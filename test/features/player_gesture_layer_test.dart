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
}
