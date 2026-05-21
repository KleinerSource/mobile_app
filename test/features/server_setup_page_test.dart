import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/settings/server_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('空地址点击保存显示报错', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSetupPage()),
      ),
    );

    await tester.tap(find.text('测试并保存'));
    await tester.pump();
    expect(find.text('请输入服务器地址'), findsOneWidget);
  });

  testWidgets('无协议前缀显示报错', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSetupPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), '192.168.1.10:8001');
    await tester.tap(find.text('测试并保存'));
    await tester.pump();
    expect(find.text('地址必须以 http:// 或 https:// 开头'), findsOneWidget);
  });
}
