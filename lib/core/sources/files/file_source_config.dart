import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_session_repository.dart';

enum FileSourceProtocol { smb, webDav }

/// Non-secret configuration for a file source.
///
/// Passwords and other credentials are deliberately represented by
/// [credentialRef] and never serialized into this model.
@immutable
class FileSourceConfig {
  const FileSourceConfig({
    required this.id,
    required this.name,
    required this.protocol,
    this.host,
    this.share,
    this.uri,
    this.credentialRef,
    this.serverId,
    this.enabled = true,
    this.timeoutMilliseconds = 30 * 1000,
    this.smbWorkers = 2,
  });

  const FileSourceConfig.smb({
    required this.id,
    required this.name,
    required this.host,
    required this.share,
    this.credentialRef,
    this.serverId,
    this.enabled = true,
    this.timeoutMilliseconds = 30 * 1000,
    this.smbWorkers = 2,
  }) : protocol = FileSourceProtocol.smb,
       uri = null;

  const FileSourceConfig.webDav({
    required this.id,
    required this.name,
    required this.uri,
    this.credentialRef,
    this.serverId,
    this.enabled = true,
    this.timeoutMilliseconds = 30 * 1000,
    this.smbWorkers = 2,
  }) : protocol = FileSourceProtocol.webDav,
       host = null,
       share = null;

  final String id;
  final String name;
  final FileSourceProtocol protocol;
  final String? host;
  final String? share;
  final String? uri;
  final String? credentialRef;
  final String? serverId;
  final bool enabled;
  final int timeoutMilliseconds;
  final int smbWorkers;

  bool get isValid {
    if (id.trim().isEmpty || name.trim().isEmpty) return false;
    if (timeoutMilliseconds <= 0) return false;
    return switch (protocol) {
      FileSourceProtocol.smb =>
        host?.trim().isNotEmpty == true && share?.trim().isNotEmpty == true,
      FileSourceProtocol.webDav =>
        uri != null && (Uri.tryParse(uri!.trim())?.hasScheme ?? false),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    if (host != null) 'host': host,
    if (share != null) 'share': share,
    if (uri != null) 'uri': uri,
    if (credentialRef != null && credentialRef!.trim().isNotEmpty)
      'credential_ref': credentialRef,
    if (serverId != null && serverId!.trim().isNotEmpty) 'server_id': serverId,
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
      'webdav' || 'web_dav' => FileSourceProtocol.webDav,
      _ => throw const FormatException('未知文件来源协议'),
    };
    return FileSourceConfig(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      protocol: protocol,
      host: _optionalString(json['host']),
      share: _optionalString(json['share']),
      uri: _optionalString(json['uri']),
      credentialRef: _optionalString(json['credential_ref']),
      serverId: _optionalString(json['server_id']),
      enabled: json['enabled'] != false,
      timeoutMilliseconds: _positiveInt(json['timeout_ms'], 30 * 1000),
      smbWorkers: _positiveInt(json['smb_workers'], 2),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileSourceConfig &&
          other.id == id &&
          other.name == name &&
          other.protocol == protocol &&
          other.host == host &&
          other.share == share &&
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
    share,
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

int _positiveInt(Object? value, int fallback) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return parsed == null || parsed <= 0 ? fallback : parsed;
}
