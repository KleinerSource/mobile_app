import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

abstract interface class AuthTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _androidOptions = AndroidOptions();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) =>
      _storage.read(key: key, aOptions: _androidOptions);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, aOptions: _androidOptions);

  @override
  Future<void> delete(String key) =>
      _storage.delete(key: key, aOptions: _androidOptions);
}

class AuthSessionRepository {
  AuthSessionRepository({AuthTokenStore? store})
    : _store = store ?? SecureAuthTokenStore(),
      _state = _AuthSessionState();

  AuthSessionRepository._scoped({
    required AuthTokenStore store,
    required _AuthSessionState state,
    required String? serverId,
    required bool allowLegacyMigration,
  }) : _store = store,
       _state = state,
       _activeServerId = serverId,
       _allowLegacyMigration = allowLegacyMigration;

  static const _accessKey = 'omm.auth.access_token';
  static const _refreshKey = 'omm.auth.refresh_token';
  static const _expiresKey = 'omm.auth.expires_in';

  final AuthTokenStore _store;
  final _AuthSessionState _state;
  String? _activeServerId;
  bool _allowLegacyMigration = true;
  int _scopeGeneration = 0;

  /// 切换当前服务器后，后续会话读写都只作用于该服务器。
  ///
  /// 服务器 ID 来自本地配置，不是用户输入的密码或令牌；这里仅对它做
  /// 可逆编码，避免把任意字符直接拼接到安全存储键中。
  void setActiveServerId(String? serverId, {bool allowLegacyMigration = true}) {
    final normalized = serverId?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    _allowLegacyMigration = allowLegacyMigration;
    if (next == _activeServerId) return;
    _activeServerId = next;
    _scopeGeneration++;
  }

  String? get activeServerId => _activeServerId;

  /// 为网络客户端创建固定服务器作用域，避免旧客户端在切换服务器后
  /// 误读到新服务器的会话。
  AuthSessionRepository forServer(
    String? serverId, {
    bool allowLegacyMigration = true,
  }) {
    return AuthSessionRepository._scoped(
      store: _store,
      state: _state,
      serverId: serverId,
      allowLegacyMigration: allowLegacyMigration,
    );
  }

  Future<AuthSession?> load() async {
    final serverId = _activeServerId;
    final cacheKey = _cacheKey(serverId);
    if (_state.loaded.contains(cacheKey)) return _state.cache[cacheKey];
    final generation = _scopeGeneration;
    var session = await _readSessionFor(serverId);

    // 兼容升级前只有一组全局 token 的版本。迁移成功后删除旧键，避免
    // 旧会话被错误地复用到其他服务器。
    if (session == null && serverId != null && _allowLegacyMigration) {
      if (_scopeGeneration != generation) return load();
      session = await _readSession(
        accessKey: _accessKey,
        refreshKey: _refreshKey,
        expiresKey: _expiresKey,
      );
      if (session != null) {
        await _writeSession(session, scoped: true, serverId: serverId);
        await _deleteSession(scoped: false, serverId: null);
      }
    }

    if (_scopeGeneration != generation) return load();
    _state.cache[cacheKey] = session;
    _state.loaded.add(cacheKey);
    return session;
  }

  Future<String?> accessToken() async => (await load())?.accessToken;

  Future<AuthSession?> current() => load();

  Future<void> save(AuthSession session) async {
    if (!session.hasAccessToken) {
      await clear();
      return;
    }
    final serverId = _activeServerId;
    await _writeSession(session, scoped: serverId != null, serverId: serverId);
    final cacheKey = _cacheKey(serverId);
    _state.cache[cacheKey] = session;
    _state.loaded.add(cacheKey);
  }

  Future<void> clear() async {
    final serverId = _activeServerId;
    await _deleteSession(scoped: serverId != null, serverId: serverId);
    final cacheKey = _cacheKey(serverId);
    _state.cache[cacheKey] = null;
    _state.loaded.add(cacheKey);
  }

  Future<AuthSession?> _readSession({
    required String accessKey,
    required String refreshKey,
    required String expiresKey,
  }) async {
    final access = await _store.read(accessKey);
    final refresh = await _store.read(refreshKey);
    if (access == null || access.isEmpty) {
      return null;
    }
    final expires = int.tryParse(await _store.read(expiresKey) ?? '') ?? 0;
    return AuthSession(
      accessToken: access,
      refreshToken: refresh ?? '',
      expiresIn: expires,
    );
  }

  Future<AuthSession?> _readSessionFor(String? serverId) {
    return _readSession(
      accessKey: _keyFor(_accessKey, serverId),
      refreshKey: _keyFor(_refreshKey, serverId),
      expiresKey: _keyFor(_expiresKey, serverId),
    );
  }

  Future<void> _writeSession(
    AuthSession session, {
    required bool scoped,
    String? serverId,
  }) async {
    final scope = scoped ? (serverId ?? _activeServerId) : null;
    await Future.wait([
      _store.write(_keyFor(_accessKey, scope), session.accessToken),
      _store.write(_keyFor(_refreshKey, scope), session.refreshToken),
      _store.write(_keyFor(_expiresKey, scope), session.expiresIn.toString()),
    ]);
  }

  Future<void> _deleteSession({
    required bool scoped,
    required String? serverId,
  }) async {
    final targetServerId = scoped ? serverId : null;
    await Future.wait([
      _store.delete(_keyFor(_accessKey, targetServerId)),
      _store.delete(_keyFor(_refreshKey, targetServerId)),
      _store.delete(_keyFor(_expiresKey, targetServerId)),
    ]);
    final cacheKey = _cacheKey(targetServerId);
    _state.cache[cacheKey] = null;
    _state.loaded.add(cacheKey);
  }

  String _cacheKey(String? serverId) => serverId ?? '<legacy>';

  String _keyFor(String legacyKey, String? serverId) {
    if (serverId == null) return legacyKey;
    final encoded = base64Url.encode(utf8.encode(serverId)).replaceAll('=', '');
    final suffix = legacyKey.substring('omm.auth.'.length);
    return 'omm.auth.server.$encoded.$suffix';
  }
}

class _AuthSessionState {
  final cache = <String, AuthSession?>{};
  final loaded = <String>{};
}
