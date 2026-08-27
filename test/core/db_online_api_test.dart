import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/services/db_online_api.dart';

void main() {
  test('dbonline 首页接口使用固定参数并解析 data.movies', () async {
    final adapter = _DbOnlineAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final recommend = await api.recommend();
    final updated = await api.latest(sortBy: 'update');
    final released = await api.latest(sortBy: 'release');
    final page = await api.latestPage(page: 2, limit: 24, sort: 'release');
    final detail = await api.detail('ABC-001');
    final detailByVideoId = await api.detailByVideoId('vid-1');
    final episodes = await api.onlinePlayEpisodes(
      'ABC-001',
      sourceId: 2,
      videoId: 'vid-1',
    );

    expect(recommend.single.id, 'movie-1');
    expect(recommend.single.thumbUrl, '/api/image?id=1');
    expect(recommend.single.canPlay, isTrue);
    expect(updated, isNotEmpty);
    expect(released, isNotEmpty);
    expect(page.movies, isNotEmpty);
    expect(page.hasMore, isTrue);
    expect(detail.code, 'ABC-001');
    expect(detailByVideoId.code, 'ABC-001');
    expect(detail.canPlay, isTrue);
    expect(detail.playSources.single.id, 2);
    expect(detail.magnets.single.magnet, startsWith('magnet:'));
    expect(episodes.episodes.single.qualities.single.name, '1080p');
    expect(episodes.episodes.single.url, contains('playlist.m3u8'));
    expect(adapter.requests, <String>[
      '/api/recommend?page=1&limit=9',
      '/api/latest?page=1&limit=9&type=all&sort=update&sort_by=update&filter_by=magnets',
      '/api/latest?page=1&limit=9&type=all&sort=release&sort_by=release&filter_by=magnets',
      '/api/latest?page=2&limit=24&type=all&sort=release&sort_by=release&filter_by=magnets',
      '/api/video/ABC-001?refresh=true',
      '/api/video/id/vid-1?refresh=true',
      '/api/video/ABC-001/online-play/episodes?source_id=2&video_id=vid-1',
    ]);
  });

  test('latestPage 优先使用 has_more，并在旧响应中按页大小推断', () async {
    final adapter = _DbOnlinePageAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final first = await api.latestPage(page: 1, limit: 2, sort: 'update');
    final last = await api.latestPage(page: 2, limit: 2, sort: 'update');

    expect(first.movies, hasLength(2));
    expect(first.hasMore, isTrue);
    expect(last.movies, hasLength(1));
    expect(last.hasMore, isFalse);
  });

  test('searchPage 使用 DBO 电影搜索参数并解析结果', () async {
    final adapter = _DbOnlineSearchAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final page = await api.searchPage(query: '示例', page: 2, limit: 24);

    expect(page.movies.single.number, 'ABC-002');
    expect(page.movies.single.canPlay, isTrue);
    expect(page.hasMore, isFalse);
    expect(
      adapter.request,
      '/api/search?q=%E7%A4%BA%E4%BE%8B&type=movie&page=2&limit=24&movie_type=all&movie_sort_by=relevance&movie_filter_by=p',
    );
  });

  test('searchPage 拒绝空搜索关键词', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(() => api.searchPage(query: '  '), throwsA(isA<ArgumentError>()));
  });
}

class _DbOnlineAdapter implements HttpClientAdapter {
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      options.uri.path + (options.uri.hasQuery ? '?${options.uri.query}' : ''),
    );
    return ResponseBody.fromString(
      jsonEncode(_responseFor(options.uri.path)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _responseFor(String path) {
    if (path.contains('/online-play/episodes')) {
      return {
        'success': true,
        'data': {
          'code': 'ABC-001',
          'video_id': 'vid-1',
          'source_id': 2,
          'episodes': [
            {
              'index': 0,
              'name': '第 1 集',
              'url': '/video/ABC-001/online-play/playlist.m3u8?target=x',
              'quality': '1080p',
              'qualities': [
                {
                  'name': '1080p',
                  'url': '/video/ABC-001/online-play/playlist.m3u8?target=x',
                },
              ],
            },
          ],
        },
      };
    }
    if (path.contains('/video/ABC-001') || path.contains('/video/id/vid-1')) {
      return {
        'success': true,
        'data': {
          'code': 'ABC-001',
          'title': '示例影片',
          'video_id': 'vid-1',
          'cover_url': 'https://example.com/cover.jpg',
          'date': '2024-01-01',
          'duration': 120,
          'score': 4.6,
          'director': {'external_id': 'd1', 'name': '导演'},
          'categories': [
            {'external_id': '88', 'name': '剧情'},
          ],
          'actors': [
            {'external_id': 'a1', 'name': '演员', 'gender': '♀'},
          ],
          'magnets': [
            {'name': '资源', 'magnet': 'magnet:?xt=urn:btih:x'},
          ],
          'ed2ks': [],
          'can_play': true,
          'play_sources': [
            {'id': 2, 'name': 'JavDB'},
          ],
        },
      };
    }
    return {
      'success': true,
      'data': {
        if (path.contains('/latest')) 'has_more': true,
        'movies': [
          {
            'id': 'movie-1',
            'number': 'ABC-001',
            'title': '示例影片',
            'thumb_url': '/api/image?id=1',
            'cover_url': 'https://example.com/cover.jpg',
            'release_date': '2024-01-01',
            'magnets_count': 2,
            'has_cnsub': true,
            'score': 8.5,
            'can_play': true,
          },
        ],
      },
    };
  }
}

class _DbOnlinePageAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.tryParse(options.queryParameters['page'].toString()) ?? 1;
    final movies = [
      for (var i = 0; i < (page == 1 ? 2 : 1); i++)
        {
          'id': 'movie-$page-$i',
          'number': 'ABC-$page$i',
          'title': '影片$page-$i',
        },
    ];
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'movies': movies},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _DbOnlineSearchAdapter implements HttpClientAdapter {
  String? request;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request =
        options.uri.path +
        (options.uri.hasQuery ? '?${options.uri.query}' : '');
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'movies': [
            {
              'id': 'movie-2',
              'number': 'ABC-002',
              'title': '搜索结果',
              'can_play': true,
            },
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
