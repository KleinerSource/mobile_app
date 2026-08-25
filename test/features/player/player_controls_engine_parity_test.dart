import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/models/playback.dart';
import 'package:omm/features/player/playback_engine.dart';
import 'package:omm/features/player/player_controls.dart';
import 'package:omm/features/player/player_decode_status.dart';
import 'package:omm/features/player/player_session_controller.dart';

import 'fake_playback_engine.dart';

void main() {
  testWidgets('libmpv 与 KSPlayer 渲染同一套控制栏和菜单', (tester) async {
    for (final kind in PlaybackEngineKind.values) {
      final engine = FakePlaybackEngine(
        kind,
        initialState: PlaybackViewState(
          engineKind: kind,
          lifecycle: PlaybackLifecycle.ready,
          playing: true,
          position: const Duration(seconds: 20),
          duration: const Duration(minutes: 2),
          buffered: const Duration(seconds: 50),
          rate: 1.25,
        ),
      );
      final session = PlayerSessionController(engine: engine);
      double? selectedRate;
      String? selectedQuality;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.expand(
              child: PlayerControls(
                controller: session,
                previewSourceUri: 'https://example.com/video.mp4',
                quality: 'original',
                qualityOptions: const [
                  QualityOption(id: 'auto', label: '自动', kind: 'auto'),
                  QualityOption(
                    id: 'original',
                    label: '1080P（原生）',
                    kind: 'original',
                  ),
                  QualityOption(id: '720p', label: '720P', kind: 'transcode'),
                  QualityOption(id: '360p', label: '360P', kind: 'transcode'),
                ],
                onQualityChanged: (quality) => selectedQuality = quality,
                subtitleTracks: const [
                  SubtitleTrack(
                    id: 'subtitle-1',
                    index: 1,
                    source: 'external',
                    language: 'zh',
                    title: '简体中文',
                    codec: 'webvtt',
                    url: 'https://example.com/subtitle.vtt',
                    isDefault: true,
                  ),
                ],
                selectedSubtitle: null,
                onSubtitleChanged: (_) {},
                onOpenSubtitleSettings: () {},
                audioTracks: const [
                  AudioTrack(
                    index: 1,
                    codec: 'aac',
                    language: 'zh',
                    title: '中文',
                    channels: 2,
                    isDefault: true,
                  ),
                  AudioTrack(
                    index: 2,
                    codec: 'aac',
                    language: 'ja',
                    title: '日语',
                    channels: 2,
                    isDefault: false,
                  ),
                ],
                onAudioChanged: (_) {},
                decodeStatuses: [
                  PlayerDecodeStatus.local(hardware: true, clientEngine: kind),
                ],
                hapticProgressBar: false,
                showPlayPauseButton: true,
                showSeekButtons: true,
                showSpeedButton: true,
                showPipButton: true,
                showOrientationButton: true,
                showMediaSwitchButton: true,
                playbackRate: 1.25,
                onPictureInPicture: () {},
                onPreviousMedia: null,
                onNextMedia: null,
                isLandscape: true,
                onOrientationToggle: () {},
                onTogglePlay: () {},
                onSeekBackward: () {},
                onSeekForward: () {},
                onRateChanged: (value) => selectedRate = value,
                onSeek: (_) async {},
                onInteraction: () {},
                onExit: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.text('00:20'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
      expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget);
      expect(find.byIcon(Icons.high_quality_outlined), findsOneWidget);
      expect(find.text('4K'), findsNothing);
      expect(
        tester.widget<Slider>(find.byType(Slider)).secondaryTrackValue,
        kind == PlaybackEngineKind.ksPlayer ? null : 50000,
      );

      await tester.tap(find.byTooltip('选择画质'));
      await tester.pumpAndSettle();
      expect(find.text('自动'), findsOneWidget);
      expect(find.text('1080P（原生）'), findsOneWidget);
      expect(find.text('720P'), findsOneWidget);
      expect(find.text('360P'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('720P'));
      await tester.pumpAndSettle();
      expect(selectedQuality, '720p');

      engine.notifier.value = engine.notifier.value.copyWith(
        buffered: const Duration(seconds: 10),
      );
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider)).secondaryTrackValue,
        kind == PlaybackEngineKind.ksPlayer ? null : 20000,
      );

      await tester.tap(find.byIcon(Icons.speed));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.50x'));
      await tester.pumpAndSettle();
      expect(selectedRate, 1.5);

      await tester.pumpWidget(const SizedBox.shrink());
      await session.dispose();
    }
  });
}
