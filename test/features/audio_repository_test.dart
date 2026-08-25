import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/features/audio/audio_models.dart';
import 'package:omm/features/audio/audio_repository.dart';

void main() {
  test('listAssets 解出资产列表与转译统计', () async {
    final adapter = _AudioAdapter();
    final repository = AudioRepository(ApiClient(_dio(adapter)).audio);

    final page = await repository.listAssets(
      limit: 10,
      offset: 20,
      search: '关键词',
    );

    expect(adapter.queries[0]['limit'], 10);
    expect(adapter.queries[0]['offset'], 20);
    expect(adapter.queries[0]['search'], '关键词');
    expect(page.total, 2);
    expect(page.totalBytes, 4096);
    expect(page.transcriptionActiveCount, 1);

    final running = page.items.first;
    expect(running.id, 11);
    expect(running.movieId, 7);
    expect(running.movieTitle, '影片 A');
    expect(running.fileName, 'a.mp3');
    expect(running.formatLabel, 'MP3');
    expect(running.isTranscriptionActive, isTrue);
    expect(running.transcriptionView.stageLabel, '云端转译');
    expect(running.transcriptionView.clampedPercent, 42);

    final done = page.items.last;
    expect(done.isTranscriptionDone, isTrue);
    expect(done.transcriptionView.downloadUrl, '/api/movies/id/7/subtitles/3');
    expect(done.formatLabel, 'M4A / AAC');
    expect(done.isTranscriptionActive, isFalse);
  });

  test('deleteAssets 提交 ids 并解出删除与拒绝明细', () async {
    final adapter = _AudioAdapter();
    final repository = AudioRepository(ApiClient(_dio(adapter)).audio);

    final result = await repository.deleteAssets([11, 12]);

    expect(adapter.requestBodies[0]['ids'], [11, 12]);
    expect(result.deleted, [11]);
    expect(result.rejected.single.id, 12);
    expect(result.rejected.single.message, '该音频仍有排队或运行中的字幕转译任务，暂不能删除');
  });

  test('enqueueTranscriptions 提交资产与覆盖开关并解出受理结果', () async {
    final adapter = _AudioAdapter();
    final repository = AudioRepository(ApiClient(_dio(adapter)).audio);

    final result = await repository.enqueueTranscriptions([
      11,
    ], overwrite: true);

    expect(adapter.requestBodies[0]['audio_asset_ids'], [11]);
    expect(adapter.requestBodies[0]['overwrite'], isTrue);
    expect(result.accepted, 1);
    expect(result.rejected, isEmpty);
  });

  test('取消与重试转译走音频资产 ID 路径', () async {
    final adapter = _AudioAdapter();
    final repository = AudioRepository(ApiClient(_dio(adapter)).audio);

    await repository.cancelTranscription(11);
    await repository.retryTranscription(11, overwrite: false);
    await repository.cancelExtraction('task-1');

    expect(adapter.paths, [
      '/api/audios/transcriptions/11/cancel',
      '/api/audios/transcriptions/11/retry',
      '/api/audios/extract/task-1/cancel',
    ]);
    expect(adapter.requestBodies[0], isEmpty);
    expect(adapter.requestBodies[1]['overwrite'], isFalse);
  });

  test('转译失败与取消状态解析', () {
    final failed = AudioAsset.fromJson(const {
      'id': 21,
      'movie_id': 1,
      'transcription': {'status': 'failed', 'error_message': '云端连接超时'},
    });
    expect(failed.transcriptionView.isFailed, isTrue);
    expect(failed.transcriptionView.errorMessage, '云端连接超时');
    expect(failed.isTranscriptionDone, isFalse);

    final canceled = AudioAsset.fromJson(const {
      'id': 22,
      'transcription': {'status': 'canceled'},
    });
    expect(canceled.transcriptionView.isCanceled, isTrue);

    final plain = AudioAsset.fromJson(const {
      'id': 23,
      'subtitle_translated': true,
    });
    expect(plain.transcription, isNull);
    expect(plain.isTranscriptionDone, isTrue);
    expect(plain.transcriptionView.stageLabel, '');
  });
}

Dio _dio(_AudioAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = adapter;
}

class _AudioAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final queries = <Map<String, dynamic>>[];
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
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    if (options.data is Map) {
      requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    } else {
      requestBodies.add(<String, dynamic>{});
    }

    final Object? data;
    switch (options.uri.path) {
      case '/api/audios':
        data = {
          'items': [
            {
              'id': 11,
              'movie_id': 7,
              'movie_title': '影片 A',
              'movie_file_name': 'a.mkv',
              'file_name': 'a.mp3',
              'format': 'mp3',
              'bitrate_kbps': 192,
              'file_size': 2048,
              'duration_sec': 61.6,
              'file_exists': true,
              'transcription': {
                'status': 'running',
                'stage': 'transcribing',
                'percent': 41.8,
                'message': '正在云端转译',
              },
            },
            {
              'id': 12,
              'movie_id': 8,
              'movie_title': '影片 B',
              'file_name': 'b.m4a',
              'format': 'm4a',
              'file_size': 2048,
              'subtitle_translated': true,
              'transcription': {
                'status': 'completed',
                'download_url': '/api/movies/id/7/subtitles/3',
              },
            },
          ],
          'total': 2,
          'total_bytes': 4096,
          'transcription_active_count': 1,
        };
      case '/api/audios/delete':
        data = {
          'deleted': [11],
          'rejected': [
            {'id': 12, 'message': '该音频仍有排队或运行中的字幕转译任务，暂不能删除'},
          ],
        };
      case '/api/audios/transcriptions':
        data = {
          'items': [
            {'id': '11'},
          ],
          'rejected': [],
        };
      default:
        data = null;
    }

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
