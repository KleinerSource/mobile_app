import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/modal_transcription_config.dart';
import 'package:md_center/features/tasks/task_model.dart';

void main() {
  test('任务进度可以兼容数字和字符串，并限制展示百分比', () {
    final progress = TaskProgress.fromJson(const {
      'total': '8',
      'completed': 10.8,
      'percent': 125,
    });

    expect(progress.total, 8);
    expect(progress.completed, 10);
    expect(progress.clampedPercent, 100);
  });

  test('调度器消息解析任务类型、媒体信息和进行中状态', () {
    final task = TaskItem.fromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'audio-task-1',
      'taskName': '音频提取',
      'status': 'running',
      'isRunning': true,
      'progress': {'total': 100, 'completed': 42, 'percent': 42.0},
      'message': '正在提取音频',
      'movieId': 7,
      'movieTitle': '示例影片',
      'fileName': 'audio.aac',
      'format': 'aac',
      'bitrateKbps': 192,
    });

    expect(task.key, '音频提取:audio-task-1');
    expect(task.isActive, isTrue);
    expect(task.movieId, 7);
    expect(task.movieTitle, '示例影片');
    expect(task.fileName, 'audio.aac');
    expect(task.bitrateKbps, 192);
    expect(task.canCancel, isTrue);
  });

  test('字幕转译记录解析错误信息并区分可重试状态', () {
    final failed = TaskItem.fromTranscription(const {
      'id': 12,
      'status': 'failed',
      'percent': 64.5,
      'error_message': '远端任务失败',
      'movie_id': 8,
      'movie_title': '另一部影片',
      'movie_file_name': 'movie.mkv',
      'audio_file_name': 'movie.aac',
      'updated_at': '2026-08-21T08:00:00Z',
    });
    final skipped = TaskItem.fromTranscription(const {
      'id': 13,
      'status': 'skipped',
      'percent': 100,
    });

    expect(failed.id, '12');
    expect(failed.message, '远端任务失败');
    expect(failed.progress.completed, 65);
    expect(failed.canRetry, isTrue);
    expect(failed.isFailed, isTrue);
    expect(failed.isCanceled, isFalse);
    expect(skipped.canRetry, isFalse);
    expect(skipped.isTerminal, isTrue);
    expect(skipped.isCompleted, isTrue);

    final canceled = TaskItem.fromTranscription(const {
      'id': 14,
      'status': 'cancelled',
      'percent': 20,
    });
    expect(canceled.isCanceled, isTrue);
    expect(canceled.canRetry, isTrue);
  });

  test('云端转译配置读取脱敏凭据，保存时不覆盖原凭据', () {
    final loaded = ModalTranscriptionConfig.fromJson(const {
      'enabled': true,
      'modal_token_id': '********2345',
      'modal_token_secret': '********6789',
      'hf_token': '********abcd',
      'has_modal_token_id': true,
      'has_modal_token_secret': true,
      'has_hf_token': true,
      'default_gpu': 'L4',
      'default_model': 'chickenrice',
      'repo_branch': 'v1.9',
      'default_formats': [],
      'max_workers': 3,
    });

    expect(loaded.modalTokenId, isEmpty);
    expect(loaded.modalTokenSecret, isEmpty);
    expect(loaded.hfToken, isEmpty);
    expect(loaded.hasModalTokenId, isTrue);
    expect(loaded.defaultFormats, const ['srt']);
    expect(loaded.toRequest().containsKey('modal_token_id'), isFalse);
    expect(loaded.toRequest()['max_workers'], 3);

    final replacement = loaded.copyWith(modalTokenSecret: 'new-secret');
    expect(replacement.toRequest()['modal_token_secret'], 'new-secret');
  });
}
