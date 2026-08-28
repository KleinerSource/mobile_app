import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/modal_transcription_config.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';

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

  test('云端转译配置解析多令牌脱敏列表并生成完整目标提交', () {
    final loaded = ModalTranscriptionConfig.fromJson(const {
      'enabled': true,
      'tokens': [
        {'id': 'tok-1', 'name': '主账号', 'token_id_masked': '********2345'},
        {'id': 'tok-2', 'name': '', 'token_id_masked': '********6789'},
      ],
      'token_strategy': 'fill_first',
      'per_token_workers': 2,
      'hf_token': '********abcd',
      'has_hf_token': true,
      'default_gpu': 'L4',
      'default_model': 'chickenrice',
      'repo_branch': 'v1.9',
      'default_formats': [],
      'max_workers': 3,
    });

    expect(loaded.tokens, hasLength(2));
    expect(loaded.tokens.first.id, 'tok-1');
    // 脱敏值不会被当作新凭据再次提交。
    expect(loaded.tokens.first.tokenId, isEmpty);
    expect(loaded.tokens.first.tokenIdMasked, '********2345');
    expect(loaded.hfToken, isEmpty);
    expect(loaded.hasHfToken, isTrue);
    expect(loaded.tokenStrategy, 'fill_first');
    expect(loaded.perTokenWorkers, 2);
    expect(loaded.defaultFormats, const ['srt']);

    final request = loaded.toRequest();
    // 既有令牌未输入新凭据时只提交稳定 id 与备注。
    expect(request['tokens'], [
      {'id': 'tok-1', 'name': '主账号'},
      {'id': 'tok-2', 'name': ''},
    ]);
    expect(request['token_strategy'], 'fill_first');
    expect(request['per_token_workers'], 2);
    expect(request['max_workers'], 3);
    expect(request.containsKey('hf_token'), isFalse);

    final updated = loaded.copyWith(
      tokens: [loaded.tokens.first.copyWith(tokenSecret: ' new-secret ')],
      hfToken: ' hf-new ',
    );
    final updatedRequest = updated.toRequest();
    expect(updatedRequest['tokens'], [
      {'id': 'tok-1', 'name': '主账号', 'token_secret': 'new-secret'},
    ]);
    expect(updatedRequest['hf_token'], 'hf-new');
  });
}
