import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_session_repository.dart';
import '../../api/server_compatibility.dart';

enum FileSourceProtocol { smb, webDav, openList }

/// Non-secret configuration for a file source.
///
/// Passwords and other credentials are deliberately represented by
/// [credentialRef] and never serialized into this model.
@immutable
class FileSourceConfig {
  const FileSourceConfig._({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    required this.path,
    this.uri,
    required this.credentialRef,
    required this.serverId,
    required this.enabled,
    required this.timeoutMilliseconds,
    required this.smbWorkers,
  });

  const FileSourceConfig.smb({
    required this.id,
    required this.name,
    required this.host,
    this.port = defaultSmbPort,
    required this.path,
    required this.credentialRef,
    required this.serverId,
    this.enabled = true,
    this.timeoutMilliseconds = 30 * 1000,
    this.smbWorkers = 2,
  }) : protocol = FileSourceProtocol.smb,
       uri = null;

  FileSourceConfig.webDav({
    required this.id,
    required this.name,
    required this.host,
    int? port,
    required this.path,
    required this.uri,
    required this.credentialRef,
    required this.serverId,
    this.enabled = true,
    this.timeoutMilliseconds = 30 * 1000,
    this.smbWorkers = 2,
  }) : protocol = FileSourceProtocol.webDav,
       port = port ?? _defaultWebDavPort(uri ?? '');

  FileSourceConfig.openList({
    required this.id,
    required this.name,
    required this.host,
    int? port,
    required this.path,
    required this.uri,
    required this.credentialRef,
    required this.serverId,
    this.enabled = true,
    this.timeoutMilliseconds = 30 * 1000,
    this.smbWorkers = 2,
  }) : protocol = FileSourceProtocol.openList,
       port = port ?? _defaultOpenListPort(uri ?? '');

  final String id;
  final String name;
  final FileSourceProtocol protocol;
  final String host;
  final int port;
  final String path;
  final String? uri;
  final String credentialRef;
  final String serverId;
  final bool enabled;
  final int timeoutMilliseconds;
  final int smbWorkers;

  bool get isValid {
    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        host.trim().isEmpty ||
        path.trim().isEmpty ||
        credentialRef.trim().isEmpty ||
        serverId.trim().isEmpty) {
      return false;
    }
    if (timeoutMilliseconds <= 0 || port < 1 || port > 65535) return false;
    return switch (protocol) {
      FileSourceProtocol.smb => uri == null,
      FileSourceProtocol.webDav => uri != null && _isHttpUri(uri!),
      FileSourceProtocol.openList => uri != null && _isHttpUri(uri!),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'host': host,
    'port': port,
    'path': path,
    if (uri != null) 'uri': uri,
    'credential_ref': credentialRef,
    'server_id': serverId,
    'enabled': enabled,
    'timeout_ms': timeoutMilliseconds,
    'smb_workers': smbWorkers,
  };

  factory FileSourceConfig.fromJson(Map<String, dynamic> json) {
    final protocol = switch (json['protocol']
        ?.toString()
        .trim()
        .toLowerCase()) {
      'smb' => FileSourceProtocol.smb,
      'webdav' => FileSourceProtocol.webDav,
      'openlist' => FileSourceProtocol.openList,
      _ => throw const FormatException('未知文件来源协议'),
    };
    final id = _requiredString(json['id'], 'id');
    final name = _requiredString(json['name'], 'name');
    final host = _requiredString(json['host'], 'host');
    final uri =
        protocol == FileSourceProtocol.webDav ||
            protocol == FileSourceProtocol.openList
        ? _requiredString(json['uri'], 'uri')
        : null;
    final port = _fileSourcePort(protocol, json['port'], uri);
    final path = _requiredString(json['path'], 'path');
    final credentialRef = _requiredString(
      json['credential_ref'],
      'credential_ref',
    );
    final serverId = _requiredString(json['server_id'], 'server_id');
    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw const FormatException('文件来源启用状态无效');
    }
    final timeoutMilliseconds = _requiredPositiveInt(json['timeout_ms']);
    final smbWorkers = _requiredPositiveInt(json['smb_workers']);
    final config = FileSourceConfig._(
      id: id,
      name: name,
      protocol: protocol,
      host: host,
      port: port,
      path: path,
      uri: uri,
      credentialRef: credentialRef,
      serverId: serverId,
      enabled: enabled,
      timeoutMilliseconds: timeoutMilliseconds,
      smbWorkers: smbWorkers,
    );
    if (!config.isValid) throw const FormatException('文件来源配置无效');
    return config;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileSourceConfig &&
          other.id == id &&
          other.name == name &&
          other.protocol == protocol &&
          other.host == host &&
          other.port == port &&
          other.path == path &&
          other.uri == uri &&
          other.credentialRef == credentialRef &&
          other.serverId == serverId &&
          other.enabled == enabled &&
          other.timeoutMilliseconds == timeoutMilliseconds &&
          other.smbWorkers == smbWorkers;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    protocol,
    host,
    port,
    path,
    uri,
    credentialRef,
    serverId,
    enabled,
    timeoutMilliseconds,
    smbWorkers,
  );
}

/// Credentials kept outside [FileSourceConfig] and backed by secure storage.
@immutable
class FileSourceCredentials {
  const FileSourceCredentials({
    this.user = '',
    this.password = '',
    this.domain,
  });

  final String user;
  final String password;
  final String? domain;
}

class FileSourceCredentialsRepository {
  FileSourceCredentialsRepository({AuthTokenStore? store})
    : _store = store ?? SecureAuthTokenStore();

  static const _prefix = 'omm.file_source.';

  final AuthTokenStore _store;

  Future<FileSourceCredentials?> read(String reference) async {
    final key = _key(reference);
    final values = await Future.wait<String?>([
      _store.read('$key.user'),
      _store.read('$key.password'),
      _store.read('$key.domain'),
    ]);
    if (values.every((value) => value == null)) return null;
    return FileSourceCredentials(
      user: values[0] ?? '',
      password: values[1] ?? '',
      domain: _emptyToNull(values[2]),
    );
  }

  Future<void> save(String reference, FileSourceCredentials credentials) async {
    final key = _key(reference);
    await Future.wait([
      _store.write('$key.user', credentials.user),
      _store.write('$key.password', credentials.password),
      _store.write('$key.domain', credentials.domain ?? ''),
    ]);
  }

  Future<void> delete(String reference) async {
    final key = _key(reference);
    await Future.wait([
      _store.delete('$key.user'),
      _store.delete('$key.password'),
      _store.delete('$key.domain'),
    ]);
  }

  String _key(String reference) {
    final normalized = reference.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(reference, 'reference', '凭据引用不能为空');
    }
    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return '$_prefix$encoded';
  }
}

class FileSourceConfigRepository {
  FileSourceConfigRepository(this._prefs);

  static const storageKey = 'file_sources.v1';

  final SharedPreferences _prefs;

  List<FileSourceConfig> loadAll() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) {
            try {
              final config = FileSourceConfig.fromJson(
                Map<String, dynamic>.from(item),
              );
              return config.isValid ? config : null;
            } on FormatException {
              return null;
            }
          })
          .whereType<FileSourceConfig>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  FileSourceConfig? find(String id) {
    final normalized = id.trim();
    for (final config in loadAll()) {
      if (config.id == normalized) return config;
    }
    return null;
  }

  Future<void> save(FileSourceConfig config) async {
    if (!config.isValid) throw const FormatException('文件来源配置无效');
    final configs = loadAll().toList();
    final index = configs.indexWhere((item) => item.id == config.id);
    if (index == -1) {
      configs.add(config);
    } else {
      configs[index] = config;
    }
    await _persist(configs);
  }

  Future<void> delete(String id) async {
    final configs = loadAll()..removeWhere((item) => item.id == id.trim());
    await _persist(configs);
  }

  Future<void> _persist(List<FileSourceConfig> configs) {
    return _prefs.setString(
      storageKey,
      jsonEncode(configs.map((config) => config.toJson()).toList()),
    );
  }
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _emptyToNull(String? value) => _optionalString(value);

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('文件来源字段无效：$field');
  }
  return value.trim();
}

int _requiredPositiveInt(Object? value) {
  if (value is! int || value <= 0) {
    throw const FormatException('文件来源数值字段无效');
  }
  return value;
}

int _requiredPort(Object? value) {
  final port = _requiredPositiveInt(value);
  if (port > 65535) throw const FormatException('文件来源端口无效');
  return port;
}

int _fileSourcePort(FileSourceProtocol protocol, Object? value, String? uri) {
  if (value != null) return _requiredPort(value);
  if (protocol == FileSourceProtocol.smb) return defaultSmbPort;
  if (protocol == FileSourceProtocol.openList) {
    return _defaultOpenListPort(uri ?? '');
  }
  return _defaultWebDavPort(uri ?? '');
}

int _defaultOpenListPort(String uri) {
  final scheme = Uri.tryParse(uri.trim())?.scheme.toLowerCase() ?? 'http';
  return defaultServerPort(ServerProject.openList, scheme: scheme);
}

int _defaultWebDavPort(String uri) {
  final scheme = Uri.tryParse(uri.trim())?.scheme.toLowerCase() ?? 'http';
  return defaultServerPort(ServerProject.webDav, scheme: scheme);
}

bool _isHttpUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
