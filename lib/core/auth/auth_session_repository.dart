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

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(
        key: key,
        aOptions: _androidOptions,
      );

  @override
  Future<void> write(String key, String value) => _storage.write(
        key: key,
        value: value,
        aOptions: _androidOptions,
      );

  @override
  Future<void> delete(String key) => _storage.delete(
        key: key,
        aOptions: _androidOptions,
      );
}

class AuthSessionRepository {
  AuthSessionRepository({AuthTokenStore? store})
      : _store = store ?? SecureAuthTokenStore();

  static const _accessKey = 'md_center.auth.access_token';
  static const _refreshKey = 'md_center.auth.refresh_token';
  static const _expiresKey = 'md_center.auth.expires_in';

  final AuthTokenStore _store;
  AuthSession? _cached;

  Future<AuthSession?> load() async {
    if (_cached != null) return _cached;
    final access = await _store.read(_accessKey);
    final refresh = await _store.read(_refreshKey);
    if (access == null || refresh == null || access.isEmpty || refresh.isEmpty) {
      return null;
    }
    final expires = int.tryParse(await _store.read(_expiresKey) ?? '') ?? 0;
    return _cached = AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: expires,
    );
  }

  Future<String?> accessToken() async => (await load())?.accessToken;

  Future<AuthSession?> current() => load();

  Future<void> save(AuthSession session) async {
    if (!session.isUsable) {
      await clear();
      return;
    }
    await _store.write(_accessKey, session.accessToken);
    await _store.write(_refreshKey, session.refreshToken);
    await _store.write(_expiresKey, session.expiresIn.toString());
    _cached = session;
  }

  Future<void> clear() async {
    await Future.wait([
      _store.delete(_accessKey),
      _store.delete(_refreshKey),
      _store.delete(_expiresKey),
    ]);
    _cached = null;
  }
}
