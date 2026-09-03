// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/auth_api_test.dart
//   - test/core/auth_session_repository_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/api/services/auth_api.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/auth/totp_code.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('迁移旧版全局飞牛会话时保留用户 ID 和 Cookie', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    await repository.save(
      const AuthSession(
        accessToken: 'legacy-access',
        refreshToken: '',
        expiresIn: 0,
        userId: 'user-1',
        cookie: 'sid=session-1',
      ),
    );

    repository.setActiveServerId('feiniu-server');
    final session = await repository.current();

    expect(session?.accessToken, 'legacy-access');
    expect(session?.userId, 'user-1');
    expect(session?.cookie, 'sid=session-1');
    expect(store.values['omm.auth.cookie'], isNull);
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

// ==================== loginForServer / TOTP 自动算码 ====================
void _main_2() {
  const totpSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  test('TOTP 密钥按服务器作用域存取，clear 会话不影响密钥', () async {
    final repository = AuthSessionRepository(store: _MemoryTokenStore());
    final serverA = repository.forServer('server-a');
    final serverB = repository.forServer('server-b');

    await serverA.saveTotpSecret(totpSecret);
    expect(await serverA.readTotpSecret(), totpSecret);
    expect(await serverB.readTotpSecret(), isNull);

    await serverA.save(
      const AuthSession(accessToken: 'a', refreshToken: 'r', expiresIn: 3600),
    );
    await serverA.clear();
    expect(await serverA.current(), isNull);
    // 密钥是长期登录配置，会话失效/登出不应删除它。
    expect(await serverA.readTotpSecret(), totpSecret);

    await serverA.deleteTotpSecret();
    expect(await serverA.readTotpSecret(), isNull);
  });

  test('loginForServer 用密码加 TOTP 密钥自动算码并保存作用域会话', () async {
    final recorder = _RequestRecorder();
    final httpServer = await _startOmmServer(recorder);
    addTearDown(() => httpServer.close(force: true));
    final sessions = AuthSessionRepository(store: _MemoryTokenStore());
    final container = await _authContainer(sessions);
    addTearDown(container.dispose);

    final server = _ommProfile(httpServer);
    await container
        .read(authControllerProvider.notifier)
        .loginForServer(
          server: server,
          password: 'pw',
          totpSecret: totpSecret,
        );

    final login = recorder.log
        .where((entry) => entry.path.endsWith('/auth/login'))
        .single;
    expect(login.method, 'POST');
    expect(login.body?['password'], 'pw');
    // 验证码由本地时钟生成，允许跨过 30 秒窗口边界时取相邻窗口的码。
    final now = DateTime.now();
    final expected = {
      tryGenerateTotpCode(totpSecret, now: now),
      tryGenerateTotpCode(totpSecret, now: now.add(const Duration(seconds: 30))),
    }.whereType<String>();
    expect(expected, contains(login.body?['totp_code']));

    final stored = await sessions.forServer(server.id).load();
    expect(stored?.accessToken, 'access-token');
    expect(stored?.refreshToken, 'refresh-token');
    // 密钥持久化由设置页在保存成功后决定，loginForServer 不代劳。
    expect(await sessions.forServer(server.id).readTotpSecret(), isNull);
  });

  test('loginForServer 在鉴权未启用时跳过登录', () async {
    final recorder = _RequestRecorder();
    final httpServer = await _startOmmServer(recorder, authEnabled: false);
    addTearDown(() => httpServer.close(force: true));
    final sessions = AuthSessionRepository(store: _MemoryTokenStore());
    final container = await _authContainer(sessions);
    addTearDown(container.dispose);

    final server = _ommProfile(httpServer);
    await container
        .read(authControllerProvider.notifier)
        .loginForServer(server: server, password: 'pw');

    expect(recorder.log.single.path, endsWith('/auth/status'));
    expect(await sessions.forServer(server.id).load(), isNull);
  });

  test('loginForServer 拒绝非法 TOTP 密钥且不发任何请求', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore());
    final container = await _authContainer(sessions);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .loginForServer(
            server: _ommProfileForUrl('http://127.0.0.1:1'),
            password: 'pw',
            totpSecret: 'not-base32!!',
          ),
      throwsA(isA<ApiException>()),
    );
  });

  test('loginForServer 走 Emby 用户名密码登录并保存 userId', () async {
    final recorder = _RequestRecorder();
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => httpServer.close(force: true));
    httpServer.listen((request) async {
      final body = await _capture(recorder, request);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'AccessToken': 'tok-1',
          'User': {'Id': 'u-1', 'Name': 'alice'},
        }),
      );
      await request.response.close();
      expect(body, isNotNull);
    });
    final sessions = AuthSessionRepository(store: _MemoryTokenStore());
    final container = await _authContainer(sessions);
    addTearDown(container.dispose);

    final line = ServerLine(
      id: 'emby-line',
      name: '主线路',
      baseUrl: 'http://${httpServer.address.address}:${httpServer.port}',
    );
    final server = ServerProfile(
      id: 'emby-server',
      name: 'Emby',
      lines: [line],
      activeLineId: line.id,
      projectName: 'emby',
    );
    await container
        .read(authControllerProvider.notifier)
        .loginForServer(
          server: server,
          username: 'alice',
          password: 'pw',
        );

    expect(
      recorder.log.single.path,
      contains('/Users/AuthenticateByName'),
    );
    final stored = await sessions.forServer(server.id).load();
    expect(stored?.accessToken, 'tok-1');
    expect(stored?.userId, 'u-1');
  });

  test('login 对已存 TOTP 密钥的服务器自动附加验证码', () async {
    final recorder = _RequestRecorder();
    final httpServer = await _startOmmServer(recorder);
    addTearDown(() => httpServer.close(force: true));
    final sessions = AuthSessionRepository(store: _MemoryTokenStore());

    final line = ServerLine(
      id: 'omm-line',
      name: '主线路',
      baseUrl: 'http://${httpServer.address.address}:${httpServer.port}',
    );
    final server = ServerProfile(
      id: 'omm-server',
      name: 'OMM',
      lines: [line],
      activeLineId: line.id,
      projectName: 'oh-my-media',
    );
    final config = ServerConfig(
      baseUrl: line.baseUrl,
      servers: [server],
      activeServerId: server.id,
    );
    final client = ApiClient.fromConfig(config, sessionRepository: sessions);
    final container = await _authContainer(
      sessions,
      config: config,
      client: client,
    );
    addTearDown(container.dispose);
    await sessions
        .forServer(server.id, allowLegacyMigration: false)
        .saveTotpSecret(totpSecret);

    final ok = await container
        .read(authControllerProvider.notifier)
        .login(password: 'pw');

    expect(ok, isTrue);
    final login = recorder.log
        .where((entry) => entry.path.endsWith('/auth/login'))
        .single;
    expect(login.body?['password'], 'pw');
    final now = DateTime.now();
    final expected = {
      tryGenerateTotpCode(totpSecret, now: now),
      tryGenerateTotpCode(totpSecret, now: now.add(const Duration(seconds: 30))),
    }.whereType<String>();
    expect(expected, contains(login.body?['totp_code']));
    expect(
      container.read(authControllerProvider).value?.phase,
      AuthPhase.authenticated,
    );
  });
}

class _RecordedRequest {
  _RecordedRequest(this.method, this.path, this.body);

  final String method;
  final String path;
  final Map<String, dynamic>? body;
}

class _RequestRecorder {
  final log = <_RecordedRequest>[];
}

Future<Map<String, dynamic>?> _capture(
  _RequestRecorder recorder,
  HttpRequest request,
) async {
  final raw = await utf8.decoder.bind(request).join();
  Map<String, dynamic>? body;
  if (raw.isNotEmpty) {
    try {
      body = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      body = null;
    }
  }
  recorder.log.add(_RecordedRequest(request.method, request.uri.path, body));
  return body;
}

/// 模拟 OMM 服务端：/api/auth/status 与 /api/auth/login 走标准信封。
Future<HttpServer> _startOmmServer(
  _RequestRecorder recorder, {
  bool authEnabled = true,
}) async {
  final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  httpServer.listen((request) async {
    await _capture(recorder, request);
    request.response.headers.contentType = ContentType.json;
    if (request.uri.path.endsWith('/auth/login') && authEnabled) {
      request.response.write(
        jsonEncode({
          'success': true,
          'data': {
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'expires_in': 3600,
          },
        }),
      );
    } else if (request.uri.path.endsWith('/auth/status')) {
      request.response.write(
        jsonEncode({
          'success': true,
          'data': {
            'enabled': authEnabled,
            'configured': authEnabled,
            'authenticated': false,
            'password_login_disabled': false,
            'refresh_token_expire_days': 7,
            'max_failed_attempts': 5,
            'lock_minutes': 30,
            'totp_configured': false,
            'webauthn_configured': false,
          },
        }),
      );
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'success': false}));
    }
    await request.response.close();
  });
  return httpServer;
}

ServerProfile _ommProfileForUrl(String baseUrl) {
  final line = ServerLine(id: 'omm-line', name: '主线路', baseUrl: baseUrl);
  return ServerProfile(
    id: 'omm-server',
    name: 'OMM',
    lines: [line],
    activeLineId: line.id,
    projectName: 'oh-my-media',
  );
}

ServerProfile _ommProfile(HttpServer httpServer) => _ommProfileForUrl(
      'http://${httpServer.address.address}:${httpServer.port}',
    );

class _FixedServerConfigNotifier extends ServerConfigNotifier {
  _FixedServerConfigNotifier(this.config);

  final ServerConfig? config;

  @override
  ServerConfig? build() => config;
}

/// 构造挂载 AuthController 的容器；默认无配置（unconfigured），
/// loginForServer 不依赖活动服务器配置。
Future<ProviderContainer> _authContainer(
  AuthSessionRepository sessions, {
  ServerConfig? config,
  ApiClient? client,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authSessionRepositoryProvider.overrideWithValue(sessions),
      if (config != null)
        serverConfigProvider.overrideWith(
          () => _FixedServerConfigNotifier(config),
        ),
      if (client != null) requiredApiClientProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  group('auth_api', _main_0);
  group('auth_session_repository', _main_1);
  group('auth_login_for_server', _main_2);
}
