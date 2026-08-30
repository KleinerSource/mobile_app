import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/features/settings/server_list_page.dart';
import 'package:omm/features/settings/server_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('服务器名称为空时显示报错', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    await tester.tap(find.text('测试并保存'));
    await tester.pump();

    expect(find.text('请输入服务器名称'), findsOneWidget);
  });

  testWidgets('创建服务器默认选择 Oh My Media 并显示 HTTP 字段', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    expect(find.text('Oh My Media'), findsOneWidget);
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsNothing);
    expect(find.text('用户名'), findsNothing);
    expect(find.text('密码'), findsNothing);
  });

  testWidgets('切换服务器类型显示对应字段', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);

    await _selectProject(tester, 'SMB');
    expect(find.text('协议'), findsNothing);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(2)
          .decoration
          ?.hintText,
      '445',
    );

    await _selectProject(tester, 'WebDAV');
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(2)
          .decoration
          ?.hintText,
      '80',
    );

    await _selectProject(tester, 'OpenList');
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('根路径'), findsOneWidget);
    expect(find.text('用户名（留空匿名访问）'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(2)
          .decoration
          ?.hintText,
      '5244',
    );
    // 根路径自动预填 /，dav 前缀内置在端点里，用户无需输入。
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .elementAt(3)
          .controller
          ?.text,
      '/',
    );
  });

  testWidgets('DB Online 显示 HTTP 字段而不显示文件服务器字段', (tester) async {
    final prefs = await _prefs();
    await _pumpSetup(tester, prefs);
    await _selectProject(tester, 'DB Online');

    expect(find.text('协议'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('路径'), findsNothing);
    expect(find.text('用户名'), findsNothing);
    expect(find.text('密码'), findsNothing);
  });

  testWidgets('编辑服务器时拆分回填名称、协议、主机和端口', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': '已保存服务器',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://saved.example:8001/',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'saved',
    });
    final prefs = await SharedPreferences.getInstance();

    await _pumpSetup(tester, prefs, editing: true);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller?.text, '已保存服务器');
    expect(fields[1].controller?.text, 'saved.example');
    expect(fields[2].controller?.text, '8001');
    expect(find.text('HTTPS'), findsOneWidget);
    expect(find.text('已回填上次保存的服务器地址，可直接修改后重新测试。'), findsNothing);
  });

  testWidgets('编辑服务器时拒绝改成其他服务器的重复连接', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'first',
          'name': '第一台服务器',
          'lines': [
            {
              'id': 'first-line',
              'name': '主线路',
              'base_url': 'http://first.example:8001',
            },
          ],
          'active_line_id': 'first-line',
          'project_name': 'oh-my-media',
        },
        {
          'id': 'second',
          'name': '第二台服务器',
          'lines': [
            {
              'id': 'second-line',
              'name': '主线路',
              'base_url': 'http://second.example:8001',
            },
          ],
          'active_line_id': 'second-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'first',
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
        child: const MaterialApp(
          home: ServerSetupPage(editing: true, serverId: 'first'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'second.example');
    await tester.tap(find.text('测试并保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已存在相同连接'), findsOneWidget);
    expect(find.text('更换服务器'), findsOneWidget);
  });

  testWidgets('服务器列表添加入口打开统一服务器页面', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ServerListPage()),
      ),
    );

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('添加服务器'), findsOneWidget);
    expect(find.byType(ServerSetupPage), findsOneWidget);
    expect(find.byType(DropdownButton<ServerProject>), findsOneWidget);
  });
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<void> _pumpSetup(
  WidgetTester tester,
  SharedPreferences prefs, {
  bool editing = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: ServerSetupPage(editing: editing)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectProject(WidgetTester tester, String project) async {
  await tester.tap(find.byType(DropdownButton<ServerProject>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(project).last);
  await tester.pumpAndSettle();
}
