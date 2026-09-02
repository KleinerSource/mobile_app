import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/api/feiniu_api.dart';
import 'package:omm/features/media_browser/api/feiniu_models.dart';

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
      FeiniuApi.subtitleUrl('http://host:5666', 'subtitle-1'),
      'http://host:5666/v/api/v1/subtitle/dl/subtitle-1',
    );
    expect(
      FeiniuApi.resolveAssetUrl('http://host:5666', '/api/v1/image/a.png'),
      'http://host:5666/v/api/v1/image/a.png',
    );
    expect(
      FeiniuApi.resolveAssetUrl('http://host:5666/v', 'images/a.png'),
      'http://host:5666/v/api/v1/sys/img/images/a.png',
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
    expect(
      FeiniuApi.resolveAssetUrl(
        'http://host:5666/v',
        '/55/02/poster-hash.webp?w=400',
      ),
      'http://host:5666/v/api/v1/sys/img/55/02/poster-hash.webp?w=400',
    );
    expect(
      FeiniuApi.resolveAssetUrl(
        'http://host:5666/v',
        '/58/06/RXFg9YOlYYTNwMynBkZifbn3VpVnzd401lk1CjS099E0CKLrudR62lPMnoHDczMO4lEftUC9fHZWkQbcf877oM0TN1.webp',
        width: 400,
      ),
      'http://host:5666/v/api/v1/sys/img/58/06/RXFg9YOlYYTNwMynBkZifbn3VpVnzd401lk1CjS099E0CKLrudR62lPMnoHDczMO4lEftUC9fHZWkQbcf877oM0TN1.webp?w=400',
    );
    expect(
      FeiniuApi.resolveAssetUrl(
        'http://host:5666/v',
        '58/06/poster-hash.webp',
        width: 440,
      ),
      'http://host:5666/v/api/v1/sys/img/58/06/poster-hash.webp?w=440',
    );
    expect(
      FeiniuApi.resolveAssetUrl(
        'http://host:5666/v',
        'http://host:5666/v/api/v1/sys/img/58/06/poster-hash.webp',
        width: 400,
      ),
      'http://host:5666/v/api/v1/sys/img/58/06/poster-hash.webp?w=400',
    );
  });

  test('飞牛原生详情与流字段兼容字符串图片和数字标记', () {
    final item = FeiniuItem.fromJson(const {
      'guid': 'item-1',
      'title': '示例影片',
      'type': 'Movie',
      'posters': '/55/02/poster.webp',
      'backdrops': '/60/20/backdrop.webp',
      'genres': [13, 2],
      'can_play': 1,
    });
    final streams = FeiniuStreamList.fromData(const {
      'video_streams': [
        {
          'guid': 'video-1',
          'codec_name': 'h264',
          'width': 1920,
          'height': 804,
          'bps': 6424829,
        },
      ],
      'subtitle_streams': [
        {'guid': 'sub-1', 'is_external': 1, 'extra_file': 1, 'format': 'ass'},
      ],
    });

    expect(item.poster, '/55/02/poster.webp');
    expect(item.backdrops, ['/60/20/backdrop.webp']);
    expect(item.isPlayable, isTrue);
    expect(streams.video.single.width, 1920);
    expect(streams.video.single.bitRate, 6424829);
    expect(streams.subtitle.single.isExternal, isTrue);
    expect(streams.subtitle.single.extraFile, isNull);
  });

  test('飞牛人物头像兼容 profile_image 和 headshot 字段', () {
    final profileImage = FeiniuPerson.fromJson(const {
      'person_id': 'person-1',
      'name': '演员一',
      'profile_image': '/58/06/profile.webp',
    });
    final headshot = FeiniuPerson.fromJson(const {
      'person_id': 'person-2',
      'name': '演员二',
      'headshot': '58/06/headshot.webp',
    });

    expect(profileImage.profilePath, '/58/06/profile.webp');
    expect(headshot.profilePath, '58/06/headshot.webp');
  });

  test('飞牛条目内嵌演员字段保留海报头像路径', () {
    final item = FeiniuItem.fromJson(const {
      'guid': 'item-1',
      'title': '示例影片',
      'type': 'Movie',
      'people': [
        {
          'person_guid': 'person-1',
          'name': '演员一',
          'job': 'Actor',
          'poster': '/58/06/person.webp',
        },
      ],
    });

    expect(item.people.single.profilePath, '/58/06/person.webp');
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
