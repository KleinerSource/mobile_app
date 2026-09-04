import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/features/settings/server_list_page.dart';
import 'package:omm/features/settings/server_setup_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/features/settings/server_settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('设置首页将服务器列表、服务器设置和应用设置并列展示', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    final group = tester
        .widgetList<SettingsGroup>(find.byType(SettingsGroup))
        .first;
    final titles = group.items
        .whereType<SettingsTile>()
        .map((tile) => tile.title)
        .toList();

    expect(titles, ['服务器列表', '服务器设置', '应用设置']);
    expect(find.text('未配置'), findsOneWidget);
  });

  testWidgets('未配置服务器时，首页服务器列表入口打开服务器设置页', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务器列表'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSetupPage), findsOneWidget);
  });

  testWidgets('已配置服务器时，首页服务器列表入口打开服务器列表页', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'omm',
          'name': 'OMM',
          'lines': [
            {
              'id': 'omm-line',
              'name': '主线路',
              'base_url': 'https://omm.example',
            },
          ],
          'active_line_id': 'omm-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'omm',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务器列表'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerListPage), findsOneWidget);
  });

  testWidgets('Stash 不显示未实现的服务器设置入口', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'stash',
          'name': 'Stash',
          'lines': [
            {
              'id': 'stash-line',
              'name': '主线路',
              'base_url': 'http://stash.example:9999',
            },
          ],
          'active_line_id': 'stash-line',
          'project_name': 'stash',
        },
      ]),
      'server.active_server_id': 'stash',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    final group = tester
        .widgetList<SettingsGroup>(find.byType(SettingsGroup))
        .first;
    final titles = group.items
        .whereType<SettingsTile>()
        .map((tile) => tile.title)
        .toList();
    expect(titles, ['服务器列表', '应用设置']);
    expect(find.text('服务器设置'), findsNothing);
  });

  testWidgets('只有 OMM 显示预览生成设置入口', (tester) async {
    for (final project in [
      'oh-my-media',
      'emby',
      'jellyfin',
      'feiniu',
      'stash',
    ]) {
      await tester.pumpWidget(_serverSettingsApp(project));
      await tester.pumpAndSettle();

      if (project == 'oh-my-media') {
        expect(find.text('预览生成'), findsOneWidget, reason: project);
      } else {
        expect(find.text('预览生成'), findsNothing, reason: project);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

Widget _serverSettingsApp(String projectName) {
  const line = ServerLine(
    id: 'line',
    name: '主线路',
    baseUrl: 'https://example.test',
  );
  final server = ServerProfile(
    id: 'server',
    name: projectName,
    lines: const [line],
    activeLineId: line.id,
    projectName: projectName,
  );
  final config = ServerConfig(
    baseUrl: line.baseUrl,
    lines: const [line],
    servers: [server],
    activeServerId: server.id,
  );
  return ProviderScope(
    overrides: [
      serverConfigProvider.overrideWith(() => _ServerConfigState(config)),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: ServerSettingsPage(),
    ),
  );
}

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

Widget _app(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      appPackageInfoProvider.overrideWith(
        (_) async => PackageInfo(
          appName: 'Oh My Media',
          packageName: 'com.ohmymedia.omm',
          version: '0.0.0',
          buildNumber: '0',
        ),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: SettingsPage(),
    ),
  );
}
