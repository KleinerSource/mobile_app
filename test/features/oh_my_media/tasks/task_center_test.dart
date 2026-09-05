// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/oh_my_media/tasks/task_center_models_test.dart
//   - test/features/oh_my_media/tasks/task_center_provider_test.dart
//   - test/features/oh_my_media/tasks/task_center_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/modal_transcription_config.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
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

// ==================== 原 test/features/oh_my_media/tasks/task_center_provider_test.dart ====================
void _main_1() {
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

  test('preview_task 消息进入任务中心并展示细粒度进度', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverConfigProvider.overrideWith(
          () => _ServerConfigState(_serverConfig('oh-my-media')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(taskCenterProvider.notifier);

    notifier.updateFromSchedulerMessage(const {
      'type': 'preview_task',
      'taskId': 'preview-1',
      'status': 'queued',
      'isRunning': false,
      'progress': {'total': 1, 'completed': 0, 'percent': 0},
      'movieId': 7,
      'movieTitle': '长视频',
    });
    expect(container.read(taskCenterProvider).single.name, '预览生成');
    expect(container.read(taskCenterProvider).single.canCancel, isTrue);

    notifier.updateFromSchedulerMessage(const {
      'type': 'preview_task',
      'taskId': 'preview-1',
      'taskName': '忽略客户端名称',
      'status': 'running',
      'isRunning': true,
      'progress': {'total': 1, 'completed': 0, 'percent': 42.5},
    });
    final running = container.read(taskCenterProvider).single;
    expect(running.progress.percent, 42.5);
    expect(running.movieId, 7);
    expect(running.movieTitle, '长视频');

    for (final status in ['completed', 'failed', 'cancelled']) {
      notifier.updateFromSchedulerMessage({
        'type': 'preview_task',
        'taskId': 'preview-$status',
        'status': status,
        'isRunning': false,
        'progress': {'total': 1, 'completed': 1, 'percent': 100},
        'movieId': 7,
        'movieTitle': '长视频',
      });
    }
    final tasks = container.read(taskCenterProvider);
    expect(tasks.any((task) => task.isCompleted), isTrue);
    expect(tasks.any((task) => task.isFailed), isTrue);
    expect(tasks.any((task) => task.isCanceled), isTrue);
    expect(
      tasks
          .where((task) => task.name == '预览生成')
          .every((task) => !task.canRetry),
      isTrue,
    );
  });

  test('提交响应登记和 WebSocket 更新保留影片信息', () {
    final task = const PreviewTask(
      taskId: 'preview-2',
      status: 'queued',
      movieIds: [11],
      totalCount: 1,
    );
    final item = TaskItem.fromPreviewTask(
      task,
      fallbackMovieId: 11,
      fallbackMovieTitle: '提交响应影片',
    );
    expect(item.movieId, 11);
    expect(item.movieTitle, '提交响应影片');

    final merged = item.merge(
      TaskItem.fromPreviewMessage(const {
        'type': 'preview_task',
        'taskId': 'preview-2',
        'status': 'running',
        'isRunning': true,
        'progress': {'total': 1, 'completed': 0, 'percent': 12.5},
      }),
    );
    expect(merged.movieId, 11);
    expect(merged.movieTitle, '提交响应影片');
    expect(merged.progress.percent, 12.5);
  });

  test('预览任务取消调用预览任务取消接口并更新本地状态', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = _TaskCenterMediaRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverConfigProvider.overrideWith(
          () => _ServerConfigState(_serverConfig('oh-my-media')),
        ),
        mediaRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);
    notifier.updateFromSchedulerMessage(const {
      'type': 'preview_task',
      'taskId': 'preview-cancel',
      'status': 'running',
      'isRunning': true,
      'progress': {'total': 1, 'completed': 0, 'percent': 37.5},
      'movieId': 7,
      'movieTitle': '可取消影片',
    });

    await notifier.cancel(container.read(taskCenterProvider).single);

    expect(repository.cancelledTaskId, 'preview-cancel');
    final task = container.read(taskCenterProvider).single;
    expect(task.isCanceled, isTrue);
    expect(task.isActive, isFalse);
    expect(task.canRetry, isFalse);
  });

  test('非 OMM 服务器忽略预览广播和客户端登记', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverConfigProvider.overrideWith(
          () => _ServerConfigState(_serverConfig('emby')),
        ),
      ],
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
    notifier.registerPreview(
      const PreviewTask(
        taskId: 'external-preview-2',
        status: 'queued',
        totalCount: 1,
      ),
    );

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

class _TaskCenterMediaRepository extends MediaRepository {
  _TaskCenterMediaRepository()
    : super(
        catalog: _NoopCatalogSource(),
        details: _NoopMovieDetailSource(),
        operations: _NoopOmmOperationsSource(),
      );

  String? cancelledTaskId;

  @override
  Future<void> cancelPreviewTask(String taskId) async {
    cancelledTaskId = taskId;
  }
}

class _NoopCatalogSource implements CatalogSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopMovieDetailSource implements MovieDetailSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopOmmOperationsSource implements OmmMediaOperationsSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

ServerConfig _serverConfig(String projectName) {
  const line = ServerLine(id: 'line', name: '主线路', baseUrl: '');
  final server = ServerProfile(
    id: 'server',
    name: projectName,
    lines: const [line],
    activeLineId: line.id,
    projectName: projectName,
  );
  return ServerConfig(
    baseUrl: line.baseUrl,
    lines: const [line],
    servers: [server],
    activeServerId: server.id,
  );
}
