import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/api/media_browser_api.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';

/// 记录 `METHOD uri` 的通用 fake adapter，响应由构造函数注入。
class _MediaBrowserTestAdapter implements HttpClientAdapter {
  _MediaBrowserTestAdapter(
    this.respond,
    this.authHeaderName, {
    this.statusCode = 200,
  });

  final Object? Function(RequestOptions options) respond;
  final String authHeaderName;
  final int statusCode;

  final requests = <String>[];
  final requestBodies = <Map<String, dynamic>>[];
  final requestData = <Object?>[];
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
    requestData.add(options.data);
    if (options.data is Map) {
      requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    authorizationHeaders.add(options.headers[authHeaderName]?.toString());
    final body = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  final configs = [MediaBrowserConfig.emby, MediaBrowserConfig.jellyfin];

  MediaBrowserApi apiFor(
    MediaBrowserConfig config,
    _MediaBrowserTestAdapter adapter,
  ) => MediaBrowserApi(
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    config,
  );

  for (final config in configs) {
    group(config.displayName, () {
      test('目录/详情/剧集接口使用正确的路径与查询参数', () async {
        final adapter = _MediaBrowserTestAdapter((options) {
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
          if (path == config.path('/Shows/NextUp')) {
            return {
              'Items': [
                {'Id': 'ep-1', 'Name': '下一集', 'Type': 'Episode'},
              ],
              'TotalRecordCount': 1,
            };
          }
          if (path == config.path('/Items/series-1/Similar')) {
            return {
              'Items': [
                {'Id': 'series-2', 'Name': '相似剧集', 'Type': 'Series'},
              ],
              'TotalRecordCount': 1,
            };
          }
          if (path.endsWith('/Seasons')) {
            return {
              'Items': [
                {
                  'Id': 'season-1',
                  'Name': '第 1 季',
                  'Type': 'Season',
                  'IndexNumber': 1,
                },
              ],
              'TotalRecordCount': 1,
            };
          }
          if (path.endsWith('/Episodes')) {
            return {
              'Items': [
                {
                  'Id': 'ep-2',
                  'Name': '第 2 集',
                  'Type': 'Episode',
                  'SeriesId': 'series-1',
                },
              ],
              'TotalRecordCount': 1,
            };
          }
          if (path == config.path('/Users/user-1/Items/item-1')) {
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
        }, config.authHeaderName);
        final api = apiFor(config, adapter);
        final base = 'http://test${config.pathPrefix}';

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
        final similar = await api.similar('user-1', 'series-1');
        final seasons = await api.seasons('user-1', 'series-1');
        final episodes = await api.episodes('user-1', 'series-1', 'season-1');
        final detail = await api.item('user-1', 'item-1');

        expect(views.single.id, 'lib-1');
        expect(views.single.collectionType, 'movies');
        expect(page.items.single.id, 'item-1');
        expect(page.total, 101);
        expect(page.hasMore, isTrue);
        expect(latest.single.name, '最新电影');
        expect(resume.items.single.userData.resumeSeconds, 120);
        expect(nextUp.items.single.isEpisode, isTrue);
        expect(similar.items.single.id, 'series-2');
        expect(seasons.single.indexNumber, 1);
        expect(episodes.items.single.seriesId, 'series-1');
        expect(detail.overview, '剧情简介');
        expect(detail.mediaSources.single.id, 'ms-1');
        expect(adapter.requests, <String>[
          'GET $base/Users/user-1/Views',
          'GET $base/Users/user-1/Items'
              '?ParentId=lib-1&IncludeItemTypes=Movie%2CSeries&Recursive=true'
              '&SortBy=DateCreated&SortOrder=Descending&StartIndex=24&Limit=24'
              '&Fields=ItemCounts%2CProductionYear%2CPremiereDate%2CEndDate%2CStatus%2CTags',
          'GET $base/Users/user-1/Items/Latest'
              '?ParentId=lib-1&Limit=16&Fields=ItemCounts%2CProductionYear%2C'
              'PremiereDate%2CEndDate%2CStatus%2CTags&EnableImages=true',
          'GET $base/Users/user-1/Items/Resume?MediaTypes=Video&Limit=6',
          'GET $base/Shows/NextUp?UserId=user-1&Limit=12',
          'GET $base/Items/series-1/Similar?UserId=user-1&Limit=12'
              '&Fields=ItemCounts%2CProductionYear%2CPremiereDate%2CEndDate%2CStatus%2CTags',
          'GET $base/Shows/series-1/Seasons?UserId=user-1',
          'GET $base/Shows/series-1/Episodes'
              '?UserId=user-1&SeasonId=season-1&Fields=Overview%2CMediaSources'
              '&SortBy=ParentIndexNumber%2CIndexNumber',
          'GET $base/Users/user-1/Items/item-1',
        ]);
      });

      test('AdditionalParts 解析分集并按服务端顺序返回', () async {
        final adapter = _MediaBrowserTestAdapter((options) {
          expect(options.uri.queryParameters['UserId'], 'user-1');
          return [
            {
              'Id': 'part-2',
              'Name': 'CD2',
              'MediaSources': [
                {'Id': 'source-2', 'Container': 'mp4'},
              ],
            },
            {
              'Id': 'part-3',
              'Name': 'CD3',
              'MediaSources': [
                {'Id': 'source-3', 'Container': 'mkv'},
              ],
            },
          ];
        }, config.authHeaderName);
        final api = apiFor(config, adapter);

        final parts = await api.additionalParts('user-1', 'movie-1');

        expect(parts.map((part) => part.id), ['part-2', 'part-3']);
        expect(parts.first.mediaSources.single.id, 'source-2');
        expect(
          adapter.requests.single,
          'GET http://test${config.pathPrefix}/Videos/movie-1/AdditionalParts'
          '?UserId=user-1',
        );
      });

      test('AdditionalParts 接口返回不支持状态时兼容为空列表', () async {
        final adapter = _MediaBrowserTestAdapter(
          (_) => {'Message': 'not supported'},
          config.authHeaderName,
          statusCode: 404,
        );
        final api = apiFor(config, adapter);

        expect(await api.additionalParts('user-1', 'movie-1'), isEmpty);
      });

      test('authenticateByName 携带客户端身份头并解析令牌与用户', () async {
        final adapter = _MediaBrowserTestAdapter(
          (_) => {
            'AccessToken': 'token-1',
            'ServerId': 'server-1',
            'User': {
              'Id': 'user-1',
              'Name': 'Alice',
              'Policy': {'IsAdministrator': true},
            },
          },
          config.authHeaderName,
        );
        final api = apiFor(config, adapter);

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
          'POST http://test${config.pathPrefix}/Users/AuthenticateByName',
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
        final api = apiFor(
          config,
          _MediaBrowserTestAdapter((_) => {}, config.authHeaderName),
        );

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

      test('媒体库管理接口使用正确的路径、查询参数、请求体并允许空响应', () async {
        final adapter = _MediaBrowserTestAdapter((options) {
          if (options.uri.path == config.path('/Library/VirtualFolders')) {
            return [
              {
                'ItemId': 'library-1',
                'Name': '电影库',
                'CollectionType': 'movies',
                'Locations': ['/media/movies'],
                'LibraryOptions': {
                  'Enabled': false,
                  'EnableRealtimeMonitor': true,
                  'TypeOptions': [
                    {
                      'Type': 'Movie',
                      'MetadataFetchers': ['TheMovieDb'],
                    },
                  ],
                },
              },
            ];
          }
          return null;
        }, config.authHeaderName);
        final api = apiFor(config, adapter);
        final base = 'http://test${config.pathPrefix}';

        final folders = await api.virtualFolders();
        await api.addVirtualFolder(
          name: '电视剧库',
          collectionType: 'tvshows',
          paths: ['/media/tv', '/media/tv 2'],
        );
        await api.renameVirtualFolder(name: '电视剧库', newName: '剧集库');
        await api.addMediaPath(libraryName: '剧集库', path: '/media/tv 3');
        await api.removeMediaPath(libraryName: '剧集库', path: '/media/tv 2');
        await api.updateVirtualFolderOptions(
          id: 'library-1',
          enabled: true,
          options: const {
            'Enabled': false,
            'EnableRealtimeMonitor': true,
            'MetadataSavers': ['Nfo'],
          },
        );
        await api.removeVirtualFolder('剧集库');
        await api.refreshLibrary();

        expect(folders.single.id, 'library-1');
        expect(folders.single.paths, ['/media/movies']);
        expect(folders.single.enabled, isFalse);
        expect(adapter.requests[0], 'GET $base/Library/VirtualFolders');
        expect(
          adapter.requests[1],
          startsWith('POST $base/Library/VirtualFolders?'),
        );
        expect(
          adapter.requests[1],
          contains('name=%E7%94%B5%E8%A7%86%E5%89%A7%E5%BA%93'),
        );
        expect(adapter.requests[1], contains('collectionType=tvshows'));
        expect(adapter.requests[1], contains('refreshLibrary=false'));
        expect(
          adapter.requests[2],
          startsWith('POST $base/Library/VirtualFolders/Name?'),
        );
        expect(
          adapter.requests[3],
          'POST $base/Library/VirtualFolders/Paths?refreshLibrary=false',
        );
        expect(
          adapter.requests[4],
          startsWith('DELETE $base/Library/VirtualFolders/Paths?'),
        );
        expect(
          adapter.requests[5],
          'POST $base/Library/VirtualFolders/LibraryOptions',
        );
        expect(
          adapter.requests[6],
          startsWith('DELETE $base/Library/VirtualFolders?'),
        );
        expect(adapter.requests[7], 'POST $base/Library/Refresh');
        expect(adapter.requestBodies[0], {
          'Name': '剧集库',
          'Path': '/media/tv 3',
        });
        expect(adapter.requestBodies[1], {
          'Id': 'library-1',
          'LibraryOptions': {
            'Enabled': true,
            'EnableRealtimeMonitor': true,
            'MetadataSavers': ['Nfo'],
          },
        });
      });

      test('单库刷新使用 Items 路径并读取 ScheduledTasks', () async {
        final adapter = _MediaBrowserTestAdapter((options) {
          if (options.uri.path == config.path('/ScheduledTasks')) {
            return [
              {
                'Key': 'RefreshMediaLibrary',
                'Name': 'Refresh Media Library library-1',
                'State': 'Running',
                'CurrentProgressPercentage': 42.5,
              },
            ];
          }
          return null;
        }, config.authHeaderName);
        final api = apiFor(config, adapter);

        await api.refreshLibrary(libraryId: 'library-1');
        final tasks = await api.scheduledTasks();

        expect(adapter.requests, [
          'POST http://test${config.pathPrefix}/Items/library-1/Refresh',
          'GET http://test${config.pathPrefix}/ScheduledTasks',
        ]);
        expect(adapter.requestData[0], isNull);
        expect(adapter.requestData[1], isNull);
        expect(tasks.single['CurrentProgressPercentage'], 42.5);
      });

      test('播放会话上报使用 Sessions/Playing 系列端点与 tick 单位', () async {
        final adapter = _MediaBrowserTestAdapter(
          (_) => {},
          config.authHeaderName,
        );
        final api = apiFor(config, adapter);
        final base = 'http://test${config.pathPrefix}';

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
          'POST $base/Sessions/Playing',
          'POST $base/Sessions/Playing/Progress',
          'POST $base/Sessions/Playing/Stopped',
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
        final adapter = _MediaBrowserTestAdapter(
          (_) => {
            'Id': 'item-1',
            'Name': '条目',
            'Type': 'Movie',
            'UserData': {'IsFavorite': true, 'Played': true},
          },
          config.authHeaderName,
        );
        final api = apiFor(config, adapter);
        final base = 'http://test${config.pathPrefix}';

        await api.markFavorite('user-1', 'item-1', true);
        await api.markFavorite('user-1', 'item-1', false);
        await api.markPlayed('user-1', 'item-1', true);
        await api.markPlayed('user-1', 'item-1', false);

        expect(adapter.requests, <String>[
          'POST $base/Users/user-1/FavoriteItems/item-1',
          'DELETE $base/Users/user-1/FavoriteItems/item-1',
          'POST $base/Users/user-1/PlayedItems/item-1',
          'DELETE $base/Users/user-1/PlayedItems/item-1',
        ]);
      });

      test('playbackInfo 使用 POST 并带 UserId 查询参数', () async {
        final adapter = _MediaBrowserTestAdapter(
          (_) => {
            'PlaySessionId': 'play-1',
            'MediaSources': [
              {
                'Id': 'ms-1',
                'SupportsDirectPlay': true,
                'TranscodingUrl':
                    '${config.pathPrefix}/videos/item-1/master.m3u8',
                'MediaStreams': [
                  {'Index': 0, 'Type': 'Video', 'Codec': 'hevc'},
                  {
                    'Index': 1,
                    'Type': 'Audio',
                    'Codec': 'aac',
                    'DisplayTitle': 'AAC 中文',
                  },
                ],
              },
            ],
          },
          config.authHeaderName,
        );
        final api = apiFor(config, adapter);

        final info = await api.playbackInfo(
          'user-1',
          'item-1',
          mediaSourceId: 'ms-1',
          deviceProfile: const {
            'DirectPlayProtocols': ['Http'],
          },
        );

        expect(info.playSessionId, 'play-1');
        expect(info.mediaSources.single.supportsDirectPlay, isTrue);
        expect(
          info.mediaSources.single.transcodingUrl,
          '${config.pathPrefix}/videos/item-1/master.m3u8',
        );
        expect(
          adapter.requests.single,
          'POST http://test${config.pathPrefix}/Items/item-1/PlaybackInfo'
          '?UserId=user-1&MediaSourceId=ms-1&AutoOpenLiveStream=true',
        );
        expect(adapter.requestBodies.single, {
          'DeviceProfile': {
            'DirectPlayProtocols': ['Http'],
          },
        });
      });

      test('直链拼接 token，图片 URL 拼接 tag 与尺寸参数', () {
        final streamUrl = MediaBrowserApi.streamUrl(
          config: config,
          baseUrl: 'http://test/',
          itemId: 'item 1',
          mediaSourceId: 'ms-1',
          token: 'token-1',
        );
        expect(
          streamUrl,
          'http://test${config.pathPrefix}/Videos/item%201/stream'
          '?static=true&MediaSourceId=ms-1'
          '&${config.tokenQueryParam}=token-1',
        );

        final imageUrl = MediaBrowserApi.imageUrl(
          config: config,
          baseUrl: 'http://test',
          itemId: 'item-1',
          maxWidth: 440,
          tag: 'tag-1',
        );
        expect(
          imageUrl,
          'http://test${config.pathPrefix}/Items/item-1/Images/Primary'
          '?maxWidth=440&quality=90&tag=tag-1',
        );

        // token 是直连下载场景的鉴权兜底，参与拼接但不属于缓存 URL 的
        // 常规形态。
        final authedUrl = MediaBrowserApi.imageUrl(
          config: config,
          baseUrl: 'http://test',
          itemId: 'item-1',
          maxWidth: 600,
          token: 'token-1',
        );
        expect(
          authedUrl,
          'http://test${config.pathPrefix}/Items/item-1/Images/Primary'
          '?maxWidth=600&quality=90&${config.tokenQueryParam}=token-1',
        );
      });

      test('用户头像 URL 使用项目路径、编码用户 ID 和对应令牌参数', () {
        final embyUrl = MediaBrowserApi.userImageUrl(
          config: MediaBrowserConfig.emby,
          baseUrl: 'http://test/',
          userId: 'user/id 1',
          token: 'emby-token',
        );
        expect(
          embyUrl,
          'http://test/emby/Users/user%2Fid%201/Images/Primary?api_key=emby-token',
        );

        final jellyfinUrl = MediaBrowserApi.userImageUrl(
          config: MediaBrowserConfig.jellyfin,
          baseUrl: 'http://test',
          userId: 'user/id 1',
          token: 'jellyfin-token',
        );
        expect(
          jellyfinUrl,
          'http://test/Users/user%2Fid%201/Images/Primary?ApiKey=jellyfin-token',
        );
      });

      test('音频直链使用 /Audio/{id}/stream 并拼接 token 参数', () {
        final audioUrl = MediaBrowserApi.audioStreamUrl(
          config: config,
          baseUrl: 'http://test/',
          itemId: 'song 1',
          mediaSourceId: 'ms-1',
          token: 'token-1',
        );
        expect(
          audioUrl,
          'http://test${config.pathPrefix}/Audio/song%201/stream'
          '?static=true&MediaSourceId=ms-1'
          '&${config.tokenQueryParam}=token-1',
        );
      });

      test('外挂字幕直链使用 Subtitles/{index}/Stream.vtt 并拼接 token', () {
        final subtitleUrl = MediaBrowserApi.subtitleStreamUrl(
          config: config,
          baseUrl: 'http://test',
          itemId: 'item 1',
          mediaSourceId: 'ms-1',
          streamIndex: 3,
          token: 'token-1',
        );
        expect(
          subtitleUrl,
          'http://test${config.pathPrefix}/Videos/item%201/ms-1'
          '/Subtitles/3/Stream.vtt'
          '?${config.tokenQueryParam}=token-1',
        );
      });

      test('lyrics 请求 /Audio/{id}/Lyrics 且空 ID 返回 null', () async {
        final adapter = _MediaBrowserTestAdapter((options) {
          if (options.uri.path.endsWith('/Audio/song-1/Lyrics')) {
            return {
              'Metadata': {'Artist': '艺术家'},
              'Lyrics': [
                {'Text': '第一行', 'Start': 10000000},
              ],
            };
          }
          return {};
        }, config.authHeaderName);
        final api = apiFor(config, adapter);

        final raw = await api.lyrics(' song-1 ');

        expect(raw, isA<Map<dynamic, dynamic>>());
        expect(
          adapter.requests.single,
          'GET http://test${config.pathPrefix}/Audio/song-1/Lyrics',
        );
        expect(await api.lyrics('  '), isNull);
      });
    });
  }

  group('validateSession', () {
    test('Emby 按持久化用户 ID 查询 /Users/{Id}（无 /Users/Me）', () async {
      final adapter = _MediaBrowserTestAdapter((options) {
        if (options.uri.path == '/emby/Users/user-1') {
          return {
            'Id': 'user-1',
            'Name': 'Alice',
            'Policy': {'IsAdministrator': false},
          };
        }
        return {};
      }, MediaBrowserConfig.emby.authHeaderName);
      final api = apiFor(MediaBrowserConfig.emby, adapter);

      final user = await api.validateSession('user-1');

      expect(user.id, 'user-1');
      expect(user.name, 'Alice');
      expect(adapter.requests.single, 'GET http://test/emby/Users/user-1');
    });

    test('Emby 拒绝空持久化用户 ID', () {
      final api = apiFor(
        MediaBrowserConfig.emby,
        _MediaBrowserTestAdapter(
          (_) => {},
          MediaBrowserConfig.emby.authHeaderName,
        ),
      );

      expect(() => api.validateSession('  '), throwsA(isA<ArgumentError>()));
    });

    test('Jellyfin 用 /Users/Me 按令牌反查用户', () async {
      final adapter = _MediaBrowserTestAdapter((options) {
        if (options.uri.path == '/Users/Me') {
          return {
            'Id': 'user-1',
            'Name': 'Alice',
            'Policy': {'IsAdministrator': false},
          };
        }
        return {};
      }, MediaBrowserConfig.jellyfin.authHeaderName);
      final api = apiFor(MediaBrowserConfig.jellyfin, adapter);

      final user = await api.validateSession(null);

      expect(user.id, 'user-1');
      expect(user.name, 'Alice');
      expect(adapter.requests.single, 'GET http://test/Users/Me');
    });
  });

  test('resolveUrl 把相对转码地址解析为绝对地址', () {
    expect(
      MediaBrowserApi.resolveUrl('http://test', '/emby/videos/1/master.m3u8'),
      'http://test/emby/videos/1/master.m3u8',
    );
    expect(
      MediaBrowserApi.resolveUrl('http://test/', 'videos/1/master.m3u8'),
      'http://test/videos/1/master.m3u8',
    );
    expect(
      MediaBrowserApi.resolveUrl('http://test', 'https://cdn.example/x.m3u8'),
      'https://cdn.example/x.m3u8',
    );
  });
}
