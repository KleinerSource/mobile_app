import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';
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
    final panelVisibility = <bool>[];
    const lyrics = LrcDocument(
      cues: [
        LrcCue(position: Duration.zero, text: '第一句'),
        LrcCue(position: Duration(seconds: 5), text: '第二句'),
        LrcCue(position: Duration(seconds: 10), text: '第三句'),
        LrcCue(position: Duration(seconds: 15), text: '第四句'),
        LrcCue(position: Duration(seconds: 20), text: '第五句'),
        LrcCue(position: Duration(seconds: 25), text: '第六句'),
        LrcCue(position: Duration(seconds: 30), text: '第七句'),
        LrcCue(position: Duration(seconds: 35), text: '第八句'),
      ],
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 32, bottom: 24),
        ),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: AudioLyricsView(
              controller: controller,
              lyrics: lyrics,
              spectrum: ValueNotifier(AudioSpectrumFrame.silence()),
              onPanelVisibilityChanged: panelVisibility.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('第一句'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-next')),
      findsOneWidget,
    );
    expect(find.text('第二句'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-spectrum')),
      findsOneWidget,
    );

    engine.notifier.value = engine.notifier.value.copyWith(
      position: const Duration(seconds: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-next')),
      findsOneWidget,
    );
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('第一句'), findsNothing);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);

    engine.notifier.value = engine.notifier.value.copyWith(
      position: const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('第一句'));
    await tester.pumpAndSettle();
    expect(find.text('歌词'), findsOneWidget);
    expect(panelVisibility, [true]);
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-glass-sheet')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byTooltip('关闭')).dy,
      greaterThanOrEqualTo(32),
    );
    expect(find.text('第一句'), findsNWidgets(2));
    expect(find.text('第二句'), findsNWidgets(2));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final initialScrollOffset = scrollable.position.pixels;
    engine.notifier.value = engine.notifier.value.copyWith(
      position: const Duration(seconds: 26),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(initialScrollOffset));
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('第六句')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('audio-lyrics-glass-sheet')),
      findsNothing,
    );
    expect(panelVisibility, [true, false]);

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.dispose();
  });

  testWidgets('调整进度后歌词立即使用目标时间且不被旧位置回退', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      seekDelay: const Duration(milliseconds: 40),
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
        LrcCue(position: Duration(seconds: 10), text: '第三句'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: AudioLyricsView(
            controller: controller,
            lyrics: lyrics,
            spectrum: ValueNotifier(AudioSpectrumFrame.silence()),
          ),
        ),
      ),
    );
    Future<String?> currentLyric() async {
      return tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('audio-lyrics-current')),
          )
          .data;
    }

    expect(await currentLyric(), '第一句');

    final seek = controller.seek(const Duration(seconds: 6));
    await tester.pump();
    expect(await currentLyric(), '第二句');

    engine.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    expect(await currentLyric(), '第二句');

    await tester.pump(const Duration(milliseconds: 50));
    await seek;
    // 只推进当前歌词滚动动画，避免测试等待页面中无关的全局稳定条件。
    await tester.pump(const Duration(milliseconds: 400));
    expect(await currentLyric(), '第二句');

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.dispose();
  });
}
