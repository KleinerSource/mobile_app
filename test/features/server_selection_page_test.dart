import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/features/settings/server_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('无服务器时显示加号入口并打开创建页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('连接到媒体服务器'), findsOneWidget);
  });

  testWidgets('创建服务器保存后返回选择器且保留用户选择的类型', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async => ServerLineProbeResult.success(
                line,
                8,
                versionInfo: const ServerVersionInfo(
                  projectName: 'oh-my-media',
                  version: '2.0.0',
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://media.example');
    await tester.tap(find.text('Oh-My-Media'));
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.text('选择服务器'), findsOneWidget);
    expect(prefs.getString('server.servers'), contains('oh-my-media'));
  });
}
