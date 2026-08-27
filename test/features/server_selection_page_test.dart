import 'dart:convert';

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
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.text('选择服务器'), findsOneWidget);
    expect(prefs.getString('server.servers'), contains('oh-my-media'));
  });

  testWidgets('初始化页连续添加两台服务器时保留第一台', (tester) async {
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

    Future<void> addServer(String url) async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), url);
      await tester.tap(find.text('测试并保存'));
      await tester.pumpAndSettle();
    }

    await addServer('https://first.example');
    expect(find.text('选择服务器'), findsOneWidget);
    expect(
      (jsonDecode(prefs.getString('server.servers')!) as List),
      hasLength(1),
    );

    await addServer('https://second.example');

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored, hasLength(2));
    expect(stored[0]['lines'][0]['base_url'], 'https://first.example');
    expect(stored[1]['lines'][0]['base_url'], 'https://second.example');
  });

  testWidgets('已有服务器列表末尾的加号打开新建页并保留已有服务器', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': 'DB Online',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://db.example',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'saved',
    });
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

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('连接到媒体服务器'), findsOneWidget);
    expect(find.text('Oh-My-Media'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'http://',
    );

    await tester.enterText(find.byType(TextField), 'https://media.example');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    final stored = jsonDecode(prefs.getString('server.servers')!) as List;
    expect(stored, hasLength(2));
    expect(stored.first['id'], 'saved');
    expect(stored.last['project_name'], 'oh-my-media');
  });

  testWidgets('长按服务器头像显示编辑和删除操作', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': 'DB Online',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://db.example',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'db_online',
        },
      ]),
      'server.active_server_id': 'saved',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerSelectionPage()),
      ),
    );

    await tester.longPress(find.text('DB Online'));
    await tester.pumpAndSettle();

    expect(find.text('编辑服务器'), findsOneWidget);
    expect(find.text('删除服务器'), findsOneWidget);
    expect(find.text('编辑服务器地址'), findsNothing);

    await tester.tap(find.text('编辑服务器'));
    await tester.pumpAndSettle();
    expect(find.text('更换服务器'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'https://db.example',
    );
  });
}
