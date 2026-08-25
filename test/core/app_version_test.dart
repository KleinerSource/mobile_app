import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/app_version.dart';

void main() {
  test('版本号包含 pubspec 注入的构建号', () {
    expect(formatAppVersion('0.1.4', '5'), '0.1.4+5');
  });

  test('版本号已包含构建号时不会重复拼接', () {
    expect(formatAppVersion('0.1.4+5', '5'), '0.1.4+5');
  });

  test('缺少构建号时只显示版本号', () {
    expect(formatAppVersion('0.1.4', ''), '0.1.4');
  });
}
