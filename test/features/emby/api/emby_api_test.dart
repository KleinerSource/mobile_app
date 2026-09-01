import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/emby/api/emby_api.dart';

/// 记录 `METHOD uri` 的通用 fake adapter，响应由构造函数注入。
class _EmbyTestAdapter implements HttpClientAdapter {
  _EmbyTestAdapter(this.respond);

  final Object? Function(RequestOptions options) respond;

  final requests = <String>[];
  final requestBodies = <Map<String, dynamic>>[];
  final authorizationHeaders = <String?>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri}');
    if (options.data is Map) {
      requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    authorizationHeaders.add(
      options.headers['X-Emby-Authorization']?.toString(),
    );
    final body = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  test('Emby 目录/详情/剧集接口使用正确的路径与查询参数', () async {
    final adapter = _EmbyTestAdapter((options) {
      final path = options.uri.path;
      if (path.endsWith('/Views')) {
        return {
          'Items': [
            {
              'Id': 'lib-1',
              'Name': '电影库',
              'Type': 'CollectionFolder',
              'CollectionType': 'movies',
            },
          ],
          'TotalRecordCount': 1,
        };
      }
      if (path.endsWith('/Latest')) {
        return [
          {'Id': 'item-9', 'Name': '最新电影', 'Type': 'Movie'},
        ];
      }
      if (path.endsWith('/Resume')) {
        return {
          'Items': [
            {
              'Id': 'item-2',
              'Name': '进行中',
              'Type': 'Movie',
              'UserData': {'PlaybackPositionTicks': 1200000000},
            },
          ],
          'TotalRecordCount': 1,
        };
      }
      if (path == '/emby/Shows/NextUp') {
        return {
          'Items': [
            {'Id': 'ep-1', 'Name': '下一集', 'Type': 'Episode'},
          ],
          'TotalRecordCount': 1,
        };
      }
      if (path.endsWith('/Seasons')) {
        return {
          'Items': [
            {'Id': 'season-1', 'Name': '第 1 季', 'Type': 'Season', 'IndexNumber': 1},
          ],
          'TotalRecordCount': 1,
        };
      }
      if (path.endsWith('/Episodes')) {
        return {
          'Items': [
            {'Id': 'ep-2', 'Name': '第 2 集', 'Type': 'Episode', 'SeriesId': 'series-1'},
          ],
          'TotalRecordCount': 1,
        };
      }
      if (path == '/emby/Users/user-1/Items/item-1') {
        return {
          'Id': 'item-1',
          'Name': '详情条目',
          'Type': 'Movie',
          'Overview': '剧情简介',
          'MediaSources': [
            {'Id': 'ms-1'},
          ],
        };
      }
      return {
        'Items': [
          {'Id': 'item-1', 'Name': '条目一', 'Type': 'Movie'},
        ],
        'TotalRecordCount': 101,
        'StartIndex': 24,
      };
    });
    final api = EmbyApi(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );

    final views = await api.views('user-1');
    final page = await api.items(
      'user-1',
      parentId: 'lib-1',
      includeItemTypes: 'Movie,Series',
      recursive: true,
      sortBy: 'DateCreated',
      sortOrder: 'Descending',
      startIndex: 24,
      limit: 24,
    );
    final latest = await api.latestMedia('user-1', parentId: 'lib-1');
    final resume = await api.resumeItems('user-1', limit: 6);
    final nextUp = await api.nextUp('user-1');
    final seasons = await api.seasons('user-1', 'series-1');
    final episodes = await api.episodes('user-1', 'season-1');
    final detail = await api.item('user-1', 'item-1');

    expect(views.single.id, 'lib-1');
    expect(views.single.collectionType, 'movies');
    expect(page.items.single.id, 'item-1');
    expect(page.total, 101);
    expect(page.hasMore, isTrue);
    expect(latest.single.name, '最新电影');
    expect(resume.items.single.userData.resumeSeconds, 120);
    expect(nextUp.items.single.isEpisode, isTrue);
    expect(seasons.single.indexNumber, 1);
    expect(episodes.items.single.seriesId, 'series-1');
    expect(detail.overview, '剧情简介');
    expect(detail.mediaSources.single.id, 'ms-1');
    expect(adapter.requests, <String>[
      'GET http://test/emby/Users/user-1/Views',
      'GET http://test/emby/Users/user-1/Items'
          '?ParentId=lib-1&IncludeItemTypes=Movie%2CSeries&Recursive=true'
          '&SortBy=DateCreated&SortOrder=Descending&StartIndex=24&Limit=24',
      'GET http://test/emby/Users/user-1/Items/Latest'
          '?ParentId=lib-1&Limit=16&EnableImages=true',
      'GET http://test/emby/Users/user-1/Items/Resume?MediaTypes=Video&Limit=6',
      'GET http://test/emby/Shows/NextUp?UserId=user-1&Limit=12',
      'GET http://test/emby/Shows/series-1/Seasons?UserId=user-1',
      'GET http://test/emby/Shows/season-1/Episodes'
          '?UserId=user-1&Fields=Overview%2CMediaSources'
          '&SortBy=ParentIndexNumber%2CIndexNumber',
      'GET http://test/emby/Users/user-1/Items/item-1',
    ]);
  });

  test('authenticateByName 携带 X-Emby-Authorization 并解析令牌与用户', () async {
    final adapter = _EmbyTestAdapter((_) => {
      'AccessToken': 'token-1',
      'ServerId': 'server-1',
      'User': {
        'Id': 'user-1',
        'Name': 'Alice',
        'Policy': {'IsAdministrator': true},
      },
    });
    final api = EmbyApi(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );

    final result = await api.authenticateByName(
      username: 'alice',
      password: 'secret',
      deviceId: 'device-1',
      deviceName: 'android',
      appVersion: '0.68.8',
    );

    expect(result.accessToken, 'token-1');
    expect(result.user.id, 'user-1');
    expect(result.user.name, 'Alice');
    expect(result.user.isAdmin, isTrue);
    expect(
      adapter.requests.single,
      'POST http://test/emby/Users/AuthenticateByName',
    );
    expect(adapter.requestBodies.single, {
      'Username': 'alice',
      'Pw': 'secret',
    });
    expect(
      adapter.authorizationHeaders.single,
      'MediaBrowser Client="Oh My Media", Device="android", '
      'DeviceId="device-1", Version="0.68.8"',
    );
  });

  test('authenticateByName 拒绝空用户名', () {
    final api = EmbyApi(Dio(BaseOptions(baseUrl: 'http://test')));

    expect(
      () => api.authenticateByName(
        username: ' ',
        password: 'x',
        deviceId: 'd',
        deviceName: 'n',
        appVersion: 'v',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('播放会话上报使用 Sessions/Playing 系列端点与 tick 单位', () async {
    final adapter = _EmbyTestAdapter((_) => {});
    final api = EmbyApi(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );

    await api.reportPlaybackStart(
      itemId: 'item-1',
      positionTicks: 10000000,
      playSessionId: 'session-1',
    );
    await api.reportPlaybackProgress(
      itemId: 'item-1',
      positionTicks: 600000000,
      playSessionId: 'session-1',
      isPaused: true,
    );
    await api.reportPlaybackStopped(
      itemId: 'item-1',
      positionTicks: 1200000000,
      playSessionId: 'session-1',
    );

    expect(adapter.requests, <String>[
      'POST http://test/emby/Sessions/Playing',
      'POST http://test/emby/Sessions/Playing/Progress',
      'POST http://test/emby/Sessions/Playing/Stopped',
    ]);
    expect(adapter.requestBodies[0], {
      'ItemId': 'item-1',
      'PositionTicks': 10000000,
      'PlaySessionId': 'session-1',
      'IsPaused': false,
    });
    expect(adapter.requestBodies[1]['IsPaused'], true);
    expect(adapter.requestBodies[2]['PositionTicks'], 1200000000);
  });

  test('收藏与已看标记分别使用 FavoriteItems/PlayedItems 端点', () async {
    final adapter = _EmbyTestAdapter((_) => {
      'Id': 'item-1',
      'Name': '条目',
      'Type': 'Movie',
      'UserData': {'IsFavorite': true, 'Played': true},
    });
    final api = EmbyApi(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );

    await api.markFavorite('user-1', 'item-1', true);
    await api.markFavorite('user-1', 'item-1', false);
    await api.markPlayed('user-1', 'item-1', true);
    await api.markPlayed('user-1', 'item-1', false);

    expect(adapter.requests, <String>[
      'POST http://test/emby/Users/user-1/FavoriteItems/item-1',
      'DELETE http://test/emby/Users/user-1/FavoriteItems/item-1',
      'POST http://test/emby/Users/user-1/PlayedItems/item-1',
      'DELETE http://test/emby/Users/user-1/PlayedItems/item-1',
    ]);
  });

  test('playbackInfo 使用 POST 并带 UserId 查询参数', () async {
    final adapter = _EmbyTestAdapter((_) => {
      'PlaySessionId': 'play-1',
      'MediaSources': [
        {
          'Id': 'ms-1',
          'SupportsDirectPlay': true,
          'TranscodingUrl': '/emby/videos/item-1/master.m3u8',
          'MediaStreams': [
            {'Index': 0, 'Type': 'Video', 'Codec': 'hevc'},
            {'Index': 1, 'Type': 'Audio', 'Codec': 'aac', 'DisplayTitle': 'AAC 中文'},
          ],
        },
      ],
    });
    final api = EmbyApi(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );

    final info = await api.playbackInfo(
      'user-1',
      'item-1',
      mediaSourceId: 'ms-1',
    );

    expect(info.playSessionId, 'play-1');
    expect(info.mediaSources.single.supportsDirectPlay, isTrue);
    expect(
      info.mediaSources.single.transcodingUrl,
      '/emby/videos/item-1/master.m3u8',
    );
    expect(
      adapter.requests.single,
      'POST http://test/emby/Items/item-1/PlaybackInfo'
      '?UserId=user-1&MediaSourceId=ms-1&AutoOpenLiveStream=true',
    );
  });

  test('直链与图片 URL 拼接 api_key 与尺寸参数', () {
    final streamUrl = EmbyApi.streamUrl(
      baseUrl: 'http://test/',
      itemId: 'item 1',
      mediaSourceId: 'ms-1',
      token: 'token-1',
    );
    expect(
      streamUrl,
      'http://test/emby/Videos/item%201/stream'
      '?static=true&MediaSourceId=ms-1&api_key=token-1',
    );

    final imageUrl = EmbyApi.imageUrl(
      baseUrl: 'http://test',
      itemId: 'item-1',
      maxWidth: 440,
      token: 'token-1',
    );
    expect(
      imageUrl,
      'http://test/emby/Items/item-1/Images/Primary'
      '?maxWidth=440&quality=90&api_key=token-1',
    );
  });

  test('resolveEmbyUrl 把相对转码地址解析为绝对地址', () {
    expect(
      EmbyApi.resolveEmbyUrl('http://test', '/emby/videos/1/master.m3u8'),
      'http://test/emby/videos/1/master.m3u8',
    );
    expect(
      EmbyApi.resolveEmbyUrl('http://test/', 'emby/videos/1/master.m3u8'),
      'http://test/emby/videos/1/master.m3u8',
    );
    expect(
      EmbyApi.resolveEmbyUrl('http://test', 'https://cdn.example/x.m3u8'),
      'https://cdn.example/x.m3u8',
    );
  });
}
