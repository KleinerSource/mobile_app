import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/features/settings/server_lines_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('添加线路检测失败时保留弹窗和已填写内容', (tester) async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'server-1',
          'name': '媒体服务器',
          'lines': [
            {
              'id': 'line-1',
              'name': '主线路',
              'base_url': 'http://main.example:8001',
            },
          ],
          'active_line_id': 'line-1',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'server-1',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          serverLineProbeCoordinatorProvider.overrideWithValue(
            ServerLineProbeCoordinator(
              probe: (line) async =>
                  ServerLineProbeResult.failure(line, '线路不可达'),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: ServerLinesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加线路'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '公网线路');
    await tester.enterText(fields.at(1), 'http://bad.example:8001');

    await tester.tap(find.text('测试并保存').last);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('服务器线路无响应'), findsOneWidget);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '公网线路');
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      'http://bad.example:8001',
    );
  });
}
