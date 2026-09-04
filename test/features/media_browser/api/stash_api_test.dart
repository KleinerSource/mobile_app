import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/auth/server_credentials_repository.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/features/media_browser/api/stash_api.dart';

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _StashAdapter implements HttpClientAdapter {
  _StashAdapter(this.respond, {this.statusCode = 200});

  final Object? Function(RequestOptions options) respond;
  final int statusCode;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

StashApi _apiFor(
  _StashAdapter adapter, {
  StashApiKeyRepository? credentials,
  Future<void> Function()? onApiKeyInvalid,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://stash.test:9999'))
    ..httpClientAdapter = adapter;
  return StashApi(
    dio,
    serverId: 'server-1',
    apiKeyRepository: credentials,
    onApiKeyInvalid: onApiKeyInvalid,
  );
}

Map<String, dynamic> _scene(String id) => {
  'id': id,
  'title': 'Scene $id',
  'details': 'details',
  'files': [
    {
      'id': 'file-$id',
      'path': '/media/$id.mp4',
      'basename': '$id.mp4',
      'size': 100,
      'duration': 60,
      'format': 'mp4',
    },
  ],
  'paths': {'screenshot': '/screens/$id.jpg'},
};

void main() {
  test('findScenes 使用 /graphql、ApiKey、分页和 title/details 搜索变量', () async {
    final store = _MemoryTokenStore();
    final credentials = StashApiKeyRepository(store: store);
    await credentials.save('server-1', 'stash-key');
    final adapter = _StashAdapter(
      (options) => {
        'data': {
          'findScenes': {
            'count': 25,
            'scenes': [_scene('scene-1')],
          },
        },
      },
    );

    final result = await _apiFor(
      adapter,
      credentials: credentials,
    ).findScenes(page: 2, perPage: 24, searchText: 'keyword');

    expect(result.total, 25);
    expect(result.scenes.single.id, 'scene-1');
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/graphql');
    expect(request.headers['ApiKey'], 'stash-key');
    final body = Map<String, dynamic>.from(request.data as Map);
    final variables = Map<String, dynamic>.from(body['variables'] as Map);
    expect(variables['filter'], {
      'page': 2,
      'per_page': 24,
      'sort': 'created_at',
      'direction': 'DESC',
    });
    expect(variables['scene_filter'], {
      'title': {'value': 'keyword', 'modifier': 'INCLUDES'},
      'OR': {
        'details': {'value': 'keyword', 'modifier': 'INCLUDES'},
      },
    });
  });

  test('findScenes 传递排序字段和方向', () async {
    final adapter = _StashAdapter(
      (_) => {
        'data': {
          'findScenes': {'count': 0, 'scenes': []},
        },
      },
    );

    await _apiFor(adapter).findScenes(sortBy: 'date', sortOrder: 'ASC');

    final body = Map<String, dynamic>.from(adapter.requests.single.data as Map);
    final variables = Map<String, dynamic>.from(body['variables'] as Map);
    expect(variables['filter'], {
      'page': 1,
      'per_page': 24,
      'sort': 'date',
      'direction': 'ASC',
    });
  });

  test('Scene mutation 使用正确的返回字段', () async {
    final adapter = _StashAdapter((options) {
      final query = (options.data as Map)['query'].toString();
      if (query.contains('SaveSceneActivity')) {
        expect(query, isNot(contains('{ id }')));
        return {
          'data': {'sceneSaveActivity': null},
        };
      }
      expect(
        query,
        contains('sceneAddPlay(id: \$id, times: \$times) { count }'),
      );
      return {
        'data': {
          'sceneAddPlay': {'count': 1},
        },
      };
    });
    final api = _apiFor(
      adapter,
      credentials: StashApiKeyRepository(store: _MemoryTokenStore()),
    );

    await api.saveActivity('scene-1', resumeTime: 12, playDuration: 20);
    await api.addPlay('scene-1');
    expect(adapter.requests, hasLength(2));
  });

  test('GraphQL errors 转为 ApiException', () async {
    final graphQlErrors = _StashAdapter(
      (_) => {
        'errors': [
          {'message': 'permission denied'},
          {'message': 'second error'},
        ],
      },
    );
    final api = _apiFor(graphQlErrors);
    await expectLater(
      api.findScenes(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'permission denied\nsecond error',
        ),
      ),
    );
  });

  test('401 会清除 API Key 并通知上层', () async {
    final store = _MemoryTokenStore();
    final credentials = StashApiKeyRepository(store: store);
    await credentials.save('server-1', 'stale-key');
    var invalidated = 0;
    final adapter = _StashAdapter(
      (_) => {
        'errors': [
          {'message': 'permission denied'},
        ],
      },
      statusCode: 401,
    );
    final api = _apiFor(
      adapter,
      credentials: credentials,
      onApiKeyInvalid: () async => invalidated++,
    );

    await expectLater(
      api.findScenes(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.status, 'status', 401)
            .having((error) => error.message, 'message', contains('API Key')),
      ),
    );
    expect(await credentials.read('server-1'), isNull);
    expect(invalidated, 1);
  });

  test('按服务器 ID 隔离读取和删除 API Key', () async {
    final credentials = StashApiKeyRepository(store: _MemoryTokenStore());
    await credentials.save('server-a', 'key-a');
    await credentials.save('server-b', 'key-b');

    expect(await credentials.read('server-a'), 'key-a');
    expect(await credentials.read('server-b'), 'key-b');
    await credentials.delete('server-a');
    expect(await credentials.read('server-a'), isNull);
    expect(await credentials.read('server-b'), 'key-b');
  });
}
