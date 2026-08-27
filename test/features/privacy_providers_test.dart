import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
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
}
