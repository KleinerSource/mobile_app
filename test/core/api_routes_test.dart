import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/actors_api.dart';
import 'package:md_center/core/api/services/configs_extended_api.dart';
import 'package:md_center/core/api/services/genres_api.dart';
import 'package:md_center/core/api/services/libraries_api.dart';
import 'package:md_center/core/api/services/libraries_extended_api.dart';
import 'package:md_center/core/api/services/mappings_api.dart';
import 'package:md_center/core/api/services/movies_api.dart';
import 'package:md_center/core/api/services/movies_extended_api.dart';
import 'package:md_center/core/api/services/playback_api.dart';
import 'package:md_center/core/api/services/series_api.dart';
import 'package:md_center/core/api/services/tags_api.dart';
import 'package:md_center/core/api/services/translation_api.dart';
import 'package:md_center/core/models/playback.dart';
import 'package:md_center/features/libraries/libraries_repository.dart';
import 'package:md_center/features/translation/translation_repository.dart';

void main() {
  test('映射 Retrofit 路径使用后端实际的 /mappings/type/{type}', () async {
    final adapter = _RouteAdapter();
    final dio = _dio(adapter);
    await MappingsApi(dio).list('tags', {'limit': 20});

    expect(adapter.paths.single, '/api/mappings/type/tags');
    expect(adapter.queries.single['limit'], '20');
  });

  test('演员数据源同步会传递所选渠道', () async {
    final adapter = _RouteAdapter();
    await MappingsApi(_dio(adapter)).actorExternalSyncPreview({
      'actor_name': '演员 A',
      'source': 'avdb',
    });

    expect(
      adapter.paths.single,
      '/api/mappings/actors/external-sync/preview',
    );
    expect(adapter.requestBodies.single['source'], 'avdb');
  });

  test('演员数据源应用会传递渠道和 AVDB 简介', () async {
    final adapter = _RouteAdapter();
    await MappingsApi(_dio(adapter)).actorExternalSyncApply({
      'mapped_value': '演员 A',
      'original_values': <String>[],
      'source': 'avdb',
      'biography': '演员简介',
    });

    expect(adapter.paths.single, '/api/mappings/actors/external-sync/apply');
    expect(adapter.requestBodies.single['source'], 'avdb');
    expect(adapter.requestBodies.single['biography'], '演员简介');
  });

  test('影片编辑器选项接口传递搜索关键词', () async {
    final cases = <(String, Future<dynamic> Function(Dio))>[
      ('/api/actors/options', (dio) => ActorsApi(dio).options({
            'search': '演员',
            'offset': 100,
            'limit': 50,
          })),
      ('/api/genres/options', (dio) => GenresApi(dio).options({
            'search': '分类',
            'offset': 100,
            'limit': 50,
          })),
      ('/api/tags/options', (dio) => TagsApi(dio).options({
            'search': '标签',
            'offset': 100,
            'limit': 50,
          })),
      ('/api/series/options', (dio) => SeriesApi(dio).options({
            'search': '系列',
            'offset': 100,
            'limit': 50,
          })),
    ];

    for (final (path, request) in cases) {
      final adapter = _RouteAdapter();
      await request(_dio(adapter));
      expect(adapter.paths.single, path);
      expect(adapter.queries.single['offset'], '100');
      expect(adapter.queries.single['limit'], '50');
    }
  });

  test('数据源和 FFmpeg 配置接口使用后端路径', () async {
    final adapter = _RouteAdapter();
    final api = ConfigsExtendedApi(_dio(adapter));

    await api.avdb();
    await api.ffmpeg();

    expect(adapter.paths, <String>['/api/configs/avdb', '/api/configs/ffmpeg']);
  });

  test('媒体库批量增量和全量扫描均由单个后端接口发起', () async {
    for (final incremental in const [true, false]) {
      final adapter = _RouteAdapter();
      final dio = _dio(adapter);
      final result = await LibrariesRepository(
        LibrariesApi(dio),
        LibrariesExtendedApi(dio),
      ).batchScan(incremental: incremental);

      expect(adapter.paths.single, '/api/libraries/scan');
      expect(adapter.requestBodies.single, {'incremental': incremental});
      expect(result.acceptedCount, 2);
      expect(result.skippedDisabledCount, 1);
      expect(result.tasks.map((task) => task.libraryId).toList(), [1, 3]);
    }
  });

  test('影片资源扫描使用批量扫描接口并传递筛选体', () async {
    final adapter = _RouteAdapter();
    final api = MoviesExtendedApi(_dio(adapter));

    await api.batchResourceScan({
      'scan_all': true,
      'favorite_only': false,
      'filters': {
        'has_new_resources': true,
        'genre_ids': [3, 8],
      },
    });

    expect(
      adapter.paths.single,
      '/api/movies/batch/dbonline/resources/scan',
    );
    expect(adapter.requestBodies.single['scan_all'], true);
    expect(adapter.requestBodies.single['filters'], {
      'has_new_resources': true,
      'genre_ids': [3, 8],
    });
  });

  test('影片预览图获取使用详情页数据源接口', () async {
    final adapter = _RouteAdapter();
    await MoviesExtendedApi(_dio(adapter)).downloadDbonlineExtrafanart(7);

    expect(
      adapter.paths.single,
      '/api/movies/id/7/dbonline/extrafanart',
    );
  });

  test('播放接口覆盖决策、串流地址、状态、SSE 和停止会话', () async {
    final adapter = _RouteAdapter();
    final api = PlaybackApi(_dio(adapter));
    const caps = PlaybackClientCaps(
      containers: ['mp4'],
      videoCodecs: {},
      audioCodecs: {},
    );

    final decision = await api.decision(7, caps);
    expect(decision.mode, 'direct_play');
    expect(await api.streamUrl(7), '/api/movies/id/7/stream?mode=direct');
    expect((await api.status(7)).active, isTrue);
    expect((await api.events(7).toList()).single.quality, '1080p');
    await api.stop(7);
    await MoviesApi(_dio(adapter)).acknowledgeResources(7);

    expect(
      adapter.paths,
      containsAll(<String>[
        '/api/movies/id/7/playback-decision',
        '/api/movies/id/7/stream-url',
        '/api/movies/id/7/transcode-status',
        '/api/movies/id/7/transcode-events',
        '/api/movies/id/7/transcode-session',
        '/api/movies/id/7/dbonline/resources/acknowledge',
      ]),
    );
  });

  test('翻译模型请求使用服务器已保存的 API Key', () async {
    final adapter = _RouteAdapter();
    final repository = TranslationRepository(TranslationApi(_dio(adapter)));

    await repository.fetchModels(' https://translate.example/ ', '');

    expect(adapter.requestBodies.single, {
      'api_url': 'https://translate.example/',
      'api_key': '__saved__',
    });
  });
}

Dio _dio(_RouteAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
}

class _RouteAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final queries = <Map<String, String>>[];
  final requestBodies = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    queries.add(options.uri.queryParameters);
    if (options.data is Map) {
      requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    final path = options.uri.path;
    if (path.endsWith('/transcode-events')) {
      return ResponseBody.fromString(
        'event: status\ndata: ${jsonEncode({
          'active': true,
          'quality': '1080p',
          'hw_accel': 'videotoolbox',
          'hw_decode_ok': true,
          'hw_encode_ok': true,
        })}\n\n',
        200,
        headers: {Headers.contentTypeHeader: ['text/event-stream']},
      );
    }

    final data = switch (path) {
      '/api/movies/id/7/playback-decision' => {
          'mode': 'direct_play',
          'stream_url': '/api/movies/id/7/stream?mode=direct',
          'mime_type': 'video/mp4',
          'audio_tracks': [],
          'subtitle_tracks': [],
        },
      '/api/movies/id/7/stream-url' => {
          'url': '/api/movies/id/7/stream?mode=direct',
        },
      '/api/movies/id/7/transcode-status' => {
          'active': true,
          'quality': '1080p',
          'hw_accel': 'videotoolbox',
          'hw_decode_ok': true,
          'hw_encode_ok': true,
        },
      '/api/libraries/scan' => {
          'scan_type': '全量扫描',
          'enabled_count': 2,
          'accepted_count': 2,
          'reused_count': 0,
          'failed_count': 0,
          'skipped_disabled_count': 1,
          'tasks': [
            {
              'library_id': 1,
              'library_name': 'Library 1',
              'task_id': 'task-1',
              'status': 'running',
              'queue_position': 0,
              'reused': false,
            },
            {
              'library_id': 3,
              'library_name': 'Library 3',
              'task_id': 'task-3',
              'status': 'queued',
              'queue_position': 1,
              'reused': false,
            },
          ],
        },
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data}),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}
