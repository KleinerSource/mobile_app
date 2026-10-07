import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/features/settings/server_list_page.dart';
import 'package:omm/features/settings/server_setup_page.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets('设置页滚动区域延伸到系统底部安全区', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs, bottomInset: 34));
    await tester.pumpAndSettle();

    final scaffold = find.byType(Scaffold).first;
    final safeArea = find
        .descendant(of: scaffold, matching: find.byType(SafeArea))
        .first;
    expect(tester.widget<SafeArea>(safeArea).bottom, isFalse);
    expect(tester.getRect(safeArea).bottom, tester.getRect(scaffold).bottom);
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(ListView).first)).bottom,
      34,
    );
    final bottomSpacer = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 80,
    );
    expect(bottomSpacer, findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(bottomSpacer).height,
      greaterThanOrEqualTo(80),
    );
  });
}

Widget _app(SharedPreferences prefs, {double? bottomInset}) {
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
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: bottomInset == null
              ? MediaQuery.paddingOf(context)
              : MediaQuery.paddingOf(context).copyWith(bottom: bottomInset),
        ),
        child: child!,
      ),
      locale: const Locale('zh'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const SettingsPage(),
    ),
  );
}
