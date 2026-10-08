import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_session_controller.dart';
import 'package:omm/features/player/video/video_player_controls.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

import '../common/fake_playback_engine.dart';

void main() {
  testWidgets('video fills the bottom safe area while controls avoid it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlayerSessionController(
      engine: FakePlaybackEngine(PlaybackEngineKind.ksPlayer),
    );
    const surfaceKey = ValueKey<String>('video-surface');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(bottom: 32),
            viewPadding: EdgeInsets.only(bottom: 32),
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              top: true,
              bottom: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned.fill(
                    child: ColoredBox(key: surfaceKey, color: Colors.blue),
                  ),
                  Positioned.fill(
                    child: VideoPlayerControls(
                      controller: controller,
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
                      decodeStatuses: const [],
                      hapticProgressBar: false,
                      showPlayPauseButton: true,
                      showSeekButtons: false,
                      showSpeedButton: false,
                      showPipButton: false,
                      showOrientationButton: false,
                      showMediaSwitchButton: false,
                      playbackRate: 1,
                      onPictureInPicture: () {},
                      onPreviousMedia: null,
                      onNextMedia: null,
                      isLandscape: false,
                      onOrientationToggle: () {},
                      onTogglePlay: () {},
                      onSeekBackward: () {},
                      onSeekForward: () {},
                      onRateChanged: (_) {},
                      onSeek: (_) async {},
                      onInteraction: () {},
                      onExit: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final playButton = find.ancestor(
      of: find.byIcon(Icons.play_arrow),
      matching: find.byType(IconButton),
    );
    expect(tester.getRect(find.byKey(surfaceKey)).bottom, 800);
    expect(tester.getRect(playButton).bottom, lessThanOrEqualTo(768));

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.dispose();
  });
}
