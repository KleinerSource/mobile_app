import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
