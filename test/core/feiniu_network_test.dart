import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_repository.dart';
import 'package:omm/features/media_browser/api/feiniu_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('飞牛请求自动补齐 API 基础路径和鉴权请求头', () async {
    final store = _MemoryTokenStore();
    final sessions = AuthSessionRepository(store: store)
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(
        accessToken: 'token-1',
        refreshToken: '',
        expiresIn: 0,
        cookie: 'sid=session-1',
      ),
    );
    final adapter = _RecordingAdapter();
    final dio = buildDio(
      const ServerConfig(baseUrl: 'http://test:5666'),
      projectOverride: ServerProject.feiniu,
      sessionRepository: sessions,
    )..httpClientAdapter = adapter;

    await dio.get<dynamic>('/user/info');

    expect(adapter.options.uri.path, '/v/api/v1/user/info');
    expect(adapter.options.headers['Authorization'], 'token-1');
    expect(adapter.options.headers['Cookie'], 'sid=session-1');
    expect(adapter.options.headers['X-Trim-Client'], 'web');
    expect(adapter.options.headers['X-Trim-Client-Version'], '616');
    expect(adapter.options.headers['Authx'], startsWith('nonce='));
  });

  test('飞牛登录 POST 使用 Authx 签名并跳过旧 token', () async {
    final adapter = _RecordingAdapter();
    final dio = buildDio(
      const ServerConfig(baseUrl: 'http://test:5666/v'),
      projectOverride: ServerProject.feiniu,
    )..httpClientAdapter = adapter;

    final api = FeiniuApi(dio);
    final token = await api.login(username: ' alice ', password: 'password');

    expect(token, 'token-2');
    expect(api.lastLoginCookie, 'sid=session-2; theme=dark');
    expect(adapter.options.uri.path, '/v/api/v1/login');
    expect(adapter.options.headers['Authorization'], isNull);
    expect(adapter.options.headers['Authx'], startsWith('nonce='));
    expect(adapter.options.data, {
      'app_name': 'trimemedia-web',
      'username': 'alice',
      'password': 'password',
    });
  });

  test('飞牛项目基础地址统一为 /v', () {
    expect(
      ServerConfig.normalizeForProject(
        'http://host:5666',
        ServerProject.feiniu,
      ),
      'http://host:5666/v',
    );
    expect(
      ServerConfig.normalizeForProject(
        'http://host:5666/v/api/v1',
        ServerProject.feiniu,
      ),
      'http://host:5666/v',
    );
    expect(
      ServerConfig.normalizeForProject(
        'http://host:5666/v/',
        ServerProject.feiniu,
      ),
      'http://host:5666/v',
    );
  });

  test('ApiClient 飞牛启动时会迁移旧版全局会话并保留 Cookie', () async {
    final store = _MemoryTokenStore();
    final sessions = AuthSessionRepository(store: store);
    await sessions.save(
      const AuthSession(
        accessToken: 'legacy-token',
        refreshToken: '',
        expiresIn: 0,
        userId: 'user-1',
        cookie: 'sid=session-1',
      ),
    );
    const server = ServerProfile(
      id: 'feiniu-server',
      name: '飞牛影视',
      projectName: 'feiniu',
      lines: [ServerLine(id: 'main', name: '主线路', baseUrl: 'http://test:5666')],
      activeLineId: 'main',
    );

    ApiClient.fromConfig(
      const ServerConfig(
        baseUrl: 'http://test:5666',
        servers: [server],
        activeServerId: 'feiniu-server',
      ),
      sessionRepository: sessions,
    );

    final session = await sessions.current();
    expect(session?.accessToken, 'legacy-token');
    expect(session?.cookie, 'sid=session-1');
    expect(store.values['omm.auth.cookie'], isNull);
  });

  test('配置仓库保存飞牛根地址时会持久化为 /v', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerConfigRepository(prefs);
    const root = 'http://host:5666';
    const profile = ServerProfile(
      id: 'feiniu-1',
      name: '飞牛影视',
      projectName: 'feiniu',
      lines: [ServerLine(id: 'main', name: '主线路', baseUrl: root)],
      activeLineId: 'main',
    );

    await repository.save(
      const ServerConfig(
        baseUrl: root,
        servers: [profile],
        activeServerId: 'feiniu-1',
      ),
    );

    expect(repository.load()?.baseUrl, 'http://host:5666/v');
    expect(
      repository.load()?.activeServer?.activeLine?.baseUrl,
      'http://host:5666/v',
    );
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  late RequestOptions options;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    final response = options.uri.path.endsWith('/login')
        ? {
            'code': 0,
            'data': {'token': 'token-2'},
          }
        : {
            'code': 0,
            'data': {'id': 'user-1', 'name': 'alice'},
          };
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: ['application/json'],
      if (options.uri.path.endsWith('/login'))
        'set-cookie': ['sid=session-2; Path=/; HttpOnly', 'theme=dark; Path=/'],
    };
    return ResponseBody.fromString(jsonEncode(response), 200, headers: headers);
  }
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
