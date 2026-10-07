import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/modal_transcription_config.dart';
import 'package:omm/features/oh_my_media/audio/audio_management_page.dart';
import 'package:omm/features/oh_my_media/audio/audio_models.dart';
import 'package:omm/features/oh_my_media/audio/audio_providers.dart';
import 'package:omm/features/oh_my_media/audio/audio_repository.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';
import 'package:omm/features/translation/modal_transcription_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tasks extends TaskCenterNotifier {
  @override
  List<TaskItem> build() => [];

  void replace(List<TaskItem> tasks) => state = tasks;
}

class _Audio extends Fake implements AudioRepository {
  final response = Completer<AudioAssetListResult>();
  int calls = 0;

  @override
  Future<AudioAssetListResult> listAssets({
    int limit = 20,
    int offset = 0,
    String? search,
  }) {
    calls++;
    return calls == 1
        ? Future.value(
            const AudioAssetListResult(
              items: [AudioAsset(id: 1, fileName: 'voice.mp3')],
              total: 1,
            ),
          )
        : response.future;
  }
}

AudioAssetListResult _transcriptionAssets(String? status) =>
    AudioAssetListResult(
      items: [
        AudioAsset(
          id: 1,
          movieId: 10,
          fileName: 'first.m4a',
          fileExists: true,
          transcription: status == null
              ? null
              : AudioTranscription(
                  taskId: 'transcription-1',
                  status: status,
                  stage: 'connecting',
                  percent: 5,
                ),
        ),
        const AudioAsset(
          id: 2,
          movieId: 10,
          fileName: 'same-movie.m4a',
          fileExists: true,
        ),
        const AudioAsset(
          id: 3,
          movieId: 20,
          fileName: 'other-movie.m4a',
          fileExists: true,
        ),
      ],
      total: 3,
    );

class _TranscriptionAudio extends Fake implements AudioRepository {
  _TranscriptionAudio(this.initialStatus, {this.returnsTask = false});

  final String? initialStatus;
  final bool returnsTask;
  final response = Completer<AudioAssetListResult>();
  final operations = <String>[];
  int calls = 0;

  @override
  Future<AudioAssetListResult> listAssets({
    int limit = 20,
    int offset = 0,
    String? search,
  }) {
    calls++;
    return calls == 1
        ? Future.value(_transcriptionAssets(initialStatus))
        : response.future;
  }

  @override
  Future<TranscriptionEnqueueResult> enqueueTranscriptions(
    List<int> assetIds, {
    bool overwrite = false,
  }) async {
    operations.add('enqueue:$assetIds:$overwrite');
    return TranscriptionEnqueueResult(
      accepted: assetIds.length,
      task: returnsTask
          ? _queuedTranscription().copyWith(audioAssetIds: assetIds)
          : null,
    );
  }

  @override
  Future<String?> cancelTranscription(String taskId) async {
    operations.add('cancel:$taskId');
    return null;
  }

  @override
  Future<String?> retryTranscription(String taskId) async {
    operations.add('retry:$taskId');
    return null;
  }
}

TaskItem _queuedTranscription() => TaskItem.fromHistory(const {
  'task_id': 'transcription-1',
  'task_type': 'subtitle_transcription',
  'task_name': '字幕转译',
  'attempt': 1,
  'revision': 1,
  'status': 'queued',
  'can_cancel': true,
  'input_json': '{"audio_asset_ids":[1],"overwrite":false}',
});

Widget _audioApp(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: Locale('zh'),
    home: AudioManagementPage(),
  ),
);

Future<ProviderContainer> _pumpTranscriptionPage(
  WidgetTester tester,
  _TranscriptionAudio repo,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      audioRepositoryProvider.overrideWithValue(repo),
      taskCenterProvider.overrideWith(_Tasks.new),
      modalTranscriptionConfigProvider.overrideWith(
        (ref) => const ModalTranscriptionConfig(enabled: true),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(_audioApp(container));
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _openAudioAction(WidgetTester tester, String label) async {
  await tester.timedDrag(
    find.byKey(const ValueKey('audio-asset-1')),
    const Offset(-110, 0),
    const Duration(milliseconds: 400),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(label).hitTestable());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('批量选择期间进入队列的音频移出选择，只提交剩余音频', (tester) async {
    final repo = _TranscriptionAudio(null);
    repo.response.complete(_transcriptionAssets(null));
    final container = await _pumpTranscriptionPage(tester, repo);
    final l = AppL10n.of(tester.element(find.byType(AudioManagementPage)));
    await tester.longPress(find.byKey(const ValueKey('audio-asset-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('audio-asset-3')));
    await tester.pump();
    expect(
      tester
          .widget<EntityBatchToolbar>(find.byType(EntityBatchToolbar))
          .selectedCount,
      2,
    );
    container.read(taskCenterProvider.notifier).restore(_queuedTranscription());
    await tester.pump();
    expect(
      tester
          .widget<EntityBatchToolbar>(find.byType(EntityBatchToolbar))
          .selectedCount,
      1,
    );
    await tester.tap(
      find.text(l.audioActionEnqueueTranscription).hitTestable(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, l.audioEnqueueConfirm));
    await tester.pump(const Duration(milliseconds: 700));
    expect(repo.operations, ['enqueue:[3]:false']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('提交成功即显示队列，刷新和重新进入保留状态，取消后解锁', (tester) async {
    final repo = _TranscriptionAudio(null, returnsTask: true);
    final container = await _pumpTranscriptionPage(tester, repo);
    final l = AppL10n.of(tester.element(find.byType(AudioManagementPage)));
    final row = find.byKey(const ValueKey('audio-asset-1'));
    final originalAction = tester.widget<SwipeActionCell>(row).actions.first;
    await _openAudioAction(tester, l.audioActionEnqueueTranscription);
    await tester.tap(find.widgetWithText(FilledButton, l.audioEnqueueConfirm));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.operations, ['enqueue:[1]:false']);
    expect(
      find.descendant(of: row, matching: find.text(l.audioStageQueued)),
      findsWidgets,
    );
    expect(tester.widget<SwipeActionCell>(row).actions.map((a) => a.label), [
      l.audioActionCancelTranscription,
    ]);

    // 即使旧操作回调尚未销毁，也不能再次打开确认并提交。
    originalAction.onPressed();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.widgetWithText(FilledButton, l.audioEnqueueConfirm),
      findsNothing,
    );
    expect(repo.operations.length, 1);
    repo.response.complete(_transcriptionAssets(null));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_audioApp(container));
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(of: row, matching: find.text(l.audioStageQueued)),
      findsWidgets,
    );

    await _openAudioAction(tester, l.audioActionCancelTranscription);
    expect(repo.operations.last, 'cancel:transcription-1');
    container
        .read(taskCenterProvider.notifier)
        .updateFromSchedulerMessage(const {
          'type': 'scheduler_status',
          'taskId': 'transcription-1',
          'taskType': 'subtitle_transcription',
          'taskName': '字幕转译',
          'attempt': 1,
          'revision': 2,
          'status': 'canceled',
        });
    await tester.pump();
    expect(
      find.descendant(of: row, matching: find.text(l.audioStatusCanceled)),
      findsOneWidget,
    );
    final sameMovie = find.byKey(const ValueKey('audio-asset-2'));
    expect(
      tester.widget<SwipeActionCell>(sameMovie).actions.map((a) => a.label),
      contains(l.audioActionEnqueueTranscription),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('确认转译时重新检查队列状态，拦截弹层打开期间的重复任务', (tester) async {
    final repo = _TranscriptionAudio(null);
    repo.response.complete(_transcriptionAssets(null));
    final container = await _pumpTranscriptionPage(tester, repo);
    final l = AppL10n.of(tester.element(find.byType(AudioManagementPage)));
    await _openAudioAction(tester, l.audioActionEnqueueTranscription);
    container.read(taskCenterProvider.notifier).restore(_queuedTranscription());
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l.audioEnqueueConfirm));
    await tester.pump(const Duration(milliseconds: 700));
    expect(repo.operations, isEmpty);
    expect(find.text(l.audioStageQueued), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('调度队列中的音频在资产投影写入前显示排队并禁止重复提交', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _TranscriptionAudio(null);
    repo.response.complete(_transcriptionAssets(null));
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        audioRepositoryProvider.overrideWithValue(repo),
        taskCenterProvider.overrideWith(_Tasks.new),
        modalTranscriptionConfigProvider.overrideWith(
          (ref) => const ModalTranscriptionConfig(enabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    final tasks = container.read(taskCenterProvider.notifier) as _Tasks;
    tasks.replace([
      TaskItem.fromHistory(const {
        'task_id': 'queued-transcription',
        'task_type': 'subtitle_transcription',
        'status': 'queued',
        'can_cancel': true,
        'input_json': '{"audio_asset_ids":[1],"overwrite":false}',
      }),
    ]);
    await tester.pumpWidget(_audioApp(container));
    await tester.pump();
    await tester.pump();
    final l = AppL10n.of(tester.element(find.byType(AudioManagementPage)));
    final row = find.byKey(const ValueKey('audio-asset-1'));
    expect(
      find.descendant(of: row, matching: find.text(l.audioStageQueued)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text(l.audioStatusNotTranscribed),
      ),
      findsNothing,
    );
    expect(
      tester.widget<SwipeActionCell>(row).actions.map((action) => action.label),
      [l.audioActionCancelTranscription],
    );
    final sameMovie = find.byKey(const ValueKey('audio-asset-2'));
    expect(tester.widget<SwipeActionCell>(sameMovie).actions, isEmpty);
    final otherMovie = find.byKey(const ValueKey('audio-asset-3'));
    expect(
      tester
          .widget<SwipeActionCell>(otherMovie)
          .actions
          .map((action) => action.label),
      contains(l.audioActionEnqueueTranscription),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final (initialStatus, taskStatus, finalStatus, operation) in [
    (null, 'running', 'running', 'enqueue:[1]:false'),
    ('running', 'canceling', 'canceled', 'cancel:transcription-1'),
    ('canceled', 'queued', 'running', 'retry:transcription-1'),
  ]) {
    testWidgets('转译操作中任务先于资产刷新时不遮挡列表：$operation', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _TranscriptionAudio(initialStatus);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          audioRepositoryProvider.overrideWithValue(repo),
          taskCenterProvider.overrideWith(_Tasks.new),
          modalTranscriptionConfigProvider.overrideWith(
            (ref) => const ModalTranscriptionConfig(enabled: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            locale: const Locale('zh'),
            home: const AudioManagementPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      final l = AppL10n.of(tester.element(find.byType(AudioManagementPage)));
      final actionLabel = initialStatus == null
          ? l.audioActionEnqueueTranscription
          : initialStatus == 'running'
          ? l.audioActionCancelTranscription
          : l.audioActionRetryTranscription;
      await tester.timedDrag(
        find.byKey(const ValueKey('audio-asset-1')),
        const Offset(-110, 0),
        const Duration(milliseconds: 400),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(actionLabel).hitTestable());
      await tester.pump();
      if (initialStatus == null) {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(
          find.widgetWithText(FilledButton, l.audioEnqueueConfirm),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.operations, [operation]);
      expect(repo.calls, 2);
      final row = find.byKey(const ValueKey('audio-asset-2'));
      final rowSize = tester.getSize(row);

      // WS 先锁定同影片资产，列表接口仍未返回转译投影，此时允许零个操作。
      (container.read(taskCenterProvider.notifier) as _Tasks).replace([
        TaskItem(
          id: 'transcription-1',
          name: 'subtitle_transcription',
          taskType: 'subtitle_transcription',
          movieId: 10,
          status: taskStatus,
          isRunning: true,
          progress: const TaskProgress(percent: 5),
          message: '',
        ),
      ]);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      // 前一行开始排队时会出现进度区，但当前行本身不应被遮挡或拉伸。
      expect(tester.getSize(row), rowSize);
      for (final id in [1, 2, 3]) {
        expect(
          find.byKey(ValueKey('audio-asset-$id')).hitTestable(),
          findsOneWidget,
        );
      }

      repo.response.complete(_transcriptionAssets(finalStatus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      // 转译状态区允许改变行高，刷新后所有资产仍须可见、可交互。
      for (final id in [1, 2, 3]) {
        expect(
          find.byKey(ValueKey('audio-asset-$id')).hitTestable(),
          findsOneWidget,
        );
      }
      if (finalStatus == 'running') {
        expect(find.text('5%'), findsOneWidget);
      } else {
        expect(find.text(l.audioTranscriptionCanceledHint), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  for (final success in [true, false]) {
    testWidgets('音频管理保留已有列表的刷新完成通知：成功=$success', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _Audio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            audioRepositoryProvider.overrideWithValue(repo),
            taskCenterProvider.overrideWith(_Tasks.new),
            modalTranscriptionConfigProvider.overrideWith(
              (ref) => throw StateError('未配置'),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            locale: Locale('zh'),
            home: AudioManagementPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final asset = find.byKey(const ValueKey('audio-asset-1'));
      expect(asset.hitTestable(), findsOneWidget);
      var done = false;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      unawaited(
        refresh.then((_) {
          done = true;
        }),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(done, isFalse);
      expect(repo.calls, 2);
      expect(asset.hitTestable(), findsOneWidget);
      if (success) {
        repo.response.complete(const AudioAssetListResult());
      } else {
        repo.response.completeError(StateError('offline'));
      }
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(asset.hitTestable(), success ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
