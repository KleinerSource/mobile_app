import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import 'package:omm/features/player/audio/audio_player_controls.dart';
import 'package:omm/features/player/audio/audio_now_playing_view.dart';
import 'package:omm/features/player/audio/lrc_parser.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

import '../common/fake_playback_engine.dart';

void main() {
  testWidgets('音频控制栏显示常规控制并转发操作', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        position: Duration(seconds: 20),
        duration: Duration(minutes: 2),
        buffered: Duration(seconds: 50),
        rate: 1.25,
        currentTitle: '正在播放.mp3',
        queueIndex: 1,
      ),
    );
    final session = PlayerSessionController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: AudioPlayerControls(
              controller: session,
              hapticProgressBar: false,
              showPlayPauseButton: true,
              showSeekButtons: true,
              showSpeedButton: true,
              showMediaSwitchButton: true,
              showShuffleButton: true,
              shuffleEnabled: false,
              shuffleOnTooltip: '开启随机播放',
              shuffleOffTooltip: '关闭随机播放',
              onShuffleToggle: () => unawaited(
                session.setShuffleMode(!session.value.shuffleEnabled),
              ),
              showRepeatButton: true,
              repeatMode: PlaybackRepeatMode.off,
              repeatOffTooltip: '循环：关闭',
              repeatOneTooltip: '循环：单曲',
              repeatAllTooltip: '循环：全部',
              onRepeatToggle: () =>
                  unawaited(session.setRepeatMode(PlaybackRepeatMode.one)),
              playbackRate: 1.25,
              onPreviousMedia: () => unawaited(session.skipToPrevious()),
              onNextMedia: () => unawaited(session.skipToNext()),
              onTogglePlay: () => unawaited(session.playOrPause()),
              onSeekBackward: () => unawaited(
                session.seek(session.position - const Duration(seconds: 10)),
              ),
              onSeekForward: () => unawaited(
                session.seek(session.position + const Duration(seconds: 10)),
              ),
              onRateChanged: (rate) => unawaited(session.setRate(rate)),
              onSeek: session.seek,
              onInteraction: () {},
              onExit: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.shuffle), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.forward_10), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.text('正在播放.mp3'), findsOneWidget);
    expect(find.byIcon(Icons.phone_android), findsNothing);
    expect(find.byIcon(Icons.high_quality_outlined), findsNothing);
    expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
    expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
    expect(
      tester.widget<Slider>(find.byType(Slider)).secondaryTrackValue,
      isNull,
    );

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(engine.commands, contains('pause'));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byTooltip('开启随机播放'));
    await tester.tap(find.byTooltip('循环：关闭'));
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.replay_10));
    await tester.tap(find.byIcon(Icons.forward_10));
    await tester.pump();

    expect(engine.commands, contains('shuffle:true'));
    expect(engine.commands, contains('repeat:one'));
    expect(engine.commands, contains('previous'));
    expect(engine.commands, contains('next'));
    expect(engine.commands, contains('seek'));

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('音频加载时只将播放按钮显示为加载状态', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.opening,
      ),
    );
    final session = PlayerSessionController(engine: engine);
    var toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: AudioPlayerControls(
            controller: session,
            hapticProgressBar: false,
            showPlayPauseButton: true,
            isLoading: true,
            showSeekButtons: false,
            showSpeedButton: false,
            showMediaSwitchButton: false,
            showShuffleButton: false,
            shuffleEnabled: false,
            shuffleOnTooltip: '开启随机播放',
            shuffleOffTooltip: '关闭随机播放',
            onShuffleToggle: null,
            showRepeatButton: false,
            repeatMode: PlaybackRepeatMode.off,
            repeatOffTooltip: '循环：关闭',
            repeatOneTooltip: '循环：单曲',
            repeatAllTooltip: '循环：全部',
            onRepeatToggle: null,
            playbackRate: 1,
            onPreviousMedia: null,
            onNextMedia: null,
            onTogglePlay: () => toggled = true,
            onSeekBackward: () {},
            onSeekForward: () {},
            onRateChanged: (_) {},
            onSeek: session.seek,
            onInteraction: () {},
            onExit: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);

    final spinnerButton = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(IconButton),
    );
    await tester.tap(spinnerButton);
    expect(toggled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('底部控制行在状态和歌词内容变化时保持底部锚定', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        duration: Duration(minutes: 2),
        currentTitle: '短标题',
      ),
    );
    final session = PlayerSessionController(engine: engine);

    await tester.pumpWidget(_controlsApp(session));
    final withoutLyrics = tester.getBottomRight(find.byIcon(Icons.repeat)).dy;

    engine.notifier.value = engine.notifier.value.copyWith(
      currentTitle: '一个很长很长的音频标题，用来确认标题换行不会推动底部控制行的位置变化和底部锚点',
      lifecycle: PlaybackLifecycle.opening,
    );
    await tester.pumpWidget(_controlsApp(session));
    final loadingWithLongTitle = tester
        .getBottomRight(find.byIcon(Icons.repeat))
        .dy;

    await tester.pumpWidget(_controlsApp(session, withLyrics: true));
    final withLyrics = tester.getBottomRight(find.byIcon(Icons.repeat)).dy;

    expect(loadingWithLongTitle, closeTo(withoutLyrics, 0.001));
    expect(withLyrics, closeTo(withoutLyrics, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('状态切换不会移动唱片和各控制槽位', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        duration: Duration(minutes: 2),
        currentTitle: '短标题',
      ),
    );
    final session = PlayerSessionController(engine: engine);

    await tester.pumpWidget(_controlsApp(session));
    final record = find.byKey(const ValueKey<String>('audio-vinyl-record'));
    final repeat = find.byIcon(Icons.repeat);
    final play = find.byIcon(Icons.play_arrow);
    final recordCenter = tester.getCenter(record);
    final repeatCenter = tester.getCenter(repeat);
    final playCenter = tester.getCenter(play);

    engine.notifier.value = engine.notifier.value.copyWith(
      currentTitle: '一个很长很长的音频标题，用来确认标题换行不会推动播放器位置',
      lifecycle: PlaybackLifecycle.opening,
      playing: true,
    );
    await tester.pumpWidget(_controlsApp(session));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.getCenter(record), recordCenter);
    expect(tester.getCenter(repeat), repeatCenter);
    expect(
      tester.getCenter(find.byType(CircularProgressIndicator)),
      playCenter,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets('播放暂停和加载状态共享同一按钮中心且不会滑动', (tester) async {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.audio,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.audio,
        lifecycle: PlaybackLifecycle.ready,
        playing: false,
        duration: Duration(minutes: 2),
      ),
    );
    final session = PlayerSessionController(engine: engine);

    await tester.pumpWidget(_controlsApp(session));
    final button = find.byKey(
      const ValueKey<String>('audio-play-pause-button'),
    );
    final buttonCenter = tester.getCenter(button);
    final playCenter = tester.getCenter(find.byIcon(Icons.play_arrow));

    engine.notifier.value = engine.notifier.value.copyWith(playing: true);
    await tester.pump(const Duration(milliseconds: 90));
    final pauseCenter = tester.getCenter(find.byIcon(Icons.pause));
    expect(pauseCenter, buttonCenter);
    expect(pauseCenter, playCenter);

    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getCenter(find.byIcon(Icons.pause)), buttonCenter);

    engine.notifier.value = engine.notifier.value.copyWith(
      lifecycle: PlaybackLifecycle.opening,
      playing: false,
    );
    await tester.pumpWidget(_controlsApp(session));
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.getCenter(find.byType(CircularProgressIndicator)),
      buttonCenter,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });
}

Widget _controlsApp(
  PlayerSessionController session, {
  bool withLyrics = false,
}) {
  const lyrics = LrcDocument(
    cues: [LrcCue(position: Duration.zero, text: '当前歌词')],
  );
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: AudioNowPlayingView(
                controller: session,
                artworkPath: null,
                lyrics: withLyrics ? lyrics : null,
                spectrum: ValueNotifier(AudioSpectrumFrame.silence()),
              ),
            ),
            Positioned.fill(child: _testControls(session)),
          ],
        ),
      ),
    ),
  );
}

AudioPlayerControls _testControls(PlayerSessionController session) {
  return AudioPlayerControls(
    controller: session,
    hapticProgressBar: false,
    showPlayPauseButton: true,
    isLoading: session.value.lifecycle == PlaybackLifecycle.opening,
    showSeekButtons: true,
    showSpeedButton: true,
    showMediaSwitchButton: true,
    showShuffleButton: true,
    shuffleEnabled: false,
    shuffleOnTooltip: '开启随机播放',
    shuffleOffTooltip: '关闭随机播放',
    onShuffleToggle: () {},
    showRepeatButton: true,
    repeatMode: PlaybackRepeatMode.off,
    repeatOffTooltip: '循环：关闭',
    repeatOneTooltip: '循环：单曲',
    repeatAllTooltip: '循环：全部',
    onRepeatToggle: () {},
    playbackRate: 1,
    onPreviousMedia: () {},
    onNextMedia: () {},
    onTogglePlay: () {},
    onSeekBackward: () {},
    onSeekForward: () {},
    onRateChanged: (_) {},
    onSeek: session.seek,
    onInteraction: () {},
    onExit: () {},
  );
}
