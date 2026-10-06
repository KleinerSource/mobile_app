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
  _TranscriptionAudio(this.initialStatus);

  final String? initialStatus;
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
    return const TranscriptionEnqueueResult(accepted: 1);
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

void main() {
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
      final rowRect = tester.getRect(row);

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
      expect(tester.getRect(row), rowRect);
      for (final file in ['first.m4a', 'same-movie.m4a', 'other-movie.m4a']) {
        expect(find.text(file).hitTestable(), findsOneWidget);
      }

      repo.response.complete(_transcriptionAssets(finalStatus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.getRect(row), rowRect);
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
      expect(find.text('voice.mp3'), findsOneWidget);
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
      expect(find.text('voice.mp3'), findsOneWidget);
      if (success) {
        repo.response.complete(const AudioAssetListResult());
      } else {
        repo.response.completeError(StateError('offline'));
      }
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(find.text('voice.mp3'), success ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
