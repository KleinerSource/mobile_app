import 'dart:convert';

import 'auth_session_repository.dart';
import '../api/error_codes.dart';

String? _optionalTrimmed(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

/// 服务器登录凭据，保存在安全存储中，不写入服务器配置或短期会话。
class ServerCredentials {
  const ServerCredentials({
    this.username = '',
    this.password = '',
    this.apiKey = '',
  });

  final String username;
  final String password;
  final String apiKey;

  bool get isEmpty =>
      username.trim().isEmpty && password.isEmpty && apiKey.trim().isEmpty;
}

/// 按服务器 ID 隔离保存 HTTP 用户名/密码和 Stash API Key。
class ServerCredentialsRepository {
  ServerCredentialsRepository({AuthTokenStore? store})
    : _store = store ?? SecureAuthTokenStore();

  static const _prefix = 'omm.server.credentials.';
  static const _legacyStashPrefix = 'omm.stash.server.';

  final AuthTokenStore _store;

  Future<ServerCredentials?> read(String serverId) async {
    final normalizedServerId = _normalizeServerId(serverId);
    final key = _key(normalizedServerId);
    final values = await Future.wait<String?>([
      _store.read('$key.username'),
      _store.read('$key.password'),
      _store.read('$key.api_key'),
    ]);

    var apiKey = _optionalTrimmed(values[2]);
    if (apiKey == null) {
      // 兼容旧版本只保存 Stash API Key 的键，并在首次读取时迁移到统一仓库。
      final legacyKey = _optionalTrimmed(
        await _store.read(_legacyStashKey(normalizedServerId)),
      );
      if (legacyKey != null) {
        apiKey = legacyKey;
        await _store.write('$key.api_key', legacyKey);
        await _store.delete(_legacyStashKey(normalizedServerId));
      }
    }

    final username = _optionalTrimmed(values[0]);
    final password = values[1];
    if (username == null && password == null && apiKey == null) return null;
    return ServerCredentials(
      username: username ?? '',
      password: password ?? '',
      apiKey: apiKey ?? '',
    );
  }

  Future<void> save(String serverId, ServerCredentials credentials) async {
    final normalizedServerId = _normalizeServerId(serverId);
    final key = _key(normalizedServerId);
    final username = credentials.username.trim();
    final password = credentials.password;
    final apiKey = credentials.apiKey.trim();
    await Future.wait([
      _writeOrDelete('$key.username', username),
      _writeOrDelete('$key.password', password),
      _writeOrDelete('$key.api_key', apiKey),
      _store.delete(_legacyStashKey(normalizedServerId)),
    ]);
  }

  Future<void> update(
    String serverId, {
    String? username,
    String? password,
    String? apiKey,
  }) async {
    final current = await read(serverId) ?? const ServerCredentials();
    await save(
      serverId,
      ServerCredentials(
        username: username ?? current.username,
        password: password ?? current.password,
        apiKey: apiKey ?? current.apiKey,
      ),
    );
  }

  Future<String?> readApiKey(String serverId) async {
    final credentials = await read(serverId);
    final apiKey = credentials?.apiKey.trim() ?? '';
    return apiKey.isEmpty ? null : apiKey;
  }

  Future<void> saveApiKey(String serverId, String apiKey) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', AppErrorCode.validationFailed);
    }
    await update(serverId, apiKey: normalizedKey);
  }

  /// 只删除 API Key，保留同一服务器上的其它凭据。
  Future<void> deleteApiKey(String serverId) async {
    final normalizedServerId = _normalizeServerId(serverId);
    await Future.wait([
      _store.delete('${_key(normalizedServerId)}.api_key'),
      _store.delete(_legacyStashKey(normalizedServerId)),
    ]);
  }

  Future<void> delete(String serverId) async {
    final normalizedServerId = _normalizeServerId(serverId);
    final key = _key(normalizedServerId);
    await Future.wait([
      _store.delete('$key.username'),
      _store.delete('$key.password'),
      _store.delete('$key.api_key'),
      _store.delete(_legacyStashKey(normalizedServerId)),
    ]);
  }

  Future<void> _writeOrDelete(String key, String value) {
    return value.isEmpty ? _store.delete(key) : _store.write(key, value);
  }

  String _normalizeServerId(String serverId) {
    final normalized = serverId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(serverId, 'serverId', AppErrorCode.validationFailed);
    }
    return normalized;
  }

  String _key(String serverId) {
    final encoded = base64Url.encode(utf8.encode(serverId)).replaceAll('=', '');
    return '$_prefix$encoded';
  }

  String _legacyStashKey(String serverId) {
    final encoded = base64Url.encode(utf8.encode(serverId)).replaceAll('=', '');
    return '$_legacyStashPrefix$encoded.api_key';
  }
}

/// 兼容旧调用方的 Stash API Key 访问适配器，实际数据由统一仓库存储。
class StashApiKeyRepository {
  StashApiKeyRepository({
    AuthTokenStore? store,
    ServerCredentialsRepository? repository,
  }) : _repository = repository ?? ServerCredentialsRepository(store: store);

  final ServerCredentialsRepository _repository;

  Future<String?> read(String serverId) async {
    return _repository.readApiKey(serverId);
  }

  Future<void> save(String serverId, String apiKey) async {
    await _repository.saveApiKey(serverId, apiKey);
  }

  Future<void> delete(String serverId) => _repository.deleteApiKey(serverId);
}
