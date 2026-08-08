import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/platform/app_haptics.dart';

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
}
