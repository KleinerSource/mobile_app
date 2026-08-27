import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/features/settings/server_list_page.dart';
import 'package:omm/features/settings/server_setup_page.dart';
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

  testWidgets('更换服务器时回填已保存地址', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.base_url': 'https://saved.example:8001/',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSetupPage()),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'https://saved.example:8001');
    expect(find.text('已回填上次保存的服务器地址，可直接修改后重新测试。'), findsNothing);
  });

  testWidgets('服务器列表添加探测失败时保留输入框和已填写内容', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async =>
                  ServerLineProbeResult.failure(line, '服务不可用'),
            ),
          ),
        ],
        child: const MaterialApp(home: ServerListPage()),
      ),
    );

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('添加服务器'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '测试服务器');
    await tester.enterText(fields.at(1), 'http://127.0.0.1:1');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump();

    expect(find.text('添加服务器'), findsOneWidget);
    final retainedFields = tester.widgetList<TextFormField>(fields).toList();
    expect(retainedFields[0].controller?.text, '测试服务器');
    expect(retainedFields[1].controller?.text, 'http://127.0.0.1:1');
    expect(find.textContaining('连接失败'), findsOneWidget);
  });
}
