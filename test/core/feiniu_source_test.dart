import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/feiniu_media_source_adapter.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/features/media_browser/api/feiniu_api.dart';

void main() {
  test('飞牛适配器分页并生成带鉴权头的播放描述', () async {
    final sessions = AuthSessionRepository(store: _MemoryTokenStore())
      ..setActiveServerId('feiniu');
    await sessions.save(
      const AuthSession(accessToken: 'token-1', refreshToken: '', expiresIn: 0),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test/v/api/v1'))
      ..httpClientAdapter = _FeiniuSourceAdapter();
    final source = FeiniuMediaSourceAdapter(
      FeiniuApi(dio),
      sessionRepository: sessions,
      endpoint: 'http://test',
    );

    final page = await source.listMovies(const MediaQuery(limit: 1));
    final descriptor = await source.resolvePlayback(
      const MediaRef(sourceId: SourceId('feiniu'), value: 'item-1'),
      const PlaybackRequest(),
    );

    expect(page.items.single.title, '示例影片');
    expect(page.total, 1);
    expect(
      descriptor.uri.toString(),
      'http://test/v/api/v1/media/range/media-1',
    );
    expect(descriptor.headers, {
      'Authorization': 'token-1',
      'X-Trim-Client': 'web',
      'X-Trim-Client-Version': '616',
    });
    expect(descriptor.mimeType, 'video/x-matroska');
  });
}

class _FeiniuSourceAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final data = switch (path) {
      '/v/api/v1/item/list' => {
        'list': [
          {
            'guid': 'item-1',
            'title': '示例影片',
            'type': 'Movie',
            'can_play': true,
            'media_guid': 'media-1',
            'file_name': 'movie.mkv',
          },
        ],
        'total': 1,
      },
      '/v/api/v1/item/item-1' => {
        'guid': 'item-1',
        'title': '示例影片',
        'type': 'Movie',
        'can_play': true,
        'media_guid': 'media-1',
        'file_name': 'movie.mkv',
      },
      '/v/api/v1/stream/list/item-1' => {
        'video_streams': [
          {'guid': 'video-1', 'title': 'H.265'},
        ],
        'audio_streams': [
          {'guid': 'audio-1', 'title': '国语', 'index': 0, 'is_default': true},
        ],
        'subtitle_streams': <Map<String, Object?>>[],
      },
      '/v/api/v1/play/info' => {
        'item_guid': 'item-1',
        'media_guid': 'media-1',
        'video_guid': 'video-1',
        'audio_guid': 'audio-1',
      },
      _ => <String, Object?>{},
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
