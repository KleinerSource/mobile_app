import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/auth/server_credentials_repository.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_capabilities.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/core/sources/media/stash_media_source_adapter.dart';
import 'package:omm/features/media_browser/api/stash_api.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

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
  _StashAdapter(this.respond);

  final Object? Function(RequestOptions options) respond;
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
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Map<String, dynamic> _scene() => {
  'id': 'scene-1',
  'title': 'Test Scene',
  'code': 'SC-001',
  'details': 'Scene details',
  'date': '2024-03-04',
  'rating100': 86,
  'resume_time': 12.5,
  'play_duration': 60,
  'play_count': 2,
  'files': [
    {
      'id': 'file-1',
      'path': '/media/scene-1.mp4',
      'basename': 'scene-1.mp4',
      'size': 1024,
      'duration': 60,
      'format': 'mp4',
      'width': 1920,
      'height': 1080,
      'video_codec': 'h264',
      'audio_codec': 'aac',
      'frame_rate': 23.976,
      'bit_rate': 4200000,
    },
  ],
  'paths': {
    'screenshot': '/images/scene-1.jpg',
    'preview': '/previews/scene-1.mp4',
  },
  'performers': [
    {'id': 'person-1', 'name': 'Actor One'},
  ],
  'tags': [
    {'id': 'tag-1', 'name': 'Drama'},
  ],
};

void main() {
  test('Scene 映射为电影条目并支持播放、截图和演员', () async {
    final store = _MemoryTokenStore();
    final credentials = StashApiKeyRepository(store: store);
    await credentials.save('server-1', 'stash-key');
    final adapter = _StashAdapter((options) {
      final query = (options.data as Map)['query'].toString();
      if (query.contains('SceneStreams')) {
        return {
          'data': {
            'sceneStreams': [
              {
                'url': '/stream/scene-1.mp4',
                'mime_type': 'video/mp4',
                'label': 'Original',
              },
            ],
          },
        };
      }
      if (query.contains('SaveSceneActivity')) {
        return {
          'data': {'sceneSaveActivity': null},
        };
      }
      if (query.contains('AddScenePlay')) {
        return {
          'data': {
            'sceneAddPlay': {'count': 3},
          },
        };
      }
      return {
        'data': {
          'findScenes': {
            'count': 1,
            'scenes': [_scene()],
          },
        },
      };
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://stash.test:9999'))
      ..httpClientAdapter = adapter;
    final source = StashMediaSourceAdapter(
      StashApi(dio, serverId: 'server-1', apiKeyRepository: credentials),
      serverId: 'server-1',
      endpoint: 'http://stash.test:9999',
    );

    final page = await source.itemPage(
      parentId: 'stash-scenes',
      includeItemTypes: 'Movie',
      limit: 24,
      sortBy: 'ProductionYear',
      sortOrder: 'Ascending',
    );
    final item = page.items.single;
    expect(source.descriptor.id, const SourceId('stash'));
    expect(source.capabilities, {
      MediaCapability.catalog,
      MediaCapability.movieDetails,
      MediaCapability.playback,
    });
    expect(item.type, 'Movie');
    expect(item.id, 'scene-1');
    expect(item.name, 'Scene details');
    expect(item.code, 'Test Scene');
    expect(item.productionYear, 2024);
    expect(item.communityRating, 8.6);
    expect(item.runTimeTicks, secondsToMediaBrowserTicks(60));
    expect(item.userData.resumeSeconds, 13);
    expect(item.userData.playCount, 2);
    expect(item.primaryImageTag, '/images/scene-1.jpg');
    expect(item.previewPath, '/previews/scene-1.mp4');
    expect(item.backdropImageTags, ['/images/scene-1.jpg']);
    expect(item.people.single.name, 'Actor One');
    expect(item.genres, ['Drama']);
    final streams = item.mediaSources.single.mediaStreams;
    expect(streams, hasLength(2));
    expect(streams[0].type, 'Video');
    expect(streams[0].codec, 'h264');
    expect(streams[0].width, 1920);
    expect(streams[0].height, 1080);
    expect(streams[0].frameRate, '23.976');
    expect(streams[0].bitRate, 4200000);
    expect(streams[1].type, 'Audio');
    expect(streams[1].codec, 'aac');
    final body = Map<String, dynamic>.from(adapter.requests.single.data as Map);
    final variables = Map<String, dynamic>.from(body['variables'] as Map);
    expect(
      Map<String, dynamic>.from(variables['filter'] as Map),
      containsPair('sort', 'date'),
    );
    expect(
      Map<String, dynamic>.from(variables['filter'] as Map),
      containsPair('direction', 'ASC'),
    );

    final descriptor = await source.resolvePlayback(
      const MediaRef(sourceId: SourceId('stash'), value: 'scene-1'),
      const PlaybackRequest(),
    );
    expect(
      descriptor.uri.toString(),
      'http://stash.test:9999/stream/scene-1.mp4',
    );
    expect(descriptor.mimeType, 'video/mp4');
    expect(descriptor.headers, {'ApiKey': 'stash-key'});
    expect(descriptor.startAt, 12.5);

    await source.reportPlaybackStopped(
      itemId: 'scene-1',
      positionTicks: secondsToMediaBrowserTicks(60),
    );
    final queries = adapter.requests
        .map((request) => (request.data as Map)['query'].toString())
        .toList();
    expect(queries.any((query) => query.contains('SaveSceneActivity')), isTrue);
    expect(queries.any((query) => query.contains('AddScenePlay')), isTrue);
  });

  test('固定 Scenes 虚拟媒体库和空可选字段不会崩溃', () async {
    final adapter = _StashAdapter(
      (_) => {
        'data': {
          'findScenes': {'count': 0, 'scenes': null},
        },
      },
    );
    final source = StashMediaSourceAdapter(
      StashApi(
        Dio(BaseOptions(baseUrl: 'http://stash.test'))
          ..httpClientAdapter = adapter,
      ),
      endpoint: 'http://stash.test',
    );

    final views = await source.views();
    expect(views.single.id, 'stash-scenes');
    expect(views.single.name, 'Scenes');
    expect(views.single.collectionType, 'movies');
    expect(views.single.childCount, 0);
    expect((await source.itemPage()).items, isEmpty);
  });

  test('缺少 screenshot 时使用 webp，且 preview 仍为空', () async {
    final scene = _scene()..['paths'] = {'webp': '/images/scene-1.webp'};
    final adapter = _StashAdapter(
      (_) => {
        'data': {
          'findScenes': {
            'count': 1,
            'scenes': [scene],
          },
        },
      },
    );
    final source = StashMediaSourceAdapter(
      StashApi(
        Dio(BaseOptions(baseUrl: 'http://stash.test'))
          ..httpClientAdapter = adapter,
      ),
      endpoint: 'http://stash.test',
    );

    final item = (await source.itemPage()).items.single;
    expect(item.primaryImageTag, '/images/scene-1.webp');
    expect(item.backdropImageTags, ['/images/scene-1.webp']);
    expect(item.previewPath, isNull);
  });
}
