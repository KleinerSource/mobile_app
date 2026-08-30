import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_config_repository.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/features/settings/server_list_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/server_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'home',
          'name': '家庭服务器',
          'lines': [
            {
              'id': 'home-line',
              'name': '主线路',
              'base_url': 'https://home.example',
            },
          ],
          'active_line_id': 'home-line',
          'project_name': 'oh-my-media',
        },
        {
          'id': 'remote',
          'name': '公网服务器',
          'lines': [
            {
              'id': 'remote-line',
              'name': '主线路',
              'base_url': 'https://remote.example',
            },
          ],
          'active_line_id': 'remote-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'home',
    });
    AppHaptics.setIntensity(HapticIntensity.standard);
  });

  testWidgets('服务器列表使用头像而非服务器图标', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    expect(find.byType(ServerAvatar), findsNWidgets(2));
    expect(find.byIcon(Icons.dns_outlined), findsNothing);
  });

  testWidgets('拖拽排序全程有触觉反馈且顺序持久化', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        // HapticFeedback 各档统一走 HapticFeedback.vibrate，具体类型在参数里。
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String? ?? '');
        }
        return null;
      },
    );

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    // 长按“家庭服务器”整行拖动，跨过公网服务器后落定。
    final row = tester.getCenter(find.text('家庭服务器'));
    final gesture = await tester.startGesture(row);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    // 拖起确认。
    expect(haptics, contains('HapticFeedbackType.lightImpact'));

    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    // 拖起 + 跨过一台服务器，至少两次轻反馈。
    expect(
      haptics.where((type) => type == 'HapticFeedbackType.lightImpact').length,
      greaterThanOrEqualTo(2),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    // 落定确认。
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));

    final persisted = ServerConfigRepository(prefs).load();
    expect(persisted?.servers.map((server) => server.id), ['remote', 'home']);
    expect(persisted?.activeServerId, 'home');
  });

  testWidgets('原位放回不重排也不触发放置反馈', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String? ?? '');
        }
        return null;
      },
    );

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    // 长按原行拖动后放回原位。
    final row = tester.getCenter(find.text('家庭服务器'));
    final gesture = await tester.startGesture(row);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // 只有拖起反馈，没有换槽和落定反馈。
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    final persisted = ServerConfigRepository(prefs).load();
    expect(persisted?.servers.map((server) => server.id), ['home', 'remote']);
  });
}

Widget _app(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: ServerListPage(),
    ),
  );
}
