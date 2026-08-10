import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/privacy/shake_detector.dart';

void main() {
  test('低于阈值的移动不会触发摇一摇', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);

    final triggered = detector.handle(x: 1, y: 2, z: 10);

    expect(triggered, isFalse);
    expect(count, 0);
  });

  test('一次摇动只触发一次,冷却结束后才允许再次触发', () {
    var count = 0;
    final detector = ShakeDetector(
      onShake: () => count++,
      cooldown: const Duration(seconds: 1),
    );
    final first = DateTime.utc(2026, 8, 10, 12);

    expect(
      detector.handle(x: 18, y: 0, z: 0, now: first),
      isTrue,
    );
    expect(
      detector.handle(
        x: 0,
        y: 19,
        z: 0,
        now: first.add(const Duration(milliseconds: 400)),
      ),
      isFalse,
    );
    expect(
      detector.handle(
        x: 0,
        y: 19,
        z: 0,
        now: first.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );

    expect(count, 2);
  });

  test('reset 会清除冷却状态', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final now = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 18, y: 0, z: 0, now: now);
    detector.reset();
    detector.handle(
      x: 18,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 100)),
    );

    expect(count, 2);
  });
}
