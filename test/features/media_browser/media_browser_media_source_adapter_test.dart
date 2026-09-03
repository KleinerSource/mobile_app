import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_browser_media_source_adapter.dart';
import 'package:omm/core/sources/media/media_capabilities.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/features/media_browser/api/media_browser_api.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

const _ommSourceId = SourceId('omm');

class _MemoryTokenStore implements AuthTokenStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final Object? Function(RequestOptions options) respond;
  final requests = <String>[];
  final bodies = <Object?>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri}');
    bodies.add(options.data);
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
  final configs = [MediaBrowserConfig.emby, MediaBrowserConfig.jellyfin];

  for (final config in configs) {
    group(config.displayName, () {
      late AuthSessionRepository sessionRepository;
      final sourceId = SourceId(config.sourceId);
      final base = 'http://test${config.pathPrefix}';

      setUp(() async {
        final store = _MemoryTokenStore();
        sessionRepository = AuthSessionRepository(store: store);
        sessionRepository.setActiveServerId('server-1');
        await sessionRepository.save(
          const AuthSession(
            accessToken: 'token-1',
            refreshToken: '',
            expiresIn: 0,
            userId: 'user-1',
          ),
        );
      });

      MediaBrowserMediaSourceAdapter buildAdapter(_RecordingAdapter adapter) {
        return MediaBrowserMediaSourceAdapter(
          MediaBrowserApi(
            Dio(BaseOptions(baseUrl: 'http://test'))
              ..httpClientAdapter = adapter,
            config,
          ),
          sessionRepository: sessionRepository,
          serverId: 'server-1',
          endpoint: 'http://test',
        );
      }

      test('descriptor 声明来源与 catalog/details/playback 能力', () {
        final adapter = buildAdapter(_RecordingAdapter((_) => {}));
        expect(adapter.descriptor.id.value, config.sourceId);
        expect(adapter.descriptor.name, config.displayName);
        expect(adapter.capabilities, {
          MediaCapability.catalog,
          MediaCapability.movieDetails,
          MediaCapability.playback,
        });
      });

      test('媒体库管理代理透传读取、路径差异操作、启用状态和刷新', () async {
        final httpAdapter = _RecordingAdapter((options) {
          if (options.uri.path ==
              '${config.pathPrefix}/Library/VirtualFolders') {
            return [
              {
                'ItemId': 'library-1',
                'Name': '电影库',
                'CollectionType': 'movies',
                'Locations': ['/media/movies'],
                'LibraryOptions': {'Enabled': true},
              },
            ];
          }
          return null;
        });
        final adapter = buildAdapter(httpAdapter);

        final libraries = await adapter.virtualFolders();
        await adapter.renameVirtualFolder(name: '电影库', newName: '影片库');
        await adapter.removeMediaPath(
          libraryName: '影片库',
          path: '/media/movies',
        );
        await adapter.addMediaPath(libraryName: '影片库', path: '/media/films');
        await adapter.updateVirtualFolderOptions(
          id: 'library-1',
          enabled: false,
          options: const {'EnableRealtimeMonitor': true},
        );
        await adapter.refreshLibrary();

        expect(libraries.single.name, '电影库');
        expect(httpAdapter.requests[0], 'GET $base/Library/VirtualFolders');
        expect(
          httpAdapter.requests[1],
          startsWith('POST $base/Library/VirtualFolders/Name?'),
        );
        expect(
          httpAdapter.requests[2],
          startsWith('DELETE $base/Library/VirtualFolders/Paths?'),
        );
        expect(
          httpAdapter.requests[3],
          'POST $base/Library/VirtualFolders/Paths?refreshLibrary=false',
        );
        expect(
          httpAdapter.requests[4],
          'POST $base/Library/VirtualFolders/LibraryOptions',
        );
        expect(httpAdapter.requests[5], 'POST $base/Library/Refresh');
        final bodies = httpAdapter.bodies.whereType<Map>().toList();
        expect(bodies[0], {'Name': '影片库', 'Path': '/media/films'});
        expect(bodies[1], {
          'Id': 'library-1',
          'LibraryOptions': {'EnableRealtimeMonitor': true, 'Enabled': false},
        });
      });

      test('albumTracks 按光盘号与曲号查询专辑曲目', () async {
        final httpAdapter = _RecordingAdapter(
          (options) => {
            'Items': [
              {
                'Id': 'track-1',
                'Name': '曲目一',
                'Type': 'Audio',
                'Album': '专辑一',
                'AlbumId': 'album-1',
                'AlbumArtist': '艺术家',
                'Artists': ['艺术家'],
                'IndexNumber': 1,
                'ParentIndexNumber': 1,
                'RunTimeTicks': 2400000000,
              },
            ],
            'TotalRecordCount': 1,
            'StartIndex': 0,
          },
        );
        final adapter = buildAdapter(httpAdapter);

        final tracks = await adapter.albumTracks('album-1');

        expect(tracks.single.id, 'track-1');
        expect(tracks.single.isAudio, isTrue);
        expect(tracks.single.album, '专辑一');
        expect(tracks.single.displayArtist, '艺术家');
        final request = httpAdapter.requests.single;
        expect(request, contains('/Users/user-1/Items'));
        expect(request, contains('ParentId=album-1'));
        expect(request, contains('IncludeItemTypes=Audio'));
        expect(request, contains('Recursive=true'));
        expect(request, contains('SortBy=ParentIndexNumber%2CIndexNumber'));
      });

      test('fetchLyrics 透传歌词原始响应', () async {
        final httpAdapter = _RecordingAdapter((options) {
          if (options.uri.path.endsWith('/Audio/track-1/Lyrics')) {
            return {
              'Lyrics': [
                {'Text': '第一行', 'Start': 10000000},
              ],
            };
          }
          return {};
        });
        final adapter = buildAdapter(httpAdapter);

        final raw = await adapter.fetchLyrics('track-1');

        expect(raw, isA<Map<dynamic, dynamic>>());
        expect(httpAdapter.requests.single, contains('/Audio/track-1/Lyrics'));
      });

      test('listMovies 把 MediaQuery 映射为分页查询', () async {
        final httpAdapter = _RecordingAdapter(
          (options) => {
            'Items': [
              {
                'Id': 'item-1',
                'Name': '电影一',
                'Type': 'Movie',
                'ProductionYear': 2024,
                'RunTimeTicks': 6000000000,
                'ImageTags': {'Primary': 'img-tag-1'},
              },
            ],
            'TotalRecordCount': 1,
            'StartIndex': 0,
          },
        );
        final adapter = buildAdapter(httpAdapter);

        final page = await adapter.listMovies(
          const MediaQuery(
            mode: MediaCatalogMode.latest,
            page: 1,
            limit: 24,
            offset: 0,
            orderBy: 'desc',
            filters: {'parentId': 'lib-1', 'recursive': true},
          ),
        );

        expect(page.total, 1);
        expect(page.items.single.title, '电影一');
        expect(page.items.single.year, 2024);
        expect(page.items.single.duration, 600);
        expect(page.items.single.poster, contains('tag=img-tag-1'));
        // 缓存 URL 不带 token，token 轮换不会打穿图片缓存。
        expect(
          page.items.single.poster,
          isNot(contains(config.tokenQueryParam)),
        );
        expect(httpAdapter.requests.single, contains('ParentId=lib-1'));
        expect(httpAdapter.requests.single, contains('Recursive=true'));
        expect(httpAdapter.requests.single, contains('SortBy=DateCreated'));
        expect(httpAdapter.requests.single, contains('SortOrder=Descending'));
      });

      test('getMovie 返回 MediaDetails 并保留 MediaBrowserItem payload', () async {
        final adapter = buildAdapter(
          _RecordingAdapter(
            (_) => {
              'Id': 'item-1',
              'Name': '电影一',
              'Type': 'Movie',
              'Overview': '简介',
              'Genres': ['科幻'],
              'People': [
                {'Id': 'p1', 'Name': '演员一', 'Type': 'Actor', 'Role': '主角'},
              ],
            },
          ),
        );

        final details = await adapter.getMovie(
          MediaRef(sourceId: sourceId, value: 'item-1'),
        );

        expect(details.summary.title, '电影一');
        expect(details.overview, '简介');
        expect(details.genres, ['科幻']);
        expect(details.actors, ['演员一（主角）']);
        expect(details.payload, isA<MediaBrowserItem>());
      });

      test('resolvePlayback 默认返回 static 直链并携带恢复位置', () async {
        final httpAdapter = _RecordingAdapter((options) {
          if (options.uri.path.endsWith('/PlaybackInfo')) {
            return {
              'PlaySessionId': 'play-1',
              'MediaSources': [
                {
                  'Id': 'ms-1',
                  'Container': 'mkv,webm',
                  'SupportsDirectPlay': true,
                  'MediaStreams': [
                    {'Index': 0, 'Type': 'Video', 'Codec': 'hevc'},
                    {
                      'Index': 1,
                      'Type': 'Audio',
                      'Codec': 'aac',
                      'DisplayTitle': 'AAC',
                      'Channels': 2,
                      'IsDefault': true,
                    },
                    {'Index': 2, 'Type': 'Subtitle', 'Codec': 'ass'},
                    {
                      'Index': 3,
                      'Type': 'Subtitle',
                      'Codec': 'srt',
                      'IsExternal': true,
                      'Language': 'chi',
                    },
                    {
                      'Index': 4,
                      'Type': 'Subtitle',
                      'Codec': 'pgssub',
                      'IsExternal': true,
                      'IsBitmap': true,
                    },
                  ],
                },
              ],
            };
          }
          return {
            'Id': 'item-1',
            'Name': '电影一',
            'Type': 'Movie',
            'RunTimeTicks': 72000000000,
            'UserData': {'PlaybackPositionTicks': 3600000000},
          };
        });
        final adapter = buildAdapter(httpAdapter);

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(),
        );

        expect(
          descriptor.uri.toString(),
          contains('${config.pathPrefix}/Videos/item-1/stream'),
        );
        expect(descriptor.uri.toString(), contains('static=true'));
        expect(descriptor.uri.toString(), contains('MediaSourceId=ms-1'));
        expect(
          descriptor.uri.toString(),
          contains('${config.tokenQueryParam}=token-1'),
        );
        expect(descriptor.isTranscode, isFalse);
        // 直链没有扩展名，容器提示用于播放器内核选择（MKV → FFmpeg）。
        expect(descriptor.mimeType, 'video/x-matroska');
        expect(descriptor.startAt, 360);
        expect(descriptor.audioTracks.single.label, 'AAC');
        expect(descriptor.audioTracks.single.channels, 2);
        expect(descriptor.audioTracks.single.isDefault, isTrue);
        final subtitle = descriptor.subtitleTracks;
        expect(subtitle.length, 3);
        // 内嵌字幕：无直链地址，mpv 按容器轨道号选择。
        expect(subtitle[0].id, '2');
        expect(subtitle[0].source, 'embedded');
        expect(subtitle[0].url, isNull);
        // 外挂文本字幕：带 token 的 WebVTT 直链，播放页下载后本地加载。
        expect(subtitle[1].id, '3');
        expect(subtitle[1].source, 'external');
        expect(
          subtitle[1].url,
          contains(
            '${config.pathPrefix}/Videos/item-1/ms-1/Subtitles/3/Stream.vtt',
          ),
        );
        expect(subtitle[1].url, contains('${config.tokenQueryParam}=token-1'));
        // 外挂位图（PGS）客户端无法渲染，标记不可选且不提供地址。
        expect(subtitle[2].id, '4');
        expect(subtitle[2].playable, isFalse);
        expect(subtitle[2].url, isNull);
        expect(descriptor.payload, isA<MediaBrowserPlaybackInfo>());
        // PlaybackInfo 携带设备能力声明，服务器才会返回 TranscodingUrl。
        final playbackBody = (httpAdapter.bodies.last as Map)['DeviceProfile'];
        expect(playbackBody, isA<Map>());
        expect((playbackBody as Map)['DirectPlayProtocols'], ['Http']);
        // 详情与播放决策各请求一次。
        expect(
          httpAdapter.requests,
          contains('GET $base/Users/user-1/Items/item-1'),
        );
        expect(
          httpAdapter.requests,
          contains(
            'POST $base/Items/item-1/PlaybackInfo'
            '?UserId=user-1&AutoOpenLiveStream=true',
          ),
        );
      });

      test('resolvePlayback 看完的条目从头开始播放', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {'Id': 'ms-1', 'SupportsDirectPlay': true},
                ],
              };
            }
            return {
              'Id': 'item-1',
              'Name': '电影一',
              'Type': 'Movie',
              'RunTimeTicks': 10000000000,
              'UserData': {'PlaybackPositionTicks': 9900000000},
            };
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(),
        );

        expect(descriptor.startAt, 0);
      });

      test('resolvePlayback 选择第二个片源并使用其媒体信息', () async {
        String? requestedMediaSourceId;
        final httpAdapter = _RecordingAdapter((options) {
          if (options.uri.path.endsWith('/PlaybackInfo')) {
            requestedMediaSourceId =
                options.uri.queryParameters['MediaSourceId'];
            return {
              'MediaSources': [
                {
                  'Id': 'ms-1',
                  'Container': 'mkv',
                  'MediaStreams': [
                    {'Index': 0, 'Type': 'Video', 'Codec': 'hevc'},
                    {'Index': 1, 'Type': 'Audio', 'DisplayTitle': '第一音轨'},
                  ],
                },
                {
                  'Id': 'ms-2',
                  'Path': '/media/second.mp4',
                  'Container': 'mp4',
                  'Size': 2048,
                  'MediaStreams': [
                    {'Index': 0, 'Type': 'Video', 'Codec': 'h264'},
                    {
                      'Index': 1,
                      'Type': 'Audio',
                      'DisplayTitle': '第二音轨',
                      'IsDefault': true,
                    },
                    {
                      'Index': 2,
                      'Type': 'Subtitle',
                      'Codec': 'srt',
                      'IsExternal': true,
                      'Language': 'chi',
                    },
                  ],
                },
              ],
            };
          }
          return {
            'Id': 'item-1',
            'Name': '电影一',
            'Type': 'Movie',
            'RunTimeTicks': 72000000000,
          };
        });
        final adapter = buildAdapter(httpAdapter);

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(mediaSourceId: 'ms-2'),
        );

        expect(requestedMediaSourceId, 'ms-2');
        expect(descriptor.uri.queryParameters['MediaSourceId'], 'ms-2');
        expect(descriptor.mimeType, 'video/mp4');
        expect(descriptor.audioTracks.single.label, '第二音轨');
        expect(descriptor.subtitleTracks.single.url, contains('/ms-2/'));
        expect(descriptor.subtitleTracks.single.url, contains('/2/Stream.vtt'));
      });

      test('resolvePlayback 选择不存在的片源时拒绝回退到第一源', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {'Id': 'ms-1', 'SupportsDirectPlay': true},
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        await expectLater(
          adapter.resolvePlayback(
            MediaRef(sourceId: sourceId, value: 'item-1'),
            const PlaybackRequest(mediaSourceId: 'missing'),
          ),
          throwsA(isA<SourceException>()),
        );
      });

      test('resolvePlayback 请求转码时使用绝对化的 TranscodingUrl', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'SupportsDirectPlay': true,
                    'SupportsTranscoding': true,
                    'TranscodingUrl':
                        '${config.pathPrefix}/videos/item-1/master.m3u8?VideoCodec=h264',
                  },
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(forceVideoTranscode: true),
        );

        expect(descriptor.isTranscode, isTrue);
        expect(descriptor.mimeType, 'application/vnd.apple.mpegurl');
        expect(
          descriptor.uri.toString(),
          '$base/videos/item-1/master.m3u8?VideoCodec=h264',
        );
      });

      test('resolvePlayback strm 外链直接播放并按扩展名给容器提示', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'Protocol': 'Http',
                    'Container': 'strm',
                    'Path': 'http://cdn.example.com/movie/file.mkv',
                    'SupportsDirectPlay': true,
                  },
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(),
        );

        expect(
          descriptor.uri.toString(),
          'http://cdn.example.com/movie/file.mkv',
        );
        expect(descriptor.isTranscode, isFalse);
        // 外链不属于服务器，不带 token。
        expect(
          descriptor.uri.toString(),
          isNot(contains(config.tokenQueryParam)),
        );
        // Container 为 "strm" 无法映射，从 URL 扩展名推断内核提示。
        expect(descriptor.mimeType, 'video/x-matroska');
      });

      test('resolvePlayback 本地文件 Path 不走外链分支', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'Protocol': 'File',
                    'Container': 'mkv',
                    'Path': '/media/movies/file.mkv',
                    'SupportsDirectPlay': true,
                  },
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(),
        );

        expect(
          descriptor.uri.toString(),
          contains('${config.pathPrefix}/Videos/item-1/stream'),
        );
        expect(descriptor.mimeType, 'video/x-matroska');
      });

      test('resolvePlayback strm 请求转码时仍优先 TranscodingUrl', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'Protocol': 'Http',
                    'Path': 'http://cdn.example.com/movie/file.mkv',
                    'SupportsDirectPlay': true,
                    'SupportsTranscoding': true,
                    'TranscodingUrl':
                        '${config.pathPrefix}/videos/item-1/master.m3u8',
                  },
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(forceVideoTranscode: true),
        );

        expect(descriptor.isTranscode, isTrue);
        expect(descriptor.uri.toString(), '$base/videos/item-1/master.m3u8');
      });

      test('resolvePlayback strm 无 TranscodingUrl 时转码请求回退外链', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'Protocol': 'Http',
                    'Path': 'http://cdn.example.com/movie/file.mkv',
                    'SupportsDirectPlay': true,
                    'SupportsTranscoding': false,
                  },
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(forceVideoTranscode: true),
        );

        expect(descriptor.isTranscode, isFalse);
        expect(
          descriptor.uri.toString(),
          'http://cdn.example.com/movie/file.mkv',
        );
      });

      test('resolvePlayback strm 外链指回本服务器时补 token', () async {
        final adapter = buildAdapter(
          _RecordingAdapter((options) {
            if (options.uri.path.endsWith('/PlaybackInfo')) {
              return {
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'Protocol': 'Http',
                    'Path': 'http://test:8096/media/file.mkv',
                    'SupportsDirectPlay': true,
                  },
                ],
              };
            }
            return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
          }),
        );

        final descriptor = await adapter.resolvePlayback(
          MediaRef(sourceId: sourceId, value: 'item-1'),
          const PlaybackRequest(),
        );

        expect(
          descriptor.uri.toString(),
          'http://test:8096/media/file.mkv'
          '?${config.tokenQueryParam}=token-1',
        );
      });

      test('getMovie 拒绝其他来源的 MediaRef', () {
        final adapter = buildAdapter(_RecordingAdapter((_) => {}));

        expect(
          () => adapter.getMovie(
            const MediaRef(sourceId: _ommSourceId, value: '42'),
          ),
          throwsA(isA<SourceException>()),
        );
      });

      test('imageUrl 不带 token，tag 参与拼接供图片缓存失效', () async {
        final adapter = buildAdapter(_RecordingAdapter((_) => {}));

        final url = await adapter.imageUrl(
          'item-1',
          maxWidth: 440,
          tag: 'tag-1',
        );

        expect(
          url,
          '$base/Items/item-1/Images/Primary'
          '?maxWidth=440&quality=90&tag=tag-1',
        );
        expect(url, isNot(contains(config.tokenQueryParam)));
      });
    });
  }
}
