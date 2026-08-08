import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/mappings_api.dart';
import 'package:md_center/core/api/services/playback_api.dart';
import 'package:md_center/core/models/playback.dart';

void main() {
  test('映射 Retrofit 路径使用后端实际的 /mappings/type/{type}', () async {
    final adapter = _RouteAdapter();
    final dio = _dio(adapter);
    await MappingsApi(dio).list('tags', {'limit': 20});

    expect(adapter.paths.single, '/api/mappings/type/tags');
    expect(adapter.queries.single['limit'], '20');
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

    expect(
      adapter.paths,
      containsAll(<String>[
        '/api/movies/id/7/playback-decision',
        '/api/movies/id/7/stream-url',
        '/api/movies/id/7/transcode-status',
        '/api/movies/id/7/transcode-events',
        '/api/movies/id/7/transcode-session',
      ]),
    );
  });
}

Dio _dio(_RouteAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
}

class _RouteAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final queries = <Map<String, String>>[];

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
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data}),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}
