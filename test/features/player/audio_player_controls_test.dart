import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/playback_engine.dart';
import 'package:omm/features/player/player_controls.dart';
import 'package:omm/features/player/player_decode_status.dart';
import 'package:omm/features/player/player_session_controller.dart';

import 'fake_playback_engine.dart';

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
            child: PlayerControls(
              controller: session,
              quality: 'auto',
              qualityOptions: const [],
              showQualityButton: false,
              onQualityChanged: (_) {},
              subtitleTracks: const [],
              selectedSubtitle: null,
              onSubtitleChanged: (_) {},
              onOpenSubtitleSettings: () {},
              audioTracks: const [],
              onAudioChanged: (_) {},
              decodeStatuses: const <PlayerDecodeStatus>[],
              hapticProgressBar: false,
              showPlayPauseButton: true,
              showSeekButtons: true,
              showSpeedButton: true,
              showPipButton: false,
              showOrientationButton: false,
              showMediaSwitchButton: true,
              showShuffleButton: true,
              shuffleEnabled: false,
              onShuffleToggle: () => unawaited(
                session.setShuffleMode(!session.value.shuffleEnabled),
              ),
              showRepeatButton: true,
              repeatMode: PlaybackRepeatMode.off,
              onRepeatToggle: () =>
                  unawaited(session.setRepeatMode(PlaybackRepeatMode.one)),
              playbackRate: 1.25,
              onPictureInPicture: () {},
              onPreviousMedia: () => unawaited(session.skipToPrevious()),
              onNextMedia: () => unawaited(session.skipToNext()),
              isLandscape: true,
              onOrientationToggle: () {},
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
}
