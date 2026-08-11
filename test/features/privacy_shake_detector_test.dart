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

  test('走路时的小幅度往复移动不会触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 5, y: 0, z: 0, now: first);
    detector.handle(
      x: -5,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 250)),
    );
    detector.handle(
      x: 6,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 500)),
    );

    expect(count, 0);
  });

  test('纵向和前后方向的剧烈移动不会触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 0, y: 20, z: 0, now: first);
    detector.handle(
      x: 0,
      y: -22,
      z: 0,
      now: first.add(const Duration(milliseconds: 250)),
    );
    detector.handle(
      x: 0,
      y: 0,
      z: 24,
      now: first.add(const Duration(milliseconds: 500)),
    );
    detector.handle(
      x: 0,
      y: 0,
      z: -26,
      now: first.add(const Duration(milliseconds: 750)),
    );

    expect(count, 0);
  });

  test('需要一秒内连续三个反向摇动峰值才触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    expect(detector.handle(x: 10, y: 0, z: 0, now: first), isFalse);
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 150)),
    );
    expect(
      detector.handle(
        x: -11,
        y: 0,
        z: 0,
        now: first.add(const Duration(milliseconds: 300)),
      ),
      isFalse,
    );
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 450)),
    );
    expect(
      detector.handle(
        x: 12,
        y: 0,
        z: 0,
        now: first.add(const Duration(milliseconds: 600)),
      ),
      isTrue,
    );

    expect(count, 1);
  });

  test('连续反向峰值不需要采到释放阈值也能触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 10, y: 0, z: 0, now: first);
    detector.handle(
      x: -11,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 250)),
    );
    expect(
      detector.handle(
        x: 12,
        y: 0,
        z: 0,
        now: first.add(const Duration(milliseconds: 500)),
      ),
      isTrue,
    );

    expect(count, 1);
  });

  test('峰值方向没有反转时不会触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 10, y: 0, z: 0, now: first);
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 100)),
    );
    detector.handle(
      x: 11,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 200)),
    );
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 300)),
    );
    detector.handle(
      x: 12,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 400)),
    );

    expect(count, 0);
  });

  test('持续高加速度但没有连续峰值不会触发', () {
    var count = 0;
    final detector = ShakeDetector(onShake: () => count++);
    final first = DateTime.utc(2026, 8, 10, 12);

    detector.handle(x: 10, y: 0, z: 0, now: first);
    detector.handle(
      x: 11,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 300)),
    );
    detector.handle(
      x: 12,
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

    detector.handle(x: 10, y: 0, z: 0, now: first);
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: first.add(const Duration(milliseconds: 400)),
    );
    detector.handle(
      x: -11,
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

    detector.handle(x: 10, y: 0, z: 0, now: now);
    detector.reset();
    detector.handle(
      x: 10,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 100)),
    );
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 200)),
    );
    detector.handle(
      x: -11,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 300)),
    );
    detector.handle(
      x: 0,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 400)),
    );
    detector.handle(
      x: 12,
      y: 0,
      z: 0,
      now: now.add(const Duration(milliseconds: 500)),
    );
    expect(count, 1);
  });
}
