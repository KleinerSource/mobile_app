import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/models/playback.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/video/video_player_controls.dart';
import 'package:omm/features/player/common/player_session_controller.dart';

import '../common/fake_playback_engine.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// 进度条触觉反馈节奏：
/// - 按下确认一次，松手不震；
/// - 首次 onChanged 是“跳到按下点”，点按跳转与拖动起点无法区分，
///   不计入 5 秒跨档刻度；
/// - 真实拖动每跨一档 tick 一次。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> hapticEffects;

  setUp(() {
    AppHaptics.setIntensity(HapticIntensity.standard);
    hapticEffects = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticEffects.add(call.arguments as String? ?? '');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  PlayerSessionController buildSession() {
    final engine = FakePlaybackEngine(
      PlaybackEngineKind.libmpv,
      initialState: const PlaybackViewState(
        engineKind: PlaybackEngineKind.libmpv,
        lifecycle: PlaybackLifecycle.ready,
        playing: true,
        position: Duration(seconds: 20),
        duration: Duration(minutes: 2),
        buffered: Duration(seconds: 50),
        rate: 1,
      ),
    );
    return PlayerSessionController(engine: engine);
  }

  /// 拖动会触发帧预览的 250ms 节流等待，收尾时推过窗口避免遗留定时器。
  Future<void> flushPreviewThrottle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> pumpControls(
    WidgetTester tester,
    PlayerSessionController session,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: VideoPlayerControls(
              controller: session,
              quality: 'original',
              qualityOptions: const [
                QualityOption(id: 'auto', label: '自动', kind: 'auto'),
              ],
              onQualityChanged: (_) {},
              subtitleTracks: const [],
              selectedSubtitle: null,
              onSubtitleChanged: (_) {},
              onOpenSubtitleSettings: () {},
              audioTracks: const [],
              onAudioChanged: (_) {},
              decodeStatuses: const [],
              hapticProgressBar: true,
              showPlayPauseButton: true,
              showSeekButtons: true,
              showSpeedButton: true,
              showPipButton: true,
              showOrientationButton: true,
              showMediaSwitchButton: true,
              playbackRate: 1,
              onPictureInPicture: () {},
              onPreviousMedia: null,
              onNextMedia: null,
              isLandscape: true,
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
        ),
      ),
    );
  }

  testWidgets('点按进度条跳转只有按下一次反馈', (tester) async {
    final session = buildSession();
    await pumpControls(tester, session);
    await tester.pump();

    // 点按滑道中部：从 20 秒跳到约 60 秒，跳变不计入跨档刻度，
    // 只有按下确认一次，松手不再震动。
    final rect = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(rect.left + rect.width * 0.5, rect.center.dy));
    await tester.pump();

    expect(hapticEffects, ['HapticFeedbackType.lightImpact']);
    await flushPreviewThrottle(tester);
  });

  testWidgets('拖动进度条按下确认一次、按跨档刻度反馈、松手不震', (tester) async {
    final session = buildSession();
    await pumpControls(tester, session);
    await tester.pump();

    double sliderValue() => tester.widget<Slider>(find.byType(Slider)).value;

    final rect = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * 0.25, rect.center.dy),
    );
    // 首次 onChanged 是定位到按下点：只有按下确认一次，跳变不计刻度。
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(hapticEffects, ['HapticFeedbackType.lightImpact']);

    // 小步连续拖动，按实际跨过的 5 秒档位数核对刻度反馈次数。
    var expectedTicks = 0;
    var lastBucket = (sliderValue() / 5000).floor();
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();
      final bucket = (sliderValue() / 5000).floor();
      expectedTicks += bucket - lastBucket;
      lastBucket = bucket;
    }
    await gesture.up();
    await tester.pump();

    // 按下确认 + 跨档刻度，松手不再追加震动。
    expect(
      hapticEffects
          .where((type) => type == 'HapticFeedbackType.lightImpact')
          .length,
      1 + expectedTicks,
    );
    expect(expectedTicks, greaterThan(0));
    expect(hapticEffects.last, 'HapticFeedbackType.lightImpact');
    await flushPreviewThrottle(tester);
  });
}
