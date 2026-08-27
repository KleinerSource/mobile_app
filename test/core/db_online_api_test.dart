import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/services/db_online_api.dart';

void main() {
  test('dbonline 首页接口使用固定参数并解析 data.movies', () async {
    final adapter = _DbOnlineAdapter();
    final api = DbOnlineApi(
      Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final recommend = await api.recommend();
    final updated = await api.latest(sortBy: 'update');
    final released = await api.latest(sortBy: 'release');
    final detail = await api.detail('ABC-001', refresh: true);
    final detailByVideoId = await api.detailByVideoId('vid-1');
    final episodes = await api.onlinePlayEpisodes(
      'ABC-001',
      sourceId: 2,
      videoId: 'vid-1',
    );

    expect(recommend.single.id, 'movie-1');
    expect(recommend.single.thumbUrl, '/api/image?id=1');
    expect(recommend.single.canPlay, isTrue);
    expect(updated, isNotEmpty);
    expect(released, isNotEmpty);
    expect(detail.code, 'ABC-001');
    expect(detailByVideoId.code, 'ABC-001');
    expect(detail.canPlay, isTrue);
    expect(detail.playSources.single.id, 2);
    expect(detail.magnets.single.magnet, startsWith('magnet:'));
    expect(episodes.episodes.single.qualities.single.name, '1080p');
    expect(episodes.episodes.single.url, contains('playlist.m3u8'));
    expect(adapter.requests, <String>[
      '/api/recommend?page=1&limit=9',
      '/api/latest?page=1&limit=9&type=all&sort_by=update&filter_by=magnets',
      '/api/latest?page=1&limit=9&type=all&sort_by=release&filter_by=magnets',
      '/api/video/ABC-001?refresh=true',
      '/api/video/id/vid-1',
      '/api/video/ABC-001/online-play/episodes?source_id=2&video_id=vid-1',
    ]);
  });
}

class _DbOnlineAdapter implements HttpClientAdapter {
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      options.uri.path + (options.uri.hasQuery ? '?${options.uri.query}' : ''),
    );
    return ResponseBody.fromString(
      jsonEncode(_responseFor(options.uri.path)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _responseFor(String path) {
    if (path.contains('/online-play/episodes')) {
      return {
        'success': true,
        'data': {
          'code': 'ABC-001',
          'video_id': 'vid-1',
          'source_id': 2,
          'episodes': [
            {
              'index': 0,
              'name': '第 1 集',
              'url': '/video/ABC-001/online-play/playlist.m3u8?target=x',
              'quality': '1080p',
              'qualities': [
                {
                  'name': '1080p',
                  'url': '/video/ABC-001/online-play/playlist.m3u8?target=x',
                },
              ],
            },
          ],
        },
      };
    }
    if (path.contains('/video/ABC-001') || path.contains('/video/id/vid-1')) {
      return {
        'success': true,
        'data': {
          'code': 'ABC-001',
          'title': '示例影片',
          'video_id': 'vid-1',
          'cover_url': 'https://example.com/cover.jpg',
          'date': '2024-01-01',
          'duration': 120,
          'score': 4.6,
          'director': {'external_id': 'd1', 'name': '导演'},
          'categories': [
            {'external_id': '88', 'name': '剧情'},
          ],
          'actors': [
            {'external_id': 'a1', 'name': '演员', 'gender': '♀'},
          ],
          'magnets': [
            {'name': '资源', 'magnet': 'magnet:?xt=urn:btih:x'},
          ],
          'ed2ks': [],
          'can_play': true,
          'play_sources': [
            {'id': 2, 'name': 'JavDB'},
          ],
        },
      };
    }
    return {
      'success': true,
      'data': {
        'movies': [
          {
            'id': 'movie-1',
            'number': 'ABC-001',
            'title': '示例影片',
            'thumb_url': '/api/image?id=1',
            'cover_url': 'https://example.com/cover.jpg',
            'release_date': '2024-01-01',
            'magnets_count': 2,
            'has_cnsub': true,
            'score': 8.5,
            'can_play': true,
          },
        ],
      },
    };
  }
}
