import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/platform/app_haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('wrapToggle 保留禁用回调语义', () {
    expect(AppHaptics.wrapToggle(null), isNull);
  });

  test('wrapToggle 只调用一次实际开关回调', () {
    var value = false;
    final onChanged = AppHaptics.wrapToggle((next) => value = next);

    onChanged!(true);

    expect(value, isTrue);
  });

  test('震动强度支持三档并可从偏好读取', () async {
    SharedPreferences.setMockInitialValues({
      AppHaptics.preferenceKey: HapticIntensity.high.storageValue,
    });
    final prefs = await SharedPreferences.getInstance();

    AppHaptics.configureFromPreferences(prefs);

    expect(HapticIntensity.values, hasLength(3));
    expect(AppHaptics.intensity, HapticIntensity.high);
    expect(HapticIntensity.fromStorage('unknown'), HapticIntensity.standard);

    AppHaptics.setIntensity(HapticIntensity.standard);
  });
}
