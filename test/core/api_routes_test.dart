import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/services/actors_api.dart';
import 'package:omm/core/api/services/audio_api.dart';
import 'package:omm/core/api/services/configs_extended_api.dart';
import 'package:omm/core/api/services/genres_api.dart';
import 'package:omm/core/api/services/mappings_api.dart';
import 'package:omm/core/api/services/movies_api.dart';
import 'package:omm/core/api/services/movies_extended_api.dart';
import 'package:omm/core/api/services/modal_transcription_api.dart';
import 'package:omm/core/api/services/playback_api.dart';
import 'package:omm/core/api/services/series_api.dart';
import 'package:omm/core/api/services/tags_api.dart';
import 'package:omm/core/api/services/translation_api.dart';
import 'package:omm/core/api/services/system_extended_api.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/playback.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/translation/translation_repository.dart';

void main() {
  test('映射 Retrofit 路径使用后端实际的 /mappings/type/{type}', () async {
    final adapter = _RouteAdapter();
    final dio = _dio(adapter);
    await MappingsApi(dio).list('tags', {'limit': 20});

    expect(adapter.paths.single, '/api/mappings/type/tags');
    expect(adapter.queries.single['limit'], '20');
  });

  test('同步演员关联会传递所选渠道', () async {
    final adapter = _RouteAdapter();
    await MappingsApi(
      _dio(adapter),
    ).actorExternalSyncPreview({'actor_name': '演员 A', 'source': 'avdb'});

    expect(adapter.paths.single, '/api/mappings/actors/external-sync/preview');
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

  test('演员数据源应用会传递头像地址', () async {
    final adapter = _RouteAdapter();
    await MappingsApi(_dio(adapter)).actorExternalSyncApply({
      'mapped_value': '演员 A',
      'original_values': <String>[],
      'source': 'dbonline',
      'avatar_url': 'https://example.com/avatar.jpg',
      'avatar_overwrite': true,
    });

    expect(adapter.paths.single, '/api/mappings/actors/external-sync/apply');
    expect(
      adapter.requestBodies.single['avatar_url'],
      'https://example.com/avatar.jpg',
    );
    expect(adapter.requestBodies.single['avatar_overwrite'], isTrue);
  });

  test('混合渠道预览与应用传递 source 与多来源身份', () async {
    final previewAdapter = _RouteAdapter();
    await MappingsApi(
      _dio(previewAdapter),
    ).actorExternalSyncPreview({'actor_name': '演员 A', 'source': 'mixed'});
    expect(
      previewAdapter.paths.single,
      '/api/mappings/actors/external-sync/preview',
    );
    expect(previewAdapter.requestBodies.single['source'], 'mixed');

    final applyAdapter = _RouteAdapter();
    await MappingsApi(_dio(applyAdapter)).actorExternalSyncApply({
      'mapped_value': '演员 A',
      'original_values': <String>[],
      'source': 'mixed',
      'biography': '演员简介',
      'avatar_url': '/api/image?url=a.png',
      'avatar_source': 'dbonline',
      'external_ids': {'dbonline': 'MW44', 'avdb': '290438'},
    });
    expect(applyAdapter.requestBodies.single['source'], 'mixed');
    expect(applyAdapter.requestBodies.single['avatar_source'], 'dbonline');
    expect(applyAdapter.requestBodies.single['external_ids'], {
      'dbonline': 'MW44',
      'avdb': '290438',
    });
  });

  test('混合渠道渐进预览会话使用独立启动与轮询接口', () async {
    final adapter = _RouteAdapter();
    final api = MappingsApi(_dio(adapter));

    await api.mixedExternalSyncPreviewStart({'actor_name': '演员 A'});
    await api.mixedExternalSyncPreviewSession('task-1');

    expect(adapter.paths, <String>[
      '/api/mappings/actors/external-sync/preview/mixed',
      '/api/mappings/actors/external-sync/preview/mixed/task-1',
    ]);
    expect(adapter.requestBodies.single, {'actor_name': '演员 A'});
  });

  test('演员头像预览使用鉴权二进制接口', () async {
    final adapter = _RouteAdapter();
    final response = await ActorsApi(_dio(adapter)).previewAvatar({
      'avatar_url': 'https://example.com/avatar.jpg',
      'source': 'avdb',
    });

    expect(adapter.paths.single, '/api/actors/avatar/preview');
    expect(
      adapter.requestBodies.single['avatar_url'],
      'https://example.com/avatar.jpg',
    );
    expect(adapter.requestBodies.single['source'], 'avdb');
    expect(response.data, isNotEmpty);
  });

  test('影片编辑器选项接口传递搜索关键词', () async {
    final cases = <(String, Future<dynamic> Function(Dio))>[
      (
        '/api/actors/options',
        (dio) => ActorsApi(
          dio,
        ).options({'search': '演员', 'offset': 100, 'limit': 50}),
      ),
      (
        '/api/genres/options',
        (dio) => GenresApi(
          dio,
        ).options({'search': '分类', 'offset': 100, 'limit': 50}),
      ),
      (
        '/api/tags/options',
        (dio) =>
            TagsApi(dio).options({'search': '标签', 'offset': 100, 'limit': 50}),
      ),
      (
        '/api/series/options',
        (dio) => SeriesApi(
          dio,
        ).options({'search': '系列', 'offset': 100, 'limit': 50}),
      ),
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
      final result = await OmmMediaSourceAdapter(
        ApiClient(dio),
      ).startBatchScan(incremental: incremental);

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

    expect(adapter.paths.single, '/api/movies/batch/dbonline/resources/scan');
    expect(adapter.requestBodies.single['scan_all'], true);
    expect(adapter.requestBodies.single['filters'], {
      'has_new_resources': true,
      'genre_ids': [3, 8],
    });
  });

  test('影片预览图获取使用详情页数据源接口', () async {
    final adapter = _RouteAdapter();
    await MoviesExtendedApi(_dio(adapter)).downloadDbonlineExtrafanart(7);

    expect(adapter.paths.single, '/api/movies/id/7/dbonline/extrafanart');
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

  test('转码状态接口透传完整会话参数', () async {
    final adapter = _RouteAdapter();
    final api = PlaybackApi(_dio(adapter));

    await api.status(
      7,
      quality: '720p',
      mode: 'dstream',
      audioStreamIndex: 2,
      subtitleTrackId: 'embedded-3',
    );
    await api
        .events(
          7,
          quality: '720p',
          mode: 'dstream',
          audioStreamIndex: 2,
          subtitleTrackId: 'embedded-3',
        )
        .toList();

    expect(adapter.queries, hasLength(2));
    for (final query in adapter.queries) {
      expect(query, {
        'quality': '720p',
        'mode': 'dstream',
        'audio_stream_index': '2',
        'subtitle_track_id': 'embedded-3',
      });
    }
  });

  test('服务器资料接口读取名称并解析头像地址', () async {
    final adapter = _RouteAdapter();
    final profile = await SystemExtendedApi(
      _dio(adapter),
      config: const ServerConfig(baseUrl: 'http://test'),
    ).serverProfile();

    expect(adapter.paths.single, '/api/public/server-profile');
    expect(profile.name, '测试服务器');
    expect(profile.avatarUrl, 'http://test/api/public/avatar');
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

  test('云端转译与音频任务接口使用后端实际路径和参数', () async {
    final audioAdapter = _RouteAdapter();
    final audio = AudioApi(_dio(audioAdapter));

    await audio.listTranscriptions(limit: 25, offset: 5, status: 'failed');
    await audio.extractAudio(movieId: 7, format: 'm4a', bitrateKbps: 256);
    await audio.cancelAudioExtraction('extract-1');
    await audio.cancelSubtitleTranscription('12');
    await audio.retrySubtitleTranscription('13', overwrite: true);

    expect(audioAdapter.paths, <String>[
      '/api/audios/transcriptions',
      '/api/audios/extract',
      '/api/audios/extract/extract-1/cancel',
      '/api/audios/transcriptions/12/cancel',
      '/api/audios/transcriptions/13/retry',
    ]);
    expect(audioAdapter.queries.first, {
      'limit': '25',
      'offset': '5',
      'status': 'failed',
    });
    expect(
      audioAdapter.requestBodies.any(
        (body) =>
            body['movie_id'] == 7 &&
            body['format'] == 'm4a' &&
            body['bitrate_kbps'] == 256,
      ),
      isTrue,
    );
    expect(
      audioAdapter.requestBodies.any((body) => body['overwrite'] == true),
      isTrue,
    );

    final configAdapter = _RouteAdapter();
    final config = ModalTranscriptionApi(_dio(configAdapter));
    await config.getConfig();
    await config.saveConfig({'enabled': true});

    expect(configAdapter.paths, <String>[
      '/api/modal-transcription/config',
      '/api/modal-transcription/config',
    ]);
    expect(configAdapter.requestBodies.single, {'enabled': true});
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
        'event: status\ndata: ${jsonEncode({'active': true, 'quality': '1080p', 'hw_accel': 'videotoolbox', 'hw_decode_ok': true, 'hw_encode_ok': true})}\n\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }

    if (path == '/api/actors/avatar/preview') {
      return ResponseBody.fromBytes(
        <int>[0xFF, 0xD8, 0xFF, 0xD9],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    }

    final data = switch (path) {
      '/api/movies/id/7/playback-decision' => {
        'mode': 'direct_play',
        'stream_url': '/api/movies/id/7/stream?mode=direct',
        'direct_url': '/api/movies/id/7/stream',
        'quality_options': [
          {'id': 'auto', 'label': '自动', 'kind': 'auto'},
          {'id': 'original', 'label': '1080P（原生）', 'kind': 'original'},
        ],
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
      '/api/public/server-profile' => {
        'name': '测试服务器',
        'avatar_url': '/api/public/avatar',
      },
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
