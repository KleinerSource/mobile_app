import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/platform/app_haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wrapToggle 保留禁用回调语义', () {
    expect(AppHaptics.wrapToggle(null), isNull);
  });

  test('wrapToggle 只调用一次实际开关回调', () {
    var value = false;
    final onChanged = AppHaptics.wrapToggle((next) => value = next);

    onChanged!(true);

    expect(value, isTrue);
  });

  test('震动强度支持关闭和三档并可从偏好读取', () async {
    SharedPreferences.setMockInitialValues({
      AppHaptics.preferenceKey: HapticIntensity.high.storageValue,
    });
    final prefs = await SharedPreferences.getInstance();

    AppHaptics.configureFromPreferences(prefs);

    expect(HapticIntensity.values, hasLength(4));
    expect(AppHaptics.intensity, HapticIntensity.high);
    expect(HapticIntensity.fromStorage('off'), HapticIntensity.off);
    expect(HapticIntensity.fromStorage('unknown'), HapticIntensity.standard);

    AppHaptics.setIntensity(HapticIntensity.standard);
  });

  test('关闭档位不会调用系统震动接口', () async {
    var hapticCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticCalls++;
      return null;
    });

    AppHaptics.setIntensity(HapticIntensity.off);
    AppHaptics.selection();
    AppHaptics.light();
    AppHaptics.medium();
    await Future<void>.delayed(Duration.zero);

    expect(hapticCalls, 0);
    AppHaptics.setIntensity(HapticIntensity.standard);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
