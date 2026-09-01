import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/jellyfin_media_source_adapter.dart';
import 'package:omm/core/sources/media/media_capabilities.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/features/jellyfin/api/jellyfin_api.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

const _jellyfinSourceId = SourceId('jellyfin');
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

class _JellyfinAdapter implements HttpClientAdapter {
  _JellyfinAdapter(this.respond);

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
  late AuthSessionRepository sessionRepository;

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

  JellyfinMediaSourceAdapter buildAdapter(_JellyfinAdapter adapter) {
    return JellyfinMediaSourceAdapter(
      JellyfinApi(
        Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
      ),
      sessionRepository: sessionRepository,
      serverId: 'server-1',
      endpoint: 'http://test',
    );
  }

  test('descriptor 声明 jellyfin 来源与 catalog/details/playback 能力', () {
    final adapter = buildAdapter(_JellyfinAdapter((_) => {}));
    expect(adapter.descriptor.id.value, 'jellyfin');
    expect(adapter.capabilities, {
      MediaCapability.catalog,
      MediaCapability.movieDetails,
      MediaCapability.playback,
    });
  });

  test('listMovies 把 MediaQuery 映射为 Jellyfin 分页查询', () async {
    final httpAdapter = _JellyfinAdapter(
      (options) => {
        'Items': [
          {
            'Id': 'item-1',
            'Name': '电影一',
            'Type': 'Movie',
            'ProductionYear': 2024,
            'RunTimeTicks': 6000000000,
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
    expect(page.items.single.poster, contains('ApiKey=token-1'));
    expect(httpAdapter.requests.single, contains('ParentId=lib-1'));
    expect(httpAdapter.requests.single, contains('Recursive=true'));
    expect(httpAdapter.requests.single, contains('SortBy=DateCreated'));
    expect(httpAdapter.requests.single, contains('SortOrder=Descending'));
  });

  test('getMovie 返回 MediaDetails 并保留 MediaBrowserItem payload', () async {
    final adapter = buildAdapter(
      _JellyfinAdapter(
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
      const MediaRef(sourceId: _jellyfinSourceId, value: 'item-1'),
    );

    expect(details.summary.title, '电影一');
    expect(details.overview, '简介');
    expect(details.genres, ['科幻']);
    expect(details.actors, ['演员一（主角）']);
    expect(details.payload, isA<MediaBrowserItem>());
  });

  test('resolvePlayback 默认返回 static 直链并携带恢复位置', () async {
    final httpAdapter = _JellyfinAdapter((options) {
      if (options.uri.path.endsWith('/PlaybackInfo')) {
        return {
          'PlaySessionId': 'play-1',
          'MediaSources': [
            {
              'Id': 'ms-1',
              'Container': 'mkv,webm',
              'SupportsDirectPlay': true,
              'MediaStreams': [
                {'Index': 1, 'Type': 'Audio', 'Codec': 'aac', 'DisplayTitle': 'AAC'},
                {'Index': 2, 'Type': 'Subtitle', 'Codec': 'ass'},
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
      const MediaRef(sourceId: _jellyfinSourceId, value: 'item-1'),
      const PlaybackRequest(),
    );

    expect(descriptor.uri.toString(), contains('/Videos/item-1/stream'));
    expect(descriptor.uri.toString(), contains('static=true'));
    expect(descriptor.uri.toString(), contains('MediaSourceId=ms-1'));
    expect(descriptor.uri.toString(), contains('ApiKey=token-1'));
    expect(descriptor.isTranscode, isFalse);
    // 直链没有扩展名，容器提示用于播放器内核选择（MKV → FFmpeg）。
    expect(descriptor.mimeType, 'video/x-matroska');
    expect(descriptor.startAt, 360);
    expect(descriptor.audioTracks.single.label, 'AAC');
    expect(descriptor.subtitleTracks.single.id, '2');
    expect(descriptor.payload, isA<MediaBrowserPlaybackInfo>());
    // PlaybackInfo 携带设备能力声明，服务器才会返回 TranscodingUrl。
    final playbackBody = (httpAdapter.bodies.last as Map)['DeviceProfile'];
    expect(playbackBody, isA<Map>());
    expect((playbackBody as Map)['DirectPlayProtocols'], ['Http']);
    // 详情与播放决策各请求一次。
    expect(
      httpAdapter.requests,
      contains('GET http://test/Users/user-1/Items/item-1'),
    );
    expect(
      httpAdapter.requests,
      contains(
        'POST http://test/Items/item-1/PlaybackInfo'
        '?UserId=user-1&AutoOpenLiveStream=true',
      ),
    );
  });

  test('resolvePlayback 看完的条目从头开始播放', () async {
    final adapter = buildAdapter(
      _JellyfinAdapter((options) {
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
      const MediaRef(sourceId: _jellyfinSourceId, value: 'item-1'),
      const PlaybackRequest(),
    );

    expect(descriptor.startAt, 0);
  });

  test('resolvePlayback 请求转码时使用绝对化的 TranscodingUrl', () async {
    final adapter = buildAdapter(
      _JellyfinAdapter((options) {
        if (options.uri.path.endsWith('/PlaybackInfo')) {
          return {
            'MediaSources': [
              {
                'Id': 'ms-1',
                'SupportsDirectPlay': true,
                'SupportsTranscoding': true,
                'TranscodingUrl': '/videos/item-1/master.m3u8?VideoCodec=h264',
              },
            ],
          };
        }
        return {'Id': 'item-1', 'Name': '电影一', 'Type': 'Movie'};
      }),
    );

    final descriptor = await adapter.resolvePlayback(
      const MediaRef(sourceId: _jellyfinSourceId, value: 'item-1'),
      const PlaybackRequest(forceVideoTranscode: true),
    );

    expect(descriptor.isTranscode, isTrue);
    expect(descriptor.mimeType, 'application/vnd.apple.mpegurl');
    expect(
      descriptor.uri.toString(),
      'http://test/videos/item-1/master.m3u8?VideoCodec=h264',
    );
  });

  test('getMovie 拒绝其他来源的 MediaRef', () {
    final adapter = buildAdapter(_JellyfinAdapter((_) => {}));

    expect(
      () => adapter.getMovie(
        const MediaRef(sourceId: _ommSourceId, value: '42'),
      ),
      throwsA(isA<SourceException>()),
    );
  });

  test('imageUrl 拼接 ApiKey 供图片内核直连', () async {
    final adapter = buildAdapter(_JellyfinAdapter((_) => {}));

    final url = await adapter.imageUrl('item-1', maxWidth: 440);

    expect(
      url,
      'http://test/Items/item-1/Images/Primary'
      '?maxWidth=440&quality=90&ApiKey=token-1',
    );
  });
}
