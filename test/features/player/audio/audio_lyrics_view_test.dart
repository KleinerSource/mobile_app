import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/audio/audio_lyrics_view.dart';
import 'package:omm/features/player/audio/lrc_parser.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

import '../common/fake_playback_engine.dart';

void main() {
  testWidgets('歌词按播放位置高亮，点击后展开歌词面板', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        position: Duration(seconds: 2),
        duration: Duration(minutes: 3),
      ),
    );
    final controller = PlayerSessionController(engine: engine);
    const lyrics = LrcDocument(
      cues: [
        LrcCue(position: Duration.zero, text: '第一句'),
        LrcCue(position: Duration(seconds: 5), text: '第二句'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: AudioLyricsView(controller: controller, lyrics: lyrics),
        ),
      ),
    );

    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsNothing);
    await tester.tap(find.text('第一句'));
    await tester.pumpAndSettle();
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('第一句'), findsNWidgets(2));
    expect(find.text('第二句'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.dispose();
  });
}
