import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/privacy/privacy_providers.dart';
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
}
