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

  test('需要连续两个摇动峰值才触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    expect(
      detector.handle(x: 15, y: 0, z: 0, now: first),
      isFalse,
    );
    expect(
      detector.handle(
        x: 0,
        y: 10,
        z: 0,
        now: first.add(const Duration(milliseconds: 400)),
      ),
      isFalse,
    );
    expect(
      detector.handle(
        x: 0,
        y: 16,
        z: 0,
        now: first.add(const Duration(milliseconds: 600)),
      ),
      isTrue,
    );

    expect(count, 1);
  });

  test('持续高加速度但没有连续峰值不会触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 16, y: 0, z: 0, now: first);
    detector.handle(
      x: 16,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 300)),
    );
    detector.handle(
      x: 19,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 600)),
    );

    expect(count, 0);
  });

  test('超过一秒的峰值序列会重新开始计数', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 16, y: 0, z: 0, now: first);
    detector.handle(
      x: 0,
      y: 10,
      z: 0,
      now: first.add(const Duration(milliseconds: 400)),
    );
    detector.handle(
      x: 16,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 1100)),
    );

    expect(count, 0);
  });

  test('reset 会清除连续摇动序列状态', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final now = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 18, y: 0, z: 0, now: now);
    detector.reset();
    detector.handle(
      x: 15,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 100)),
    );
    detector.handle(
      x: 0,
      y: 10,
      z: 0,
      now: now.add(const Duration(milliseconds: 200)),
    );
    detector.handle(
      x: 16,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 300)),
    );
    detector.handle(
      x: 0,
      y: 10,
      z: 0,
      now: now.add(const Duration(milliseconds: 400)),
    );
    expect(count, 1);
  });
}
