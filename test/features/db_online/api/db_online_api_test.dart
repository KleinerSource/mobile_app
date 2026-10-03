import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';

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
    final library = await api.taggedMoviesPage();
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
    expect(library.movies, isNotEmpty);
    expect(detail.code, 'ABC-001');
    expect(detailByVideoId.code, 'ABC-001');
    expect(detail.canPlay, isTrue);
    expect(detail.playSources.single.id, 2);
    expect(detail.magnets.single.magnet, startsWith('magnet:'));
    expect(episodes.episodes.single.qualities.single.name, '1080p');
    expect(episodes.episodes.single.url, contains('playlist.m3u8'));
    expect(adapter.requests, <String>[
      '/api/recommend?page=1&limit=9',
      '/api/latest?page=1&limit=9&type=all&sort=update&sort_by=update',
      '/api/latest?page=1&limit=9&type=all&sort=release&sort_by=release',
      '/api/latest?page=2&limit=24&type=all&sort=release&sort_by=release',
      '/api/subs/tags?filter_by=0%3At%3A%3A%3A%3A%3A&page=1&limit=24&sort_by=update&order_by=desc',
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
      '/api/search?q=%E7%A4%BA%E4%BE%8B&type=movie&page=2&limit=24&movie_type=all&movie_sort_by=relevance',
    );
  });

  test('searchPage 拒绝空搜索关键词', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(() => api.searchPage(query: '  '), throwsA(isA<ArgumentError>()));
  });

  test('searchActors 解析演员结果，searchEntitiesPage 使用实体搜索参数', () async {
    final adapter = _DbOnlineEntitySearchAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final actors = await api.searchActors(query: '演员');
    final series = await api.searchEntitiesPage(
      type: 'series',
      query: '系列',
      page: 2,
      limit: 24,
    );
    final makers = await api.searchEntitiesPage(type: 'maker', query: '片商');
    final directors = await api.searchEntitiesPage(
      type: 'director',
      query: '导演',
    );
    final lists = await api.searchEntitiesPage(type: 'list', query: '清单');

    expect(actors.actors.single.id, 'actor-1');
    expect(actors.actors.single.videosCount, 12);
    expect(series.items.single.name, '实体结果');
    expect(makers.items.single.name, '实体结果');
    expect(directors.items.single.moviesCount, 4);
    expect(lists.items.single.id, 'entity-1');
    expect(adapter.actorRequest, '/api/search/actors?q=%E6%BC%94%E5%91%98');
    expect(adapter.entityRequests, <String>[
      '/api/search?q=%E7%B3%BB%E5%88%97&type=series&page=2&limit=24&movie_type=all&movie_sort_by=relevance',
      '/api/search?q=%E7%89%87%E5%95%86&type=maker&page=1&limit=24&movie_type=all&movie_sort_by=relevance',
      '/api/search?q=%E5%AF%BC%E6%BC%94&type=director&page=1&limit=24&movie_type=all&movie_sort_by=relevance',
      '/api/search?q=%E6%B8%85%E5%8D%95&type=list&page=1&limit=24&movie_type=all&movie_sort_by=relevance',
    ]);
  });

  test('searchEntitiesPage 拒绝空关键词与未知实体类型', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(
      () => api.searchEntitiesPage(type: 'maker', query: '  '),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => api.searchEntitiesPage(type: 'studio', query: '片商'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('entityMoviesPage 按实体类型映射端点并解析影片', () async {
    final adapter = _EntityMoviesAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final actors = await api.entityMoviesPage(
      kind: 'actor',
      id: 'kd96',
      page: 2,
    );
    final lists = await api.entityMoviesPage(kind: 'list', id: 'list-1');

    expect(actors.movies.single.number, 'ABC-003');
    expect(actors.movies.single.canPlay, isTrue);
    expect(actors.hasMore, isFalse);
    expect(lists.movies.single.number, 'ABC-003');
    expect(adapter.requests, <String>[
      '/api/actors/kd96/movies?page=2&limit=24&sort_by=release',
      '/api/lists/list-1/movies?page=1&limit=24&sort_by=release',
    ]);
  });

  test('entityMoviesPage 拒绝未知实体类型与空 ID', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(
      () => api.entityMoviesPage(kind: 'publisher', id: 'p1'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => api.entityMoviesPage(kind: 'actor', id: '  '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('searchActors 拒绝空搜索关键词', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(() => api.searchActors(query: '  '), throwsA(isA<ArgumentError>()));
  });

  test('DBO 后台配置使用 config 接口并支持局部保存和连接测试', () async {
    final adapter = _DbOnlineConfigAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final config = await api.getBackendConfig();
    final saved = await api.updateBackendConfig({
      'javdb_api': {'timeout': 45},
    });
    final tested = await api.testBackendConnection('aria2', {
      'host': '127.0.0.1',
      'port': 6800,
    });

    expect(config['javdb_api'], isA<Map>());
    expect(saved['subscription'], isA<Map>());
    expect(tested['message'], '连接正常');
    expect(adapter.requests, <String>[
      'GET /api/config',
      'PUT /api/config',
      'POST /api/aria2/test',
    ]);
    expect(adapter.requestBodies[0], {
      'javdb_api': {'timeout': 45},
    });
    expect(adapter.requestBodies[1], {'host': '127.0.0.1', 'port': 6800});
  });
}

class _DbOnlineConfigAdapter implements HttpClientAdapter {
  final requests = <String>[];
  final requestBodies = <Map<String, dynamic>>[];

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
      requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    final data = options.method == 'GET'
        ? {
            'javdb_api': {'host': 'https://javdb.example'},
            'subscription': {'enabled': false},
          }
        : options.uri.path.endsWith('/test')
        ? {'success': true, 'message': '连接正常'}
        : {
            'javdb_api': {'timeout': 45},
            'subscription': {'enabled': false},
          };
    final response = options.uri.path.endsWith('/test')
        ? {'success': true, 'message': '连接正常'}
        : {'success': true, 'data': data};
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
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

class _EntityMoviesAdapter implements HttpClientAdapter {
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
      options.uri.path +
          (options.uri.hasQuery ? '?${options.uri.query}' : ''),
    );
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'movies': [
            {
              'id': 'movie-1',
              'number': 'ABC-003',
              'title': '实体影片',
              'can_play': true,
            },
          ],
          'current_page': 1,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _DbOnlineEntitySearchAdapter implements HttpClientAdapter {
  String? actorRequest;
  final entityRequests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request =
        options.uri.path +
        (options.uri.hasQuery ? '?${options.uri.query}' : '');
    if (options.uri.path.endsWith('/search/actors')) {
      actorRequest = request;
      return _response({
        'actors': [
          {'id': 'actor-1', 'name': '演员结果', 'videos_count': 12},
        ],
        'total': 1,
      });
    }
    entityRequests.add(request);
    return _response({
      'items': [
        {'id': 'entity-1', 'name': '实体结果', 'movies_count': 4},
      ],
      'total': 1,
    });
  }

  ResponseBody _response(Map<String, dynamic> data) {
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
