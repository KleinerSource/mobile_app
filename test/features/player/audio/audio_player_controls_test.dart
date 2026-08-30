import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/audio/audio_player_controls.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';

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
}
