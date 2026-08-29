// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/privacy_providers_test.dart
//   - test/features/privacy_shake_detector_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/features/privacy/shake_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/features/privacy_providers_test.dart ====================
void _main_0() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('隐私遮罩默认关闭并可持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(privacyShieldProvider), isFalse);

    await container.read(privacyShieldProvider.notifier).setEnabled(true);

    expect(container.read(privacyShieldProvider), isTrue);
    expect(prefs.getBool('privacy.app_switcher_shield'), isTrue);
  });

  test('摇一摇开关默认开启并可持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(privacyShakeProvider), isTrue);

    await container.read(privacyShakeProvider.notifier).setEnabled(false);

    expect(container.read(privacyShakeProvider), isFalse);
    expect(prefs.getBool('privacy.shake_to_toggle'), isFalse);
  });

  test('隐私揭示集合同时支持 OMM 整数 ID 和 DBO 字符串 ID', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(revealedMoviesProvider.notifier);
    notifier.reveal(7);
    notifier.reveal('movie-7');

    expect(container.read(revealedMoviesProvider), containsAll([7, 'movie-7']));

    notifier.hide('movie-7');
    expect(container.read(revealedMoviesProvider), contains(7));
    expect(container.read(revealedMoviesProvider), isNot(contains('movie-7')));
  });

  test('切换隐私模式会清空媒体库揭示集合', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(revealedLibrariesProvider.notifier).reveal(7);
    expect(container.read(revealedLibrariesProvider), contains(7));

    await container.read(privacyShieldProvider.notifier).setEnabled(true);

    expect(container.read(revealedLibrariesProvider), isEmpty);
  });

  testWidgets('媒体库隐私域支持遮罩和首次点击揭示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyShieldProvider.overrideWith(() => _PrivacyEnabled()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const PrivacyMask(
                  movieId: 7,
                  scope: PrivacyScope.library,
                  child: SizedBox(
                    width: 100,
                    height: 60,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
                const PrivacyText(
                  movieId: 7,
                  scope: PrivacyScope.library,
                  text: '私人媒体库',
                  style: TextStyle(),
                ),
                PrivacyAwareInkWell(
                  movieId: 7,
                  scope: PrivacyScope.library,
                  onTap: () {},
                  child: const SizedBox(width: 100, height: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.text('▆▆▆▆▆'), findsOneWidget);

    await tester.tap(find.byType(PrivacyAwareInkWell));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.text('私人媒体库'), findsOneWidget);
  });
}

class _PrivacyEnabled extends PrivacyShieldNotifier {
  @override
  bool build() => true;
}

// ==================== 原 test/features/privacy_shake_detector_test.dart ====================
void _main_1() {
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

void main() {
  group('privacy_providers', _main_0);
  group('privacy_shake_detector', _main_1);
}
