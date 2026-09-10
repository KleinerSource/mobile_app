// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/oh_my_media/tasks/task_center_models_test.dart
//   - test/features/oh_my_media/tasks/task_center_provider_test.dart
//   - test/features/oh_my_media/tasks/task_center_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/modal_transcription_config.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_page.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

// ==================== 原 test/features/oh_my_media/tasks/task_center_models_test.dart ====================
void _main_0() {
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
      'recordId': 'record-audio-1',
      'taskType': 'audio_extract',
      'taskName': '音频提取',
      'displayName': 'ABC-123 · 示例影片',
      'attempt': 1,
      'revision': 3,
      'status': 'running',
      'isRunning': true,
      'canCancel': true,
      'progress': {'total': 100, 'completed': 42, 'percent': 42.0},
      'message': '正在提取音频',
      'movieId': 7,
      'movieTitle': '示例影片',
      'fileName': 'audio.aac',
      'format': 'aac',
      'bitrateKbps': 192,
    });

    expect(task.key, 'task:audio-task-1:1');
    expect(task.taskType, 'audio_extract');
    expect(task.recordId, 'record-audio-1');
    expect(task.revision, 3);
    expect(task.isActive, isTrue);
    expect(task.movieId, 7);
    expect(task.displayName, 'ABC-123 · 示例影片');
    expect(task.movieTitle, '示例影片');
    expect(task.fileName, 'audio.aac');
    expect(task.bitrateKbps, 192);
    expect(task.canCancel, isTrue);
  });

  test('任务能力完全由服务端快照决定', () {
    final task = TaskItem.fromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'resource-scan-1',
      'taskType': 'resource_scan',
      'taskName': '资源扫描',
      'status': 'running',
      'isRunning': true,
      'canCancel': true,
      'canPause': true,
      'canResume': false,
    });

    expect(task.canCancel, isTrue);
    expect(task.canPause, isTrue);
    expect(task.canResume, isFalse);
    expect(
      TaskItem.fromSchedulerMessage(const {
        'type': 'scheduler_status',
        'taskId': 'resource-scan-2',
        'taskType': 'resource_scan',
        'taskName': '资源扫描',
        'status': 'running',
        'isRunning': true,
      }).canCancel,
      isFalse,
    );
  });

  test('任务时间兼容 snake_case，并且历史缺失时间不伪造为当前时间', () {
    final running = TaskItem.fromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'scan-1',
      'taskName': '目录扫描',
      'status': 'running',
      'isRunning': true,
      'start_time': '2026-09-05T06:00:00Z',
    });
    expect(running.startTime, DateTime.parse('2026-09-05T06:00:00Z'));

    final history = TaskItem.fromHistory(const {
      'record_id': 'record-without-time',
      'task_id': 'task-without-time',
      'task_name': '音频提取',
      'status': 'completed',
    });
    expect(history.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('任务历史保留重启恢复决策和原新执行关联', () {
    final history = TaskItem.fromHistory(const {
      'record_id': 'record-new',
      'task_id': 'task-replayed',
      'task_type': 'media_info_probe',
      'task_name': '媒体信息探测',
      'status': 'queued',
      'recovery_decision': 'replay',
      'recovery_reason': '任务定义启用自动重放',
      'previous_record_id': 'record-old',
      'next_record_id': 'record-next',
    });

    expect(history.recoveryDecision, 'replay');
    expect(history.recoveryReason, '任务定义启用自动重放');
    expect(history.previousRecordId, 'record-old');
    expect(history.nextRecordId, 'record-next');
  });

  test('终态任务不显示取消操作，只有失败或取消任务允许重试', () {
    final completed = TaskItem.fromHistory(const {
      'record_id': 'record-completed',
      'task_id': 'transcription-1',
      'task_name': '字幕转译',
      'status': 'completed',
      'phase': 'completed',
      'can_cancel': true,
      'can_retry': true,
    });
    final failed = TaskItem.fromHistory(const {
      'record_id': 'record-failed',
      'task_id': 'transcription-2',
      'task_name': '字幕转译',
      'status': 'failed',
      'phase': 'failed',
      'can_cancel': true,
      'can_retry': true,
    });

    expect(completed.canCancel, isFalse);
    expect(completed.canRetry, isFalse);
    expect(failed.canCancel, isFalse);
    expect(failed.canRetry, isTrue);
  });

  test('字幕转译记录解析错误信息并区分可重试状态', () {
    final failed = TaskItem.fromTranscription(const {
      'id': 12,
      'task_id': 'transcription-12',
      'status': 'failed',
      'can_retry': true,
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
      'task_id': 'transcription-13',
      'status': 'skipped',
      'percent': 100,
    });

    expect(failed.id, 'transcription-12');
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
      'task_id': 'transcription-14',
      'status': 'cancelled',
      'percent': 20,
      'can_retry': true,
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

// ==================== 原 test/features/oh_my_media/tasks/task_center_provider_test.dart ====================
void _main_1() {
  test('服务器连接暂停时不启动任务历史请求', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            handler.resolve(Response<dynamic>(requestOptions: options));
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
      ],
    );
    addTearDown(container.dispose);

    container.read(taskCenterProvider);
    await Future<void>.delayed(Duration.zero);

    expect(requestCount, 0);
  });

  test('单任务 HTTP 快照可以补齐错过的 WS 终态', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = options.path == '/tasks/fanart-task-1'
                ? const {
                    'success': true,
                    'data': {
                      'taskId': 'fanart-task-1',
                      'recordId': 'fanart-record-1',
                      'taskType': 'extra_fanart_download',
                      'attempt': 1,
                      'revision': 3,
                      'status': 'completed',
                      'isRunning': false,
                    },
                  }
                : const {
                    'success': true,
                    'data': {'items': [], 'total': 0, 'stats': {}},
                  };
            handler.resolve(
              Response<dynamic>(requestOptions: options, data: data),
            );
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);
    await notifier.syncTaskSnapshot('fanart-task-1');

    final task = container
        .read(taskCenterProvider)
        .singleWhere((item) => item.id == 'fanart-task-1');
    expect(task.taskType, 'extra_fanart_download');
    expect(task.isCompleted, isTrue);
  });

  test('任务中心按服务端时间排序，缺失时间时保持稳定顺序', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);
    notifier.restore(
      TaskItem.fromHistory(const {
        'record_id': 'record-new',
        'task_id': 'task-new',
        'task_name': '音频提取',
        'status': 'completed',
        'updated_at': '2026-09-05T08:00:00Z',
      }),
    );
    notifier.restore(
      TaskItem.fromHistory(const {
        'record_id': 'record-old',
        'task_id': 'task-old',
        'task_name': '音频提取',
        'status': 'completed',
        'updated_at': '2026-09-05T07:00:00Z',
      }),
    );

    expect(container.read(taskCenterProvider).map((task) => task.id), [
      'task-new',
      'task-old',
    ]);
  });

  test('新增、状态更新和删除任务会同步顶部统计', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? deletedRecordId;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'DELETE') {
              deletedRecordId = options.path.split('/').last;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: const {
                  'success': true,
                  'data': {'items': [], 'total': 0, 'stats': {}},
                },
              ),
            );
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);

    notifier.restore(
      TaskItem.fromHistory(const {
        'record_id': 'record-completed',
        'task_id': 'task-1',
        'task_name': '字幕转译',
        'status': 'running',
      }),
    );
    var meta = container.read(taskCenterMetaProvider);
    expect(meta.total, 1);
    expect(meta.stats['running'], 1);

    notifier.updateFromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'task-1',
      'taskName': '字幕转译',
      'status': 'completed',
      'isRunning': false,
    });
    meta = container.read(taskCenterMetaProvider);
    expect(meta.total, 1);
    expect(meta.stats['running'], 0);
    expect(meta.stats['completed'], 1);

    notifier.restore(
      TaskItem.fromHistory(const {
        'record_id': 'record-failed',
        'task_id': 'task-2',
        'task_name': '字幕转译',
        'status': 'failed',
      }),
    );
    await notifier.remove(container.read(taskCenterProvider).last);
    meta = container.read(taskCenterMetaProvider);
    expect(deletedRecordId, 'record-failed');
    expect(meta.total, 1);
    expect(meta.stats['failed'], 0);
    expect(meta.stats['completed'], 1);
  });

  test('进度广播交错到达时任务保持稳定顺序', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);

    void send(String id, {required bool running}) {
      notifier.updateFromSchedulerMessage(<String, dynamic>{
        'type': 'scheduler_status',
        'taskId': id,
        'taskName': '音频提取',
        'status': running ? 'running' : 'completed',
        'isRunning': running,
        'movieTitle': 'movie-$id',
      });
    }

    List<String> ids() =>
        container.read(taskCenterProvider).map((task) => task.id).toList();

    send('a', running: true);
    send('b', running: true);
    expect(ids(), ['b', 'a'], reason: '新任务排在前面');

    // 两个活跃任务交错收到进度广播，updatedAt 不断刷新，顺序不应互换。
    send('a', running: true);
    send('b', running: true);
    send('a', running: true);
    expect(ids(), ['b', 'a'], reason: '进度更新不得改变任务顺序');

    // a 结束后掉到非活跃区，活跃的 b 保持在顶部。
    send('a', running: false);
    final tasks = container.read(taskCenterProvider);
    expect(tasks.map((task) => task.id), ['b', 'a']);
    expect(tasks.first.isActive, isTrue);
    expect(tasks.last.isTerminal, isTrue);
  });

  test('历史终态与无 recordId 的实时重试不会覆盖旧记录', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);
    notifier.restore(
      TaskItem.fromHistory(const {
        'record_id': 'record-old',
        'task_id': 'retry-1',
        'task_name': '字幕转译',
        'status': 'completed',
        'phase': 'completed',
      }),
    );
    notifier.updateFromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'retry-1',
      'taskName': '字幕转译',
      'status': 'queued',
      'isRunning': true,
    });

    final tasks = container.read(taskCenterProvider);
    expect(tasks, hasLength(2));
    expect(tasks.where((task) => task.recordId == 'record-old'), hasLength(1));
    expect(tasks.where((task) => task.isActive), hasLength(1));
  });

  test('统一预览任务按 revision 合并并拒绝迟到消息', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(taskCenterProvider.notifier);

    notifier.updateFromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'preview-1',
      'recordId': 'preview-record-1',
      'taskType': 'preview_generation',
      'taskName': '预览生成',
      'attempt': 1,
      'revision': 1,
      'status': 'queued',
      'isRunning': true,
      'canCancel': true,
      'progress': {'total': 1, 'completed': 0, 'percent': 0},
      'movieId': 7,
      'movieTitle': '长视频',
    });
    expect(container.read(taskCenterProvider).single.name, '预览生成');
    expect(container.read(taskCenterProvider).single.canCancel, isTrue);

    notifier.updateFromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'preview-1',
      'recordId': 'preview-record-1',
      'taskType': 'preview_generation',
      'taskName': '预览生成',
      'attempt': 1,
      'revision': 2,
      'status': 'running',
      'isRunning': true,
      'canCancel': true,
      'progress': {'total': 1, 'completed': 0, 'percent': 42.5},
    });
    final running = container.read(taskCenterProvider).single;
    expect(running.progress.percent, 42.5);
    expect(running.movieId, 7);
    expect(running.movieTitle, '长视频');

    notifier.updateFromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'preview-1',
      'recordId': 'preview-record-1',
      'taskType': 'preview_generation',
      'taskName': '预览生成',
      'attempt': 1,
      'revision': 1,
      'status': 'completed',
      'isRunning': false,
      'progress': {'total': 1, 'completed': 1, 'percent': 100},
    });
    expect(container.read(taskCenterProvider).single.status, 'running');
    expect(container.read(taskCenterProvider).single.revision, 2);
  });

  test('新 attempt 替换同一逻辑任务的旧活跃投影', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(taskCenterProvider.notifier);

    for (final attempt in const [1, 2]) {
      notifier.updateFromSchedulerMessage({
        'type': 'scheduler_status',
        'taskId': 'replay-1',
        'recordId': 'record-$attempt',
        'taskType': 'subtitle_transcription',
        'taskName': '字幕转译',
        'attempt': attempt,
        'revision': 1,
        'status': attempt == 1 ? 'running' : 'queued',
        'isRunning': true,
      });
    }

    final tasks = container.read(taskCenterProvider);
    expect(tasks, hasLength(1));
    expect(tasks.single.attempt, 2);
    expect(tasks.single.recordId, 'record-2');
  });

  test('任务取消统一调用 TasksApi 并应用返回快照', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? controlPath;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') controlPath = options.path;
            final data = options.method == 'POST'
                ? const {
                    'type': 'scheduler_status',
                    'taskId': 'preview-cancel',
                    'recordId': 'preview-record',
                    'taskType': 'preview_generation',
                    'taskName': '预览生成',
                    'attempt': 1,
                    'revision': 2,
                    'status': 'canceling',
                    'isRunning': true,
                    'canCancel': false,
                  }
                : const {'items': [], 'total': 0, 'stats': {}};
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {'success': true, 'data': data},
              ),
            );
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    notifier.updateFromSchedulerMessage(const {
      'type': 'scheduler_status',
      'taskId': 'preview-cancel',
      'recordId': 'preview-record',
      'taskType': 'preview_generation',
      'taskName': '预览生成',
      'attempt': 1,
      'revision': 1,
      'status': 'running',
      'isRunning': true,
      'canCancel': true,
      'progress': {'total': 1, 'completed': 0, 'percent': 37.5},
      'movieId': 7,
      'movieTitle': '可取消影片',
    });

    await notifier.cancel(container.read(taskCenterProvider).single);

    expect(controlPath, '/tasks/preview-cancel/cancel');
    final task = container.read(taskCenterProvider).single;
    expect(task.status, 'canceling');
    expect(task.isActive, isTrue);
    expect(task.canRetry, isFalse);
  });

  test('任务中心忽略旧的专用 preview_task 消息', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);
    notifier.updateFromSchedulerMessage(const {
      'type': 'preview_task',
      'taskId': 'external-preview-1',
      'status': 'running',
      'isRunning': true,
      'progress': {'total': 1, 'completed': 0, 'percent': 50},
    });

    expect(container.read(taskCenterProvider), isEmpty);
  });
}

// ==================== 原 test/features/oh_my_media/tasks/task_center_page_test.dart ====================
void _main_2() {
  testWidgets('已完成的字幕转译卡片点击进入影片详情', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(taskCenterProvider.notifier)
        .updateFromSchedulerMessage(const <String, dynamic>{
          'type': 'scheduler_status',
          'taskId': 'tr-42',
          'taskType': 'subtitle_transcription',
          'taskName': '字幕转译',
          'status': 'completed',
          'isRunning': false,
          'movieId': 7,
          'movieTitle': '示例影片',
        });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: TaskCenterPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MovieDetailPage), findsNothing);

    await tester.tap(find.text('字幕转译'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MovieDetailPage), findsOneWidget);

    // 卸载页面并销毁容器，取消 WebSocket 重连定时器，避免 pending timer。
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}

void main() {
  group('task_center_models', _main_0);
  group('task_center_provider', _main_1);
  group('task_center_page', _main_2);
}
