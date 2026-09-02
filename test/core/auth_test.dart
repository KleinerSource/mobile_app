// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/auth_api_test.dart
//   - test/core/auth_session_repository_test.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/services/auth_api.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';

// ==================== 原 test/core/auth_api_test.dart ====================
void _main_0() {
  test('鉴权 API 正确解包 Response.data 并覆盖完整会话路径', () async {
    final adapter = _AuthAdapter();
    final dio = _dio(adapter);
    Object? loginRequestData;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.path.endsWith('/auth/login')) {
            loginRequestData = options.data;
          }
          handler.next(options);
        },
      ),
    );
    final api = AuthApi(dio);

    final status = await api.status();
    final config = await api.config();
    final updatedConfig = await api.updateConfig(
      enabled: true,
      password: 'password',
      refreshTokenExpireDays: 14,
      maxFailedAttempts: 8,
      lockMinutes: 45,
    );
    final session = await api.login(password: 'password', totpCode: '123456');
    final refreshed = await api.refresh('refresh-token');
    final verified = await api.verify();
    final totp = await api.beginTotp();
    await api.finishTotp(sessionId: totp.sessionId, code: '123456');
    await api.deleteTotp();
    await api.logout();

    expect(status.enabled, isTrue);
    expect(config.configured, isTrue);
    expect(updatedConfig.refreshTokenExpireDays, 14);
    expect(session.accessToken, 'access-token');
    expect(loginRequestData, {'password': 'password', 'totp_code': '123456'});
    expect(refreshed.refreshToken, 'refresh-token');
    expect(totp.secret, 'TOTPSECRET');
    expect(verified, isTrue);
    expect(adapter.paths, <String>[
      '/api/auth/status',
      '/api/auth/config',
      '/api/auth/config',
      '/api/auth/login',
      '/api/auth/refresh',
      '/api/auth/verify',
      '/api/auth/totp/begin',
      '/api/auth/totp/finish',
      '/api/auth/totp',
      '/api/auth/logout',
    ]);
    expect(adapter.refreshAuthorization, 'Bearer refresh-token');
  });

  test('dbonline token-only 登录会话可解析', () {
    final session = AuthSession.fromJson(const {
      'token': 'db-token',
      'expires_in': 86400,
    });
    expect(session.accessToken, 'db-token');
    expect(session.refreshToken, isEmpty);
    expect(session.hasAccessToken, isTrue);
    expect(session.isUsable, isFalse);
  });
}

Dio _dio(_AuthAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
}

class _AuthAdapter implements HttpClientAdapter {
  final paths = <String>[];
  String? refreshAuthorization;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    if (options.uri.path.endsWith('/auth/refresh')) {
      refreshAuthorization = options.headers['Authorization']?.toString();
    }

    final data = switch (options.uri.path) {
      '/api/auth/status' => {
        'enabled': true,
        'configured': true,
        'authenticated': false,
        'password_login_disabled': false,
        'refresh_token_expire_days': 7,
        'max_failed_attempts': 5,
        'lock_minutes': 30,
        'totp_configured': true,
        'webauthn_configured': false,
      },
      '/api/auth/config' => {
        'enabled': true,
        'configured': true,
        'password_login_disabled': false,
        'refresh_token_expire_days': options.method == 'PATCH' ? 14 : 7,
        'max_failed_attempts': options.method == 'PATCH' ? 8 : 5,
        'lock_minutes': options.method == 'PATCH' ? 45 : 30,
        'totp_configured': true,
        'webauthn_configured': false,
      },
      '/api/auth/totp/begin' => {
        'session_id': 'totp-session',
        'secret': 'TOTPSECRET',
        'qr_data_url': 'data:image/png;base64,AAAA',
      },
      '/api/auth/totp/finish' => {'totp_configured': true},
      '/api/auth/totp' => {'totp_configured': false},
      '/api/auth/verify' => {'valid': true},
      _ => null,
    };
    final session = {
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'expires_in': 3600,
    };
    final body = {
      'success': true,
      'message': 'ok',
      'data':
          options.uri.path.endsWith('/auth/login') ||
              options.uri.path.endsWith('/auth/refresh')
          ? session
          : data,
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

// ==================== 原 test/core/auth_session_repository_test.dart ====================
void _main_1() {
  test('会话只在保存时写入 token，clear 会清理所有字段', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    const session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 3600,
      cookie: 'sid=session-1',
    );

    await repository.save(session);
    expect(await repository.accessToken(), 'access-token');
    expect((await repository.current())?.cookie, 'sid=session-1');
    expect(store.values.values, contains('refresh-token'));

    await repository.clear();
    expect(await repository.current(), isNull);
    expect(store.values, isEmpty);
  });

  test('dbonline token-only 会话可以保存', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    const incomplete = AuthSession(
      accessToken: 'access-token',
      refreshToken: '',
      expiresIn: 3600,
    );

    await repository.save(incomplete);
    expect((await repository.current())?.accessToken, 'access-token');
    expect((await repository.current())?.refreshToken, isEmpty);
    expect(store.values.values, contains('access-token'));
  });

  test('不同服务器使用彼此隔离的会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);

    repository.setActiveServerId('server-a');
    await repository.save(
      const AuthSession(
        accessToken: 'access-a',
        refreshToken: 'refresh-a',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-b');
    expect(await repository.current(), isNull);
    await repository.save(
      const AuthSession(
        accessToken: 'access-b',
        refreshToken: 'refresh-b',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-a');
    expect(await repository.accessToken(), 'access-a');
    repository.setActiveServerId('server-b');
    expect(await repository.accessToken(), 'access-b');
    expect(store.values.keys, everyElement(startsWith('omm.auth.server.')));
  });

  test('首次选择服务器时会迁移旧版全局会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    await repository.save(
      const AuthSession(
        accessToken: 'legacy-access',
        refreshToken: 'legacy-refresh',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-a');
    expect(await repository.accessToken(), 'legacy-access');
    expect(store.values.keys, everyElement(startsWith('omm.auth.server.')));
  });

  test('DBO 服务器不会迁移旧版全局会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    await repository.save(
      const AuthSession(
        accessToken: 'legacy-access',
        refreshToken: 'legacy-refresh',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('dbo-server', allowLegacyMigration: false);

    expect(await repository.current(), isNull);
    expect(store.values['omm.auth.access_token'], 'legacy-access');
  });

  test('固定作用域客户端不会因主仓库切换服务器而串用会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    final serverA = repository.forServer('server-a');
    final serverB = repository.forServer('server-b');

    await serverA.save(
      const AuthSession(
        accessToken: 'access-a',
        refreshToken: 'refresh-a',
        expiresIn: 3600,
      ),
    );
    await serverB.save(
      const AuthSession(
        accessToken: 'access-b',
        refreshToken: 'refresh-b',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-b');
    expect(await serverA.accessToken(), 'access-a');
    expect(await serverB.accessToken(), 'access-b');
  });
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  group('auth_api', _main_0);
  group('auth_session_repository', _main_1);
}
