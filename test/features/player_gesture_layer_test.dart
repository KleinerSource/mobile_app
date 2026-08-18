import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/features/player/player_gesture_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> hapticCalls;

  setUp(() {
    hapticCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        hapticCalls.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('单击播放器切换控件显隐不触发震动', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: PlayerGestureLayer(
              positionGetter: () => Duration.zero,
              durationGetter: () => const Duration(minutes: 2),
              onTap: () => tapCount++,
              doubleTapCenterEnabled: true,
              doubleTapEdgesEnabled: true,
              onDoubleTapCenter: () {},
              onDoubleTapSeek: (_) {},
              hapticLongPress: true,
              hapticSeek: true,
              hapticRate: true,
              onRateBoost: (_) {},
              onRateBoostEnd: () {},
              onSeekPreview: (_, __) {},
              onSeekCommit: (_) {},
              onBrightnessDelta: (_) {},
              onVolumeDelta: (_) {},
              onAxisDragEnd: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PlayerGestureLayer));
    await tester.pump(const Duration(seconds: 1));

    expect(tapCount, 1);
    expect(hapticCalls, isEmpty);
  });

  testWidgets('左右两侧垂直滑动分别调节亮度和音量', (tester) async {
    var brightnessDelta = 0.0;
    var volumeDelta = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: PlayerGestureLayer(
              positionGetter: () => Duration.zero,
              durationGetter: () => const Duration(minutes: 2),
              onTap: () {},
              doubleTapCenterEnabled: false,
              doubleTapEdgesEnabled: false,
              onDoubleTapCenter: () {},
              onDoubleTapSeek: (_) {},
              hapticLongPress: false,
              hapticSeek: false,
              hapticRate: false,
              onRateBoost: (_) {},
              onRateBoostEnd: () {},
              onSeekPreview: (_, __) {},
              onSeekCommit: (_) {},
              onBrightnessDelta: (delta) => brightnessDelta += delta,
              onVolumeDelta: (delta) => volumeDelta += delta,
              onAxisDragEnd: () {},
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(PlayerGestureLayer));
    await tester.dragFrom(
      rect.center + Offset(-rect.width / 4, 0),
      const Offset(0, -48),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.dragFrom(
      rect.center + Offset(rect.width / 4, 0),
      const Offset(0, 48),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(brightnessDelta, greaterThan(0));
    expect(volumeDelta, lessThan(0));
    expect(brightnessDelta.abs(), closeTo(volumeDelta.abs(), 0.01));
  });

  testWidgets('横向 seek 实时预览并在媒体边界钳制后提交', (tester) async {
    final previews = <Duration>[];
    final commits = <Duration>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: PlayerGestureLayer(
              positionGetter: () => const Duration(seconds: 110),
              durationGetter: () => const Duration(seconds: 120),
              onTap: () {},
              doubleTapCenterEnabled: false,
              doubleTapEdgesEnabled: false,
              onDoubleTapCenter: () {},
              onDoubleTapSeek: (_) {},
              hapticLongPress: false,
              hapticSeek: false,
              hapticRate: false,
              onRateBoost: (_) {},
              onRateBoostEnd: () {},
              onSeekPreview: (target, _) => previews.add(target),
              onSeekCommit: commits.add,
              onBrightnessDelta: (_) {},
              onVolumeDelta: (_) {},
              onAxisDragEnd: () {},
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(PlayerGestureLayer));
    await tester.dragFrom(rect.center, const Offset(160, 0));
    await tester.pump(const Duration(milliseconds: 100));

    expect(previews, isNotEmpty);
    expect(previews.last, const Duration(seconds: 120));
    expect(commits, [const Duration(seconds: 120)]);
  });

  testWidgets('长按开始 2x 加速，结束恢复回调生命周期', (tester) async {
    final rates = <double>[];
    var ended = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: PlayerGestureLayer(
              positionGetter: () => Duration.zero,
              durationGetter: () => const Duration(minutes: 2),
              onTap: () {},
              doubleTapCenterEnabled: false,
              doubleTapEdgesEnabled: false,
              onDoubleTapCenter: () {},
              onDoubleTapSeek: (_) {},
              hapticLongPress: false,
              hapticSeek: false,
              hapticRate: false,
              onRateBoost: rates.add,
              onRateBoostEnd: () => ended++,
              onSeekPreview: (_, __) {},
              onSeekCommit: (_) {},
              onBrightnessDelta: (_) {},
              onVolumeDelta: (_) {},
              onAxisDragEnd: () {},
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(PlayerGestureLayer));

    expect(rates, [2.0]);
    expect(ended, 1);
  });
}
