import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';

void main() {
  test('rankingsPage 使用期间与类型参数并解析名次', () async {
    final adapter = _RankingAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final page = await api.rankingsPage(period: 'weekly', type: 2);

    expect(page.movies.single.number, 'ABC-001');
    expect(page.movies.single.ranking, 3);
    expect(page.movies.single.canPlay, isTrue);
    expect(adapter.requests.single, '/api/rankings?period=weekly&type=2');
  });

  test('rankingsPage 拒绝非法期间与类型', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(
      () => api.rankingsPage(period: 'yearly'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => api.rankingsPage(period: 'daily', type: 4),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('top250Page 使用筛选参数并解析 has_more', () async {
    final adapter = _RankingAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final page = await api.top250Page(
      type: 'video_type',
      typeValue: '1',
      ignoreWatched: true,
      startRank: 51,
      page: 2,
      limit: 25,
    );

    expect(page.movies.single.ranking, 3);
    expect(page.hasMore, isTrue);
    expect(adapter.requests.single, [
      '/api/top250',
      '?type=video_type',
      '&type_value=1',
      '&ignore_watched=true',
      '&start_rank=51',
      '&page=2',
      '&limit=25',
    ].join());
  });

  test('top250Page 拒绝非法类型、起始名次与页大小', () {
    final api = DbOnlineApi(Dio(BaseOptions(baseUrl: 'http://test/api')));

    expect(
      () => api.top250Page(type: 'hot'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => api.top250Page(startRank: 10),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => api.top250Page(limit: 51),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => api.top250Page(page: 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('演员榜解析头像与别名并校验类型', () async {
    final adapter = _RankingAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final result = await api.ranking.rankingActors(type: 1);

    expect(result.actors.single.id, 'actor-1');
    expect(result.actors.single.otherName, '别名');
    expect(result.actors.single.avatarUrl, 'https://example.test/a.jpg');
    expect(result.total, 1);
    expect(adapter.requests.single, '/api/actors?type=1');
    expect(
      () => api.ranking.rankingActors(type: 3),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Top250 一键订阅提交筛选并解析结果摘要', () async {
    final adapter = _RankingAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final result = await api.ranking.subscribeTop250(
      type: 'year',
      typeValue: '2015',
      ignoreWatched: true,
      startRank: 101,
    );

    expect(result.added, 2);
    expect(result.skippedSubscribed, 1);
    expect(result.skippedBlacklist, 1);
    expect(result.failed, 0);
    expect(adapter.requests.single, 'POST /api/top250/subscribe');
    expect(adapter.bodies.single, {
      'type': 'year',
      'type_value': '2015',
      'ignore_watched': true,
      'start_rank': 101,
    });
  });

  test('排行榜自动订阅配置使用 config 包装读写', () async {
    final adapter = _RankingAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final config = await api.ranking.getAutoConfig();

    expect(config.enabled, isTrue);
    expect(config.checkTime, '08:30');
    expect(config.periods, ['daily', 'weekly']);
    expect(config.contentTypes, [0, 3]);
    expect(config.topN, 20);

    final saved = await api.ranking.updateAutoConfig(config);
    expect(saved.topN, 20);
    expect(adapter.requests, [
      '/api/subs/ranking',
      'PUT /api/subs/ranking',
    ]);
    expect(adapter.bodies.single, {
      'config': {
        'enabled': true,
        'check_time': '08:30',
        'periods': ['daily', 'weekly'],
        'content_types': [0, 3],
        'top_n': 20,
      },
    });
  });
}

class _RankingAdapter implements HttpClientAdapter {
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
    final path = options.uri.path;
    requests.add(
      options.method == 'GET'
          ? path +
                (options.uri.hasQuery ? '?${options.uri.query}' : '')
          : '${options.method} $path',
    );
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': _dataFor(path)}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _dataFor(String path) {
    if (path == '/api/config') {
      return {'javdb_api': <String, dynamic>{}};
    }
    if (path == '/api/rankings' || path == '/api/top250') {
      return {
        'movies': [
          {
            'id': 'vid-1',
            'number': 'ABC-001',
            'title': '榜单影片',
            'ranking': 3,
            'can_play': true,
          },
        ],
        'total': 250,
        'has_more': true,
      };
    }
    if (path == '/api/actors') {
      return {
        'actors': [
          {
            'id': 'actor-1',
            'name': '榜单演员',
            'other_name': '别名',
            'avatar_url': 'https://example.test/a.jpg',
          },
        ],
        'total': 1,
      };
    }
    if (path == '/api/top250/subscribe') {
      return {
        'added': 2,
        'skipped_subscribed': 1,
        'skipped_blacklist': 1,
        'failed': 0,
      };
    }
    if (path == '/api/subs/ranking') {
      return {
        'config': {
          'enabled': true,
          'check_time': '08:30',
          'periods': ['daily', 'weekly'],
          'content_types': [0, 3],
          'top_n': 20,
        },
      };
    }
    return <String, dynamic>{};
  }
}
