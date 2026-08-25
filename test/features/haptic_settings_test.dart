import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/features/settings/haptic_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('震动强度可以持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = HapticSettingsRepository(prefs);

    await repository.save(HapticIntensity.low);

    expect(repository.load(), HapticIntensity.low);
  });
}
