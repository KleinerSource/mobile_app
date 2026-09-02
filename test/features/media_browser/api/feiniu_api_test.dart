import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/api/feiniu_api.dart';

void main() {
  test('飞牛 API 解析响应信封和分页数据', () async {
    final adapter = _FeiniuAdapter((options) {
      if (options.uri.path.endsWith('/item/list')) {
        return {
          'code': 0,
          'msg': '',
          'data': {
            'list': [
              {
                'guid': 'item-1',
                'title': '示例影片',
                'type': 'Movie',
                'media_guid': 'media-1',
              },
            ],
            'total': 3,
            'page': 3,
            'page_size': 1,
          },
        };
      }
      if (options.uri.path.endsWith('/user/info')) {
        return {
          'code': 0,
          'data': {'id': 'user-1', 'name': 'alice'},
        };
      }
      return {'code': 0, 'data': {}};
    });
    final api = FeiniuApi(
      Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
        ..httpClientAdapter = adapter,
    );

    final page = await api.itemList(
      parentGuid: 'library-1',
      searchTerm: '示例',
      startIndex: 2,
      limit: 1,
    );
    final user = await api.userInfo();

    expect(page.items.single.guid, 'item-1');
    expect(page.items.single.mediaGuid, 'media-1');
    expect(page.total, 3);
    expect(page.startIndex, 2);
    expect(page.limit, 1);
    expect(page.hasMore, isFalse);
    expect(user.id, 'user-1');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first, 'POST /v/api/v1/item/list');
    expect(adapter.bodies.first, {
      'ancestor_guid': 'library-1',
      'tags': {
        'type': ['Movie', 'TV'],
      },
      'sort_column': 'sort_title',
      'sort_type': 'ASC',
      'search': '示例',
      'page': 3,
      'page_size': 1,
      'exclude_grouped_video': 1,
    });
  });

  test('飞牛 API 非零 code 转换为可读异常', () async {
    final api = FeiniuApi(
      Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
        ..httpClientAdapter = _FeiniuAdapter(
          (_) => {'code': 401, 'msg': '未登录', 'data': null},
        ),
    );

    await expectLater(
      api.userInfo(),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('未登录'),
        ),
      ),
    );
  });

  test('飞牛 URL 构造会补齐且不重复 /v', () {
    expect(
      FeiniuApi.mediaRangeUrl('http://host:5666', 'media-1'),
      'http://host:5666/v/api/v1/media/range/media-1',
    );
    expect(
      FeiniuApi.mediaRangeUrl('http://host:5666/v', 'media-1'),
      'http://host:5666/v/api/v1/media/range/media-1',
    );
    expect(
      FeiniuApi.resolveAssetUrl('http://host:5666', '/api/v1/image/a.png'),
      'http://host:5666/v/api/v1/image/a.png',
    );
    expect(
      FeiniuApi.resolveAssetUrl('http://host:5666/v', 'images/a.png'),
      'http://host:5666/v/images/a.png',
    );
    expect(
      FeiniuApi.resolveAssetUrl(
        'http://host:5666/v',
        '/mediadb/item-1/poster.jpg',
      ),
      'http://host:5666/v/api/v1/sys/img/mediadb/item-1/poster.jpg',
    );
    expect(
      FeiniuApi.resolveAssetUrl(
        'http://host:5666',
        '/sys/img/mediadb/item-1/backdrop.jpg?x=1',
      ),
      'http://host:5666/v/api/v1/sys/img/mediadb/item-1/backdrop.jpg?x=1',
    );
    expect(
      FeiniuApi.resolveAssetUrl('http://host:5666', '/img/avatar.png'),
      'http://host:5666/v/api/v1/img/avatar.png',
    );
  });
}

class _FeiniuAdapter implements HttpClientAdapter {
  _FeiniuAdapter(this.respond);

  final Object? Function(RequestOptions options) respond;
  final requests = <String>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri.path}');
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
