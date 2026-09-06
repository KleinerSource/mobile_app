import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
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

void main() {
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
