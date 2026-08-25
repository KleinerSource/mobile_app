import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/core/update/update_repository.dart';
import 'package:omm/features/settings/app_update_settings_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('开发版检测开关位于当前版本卡片并持久化状态', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    Future<void> pumpPage() {
      return tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            appPackageInfoProvider.overrideWith(
              (_) async => PackageInfo(
                appName: 'Oh-My-Media',
                packageName: 'com.ohmymedia.omm',
                version: '0.38.22',
                buildNumber: '409',
              ),
            ),
          ],
          child: const MaterialApp(home: AppUpdateSettingsPage()),
        ),
      );
    }

    await pumpPage();
    await tester.pumpAndSettle();

    final currentVersionGroup = tester
        .widgetList<SettingsGroup>(find.byType(SettingsGroup))
        .singleWhere((group) => group.title == '当前版本');
    final developmentTile = currentVersionGroup.items
        .whereType<SettingsTile>()
        .singleWhere((tile) => tile.title == '检测开发版');
    expect(developmentTile.subtitle, '开启后同时检测标准版与开发版，并选择版本更高的安装包');

    final tileFinder = find.ancestor(
      of: find.text('检测开发版'),
      matching: find.byType(SettingsTile),
    );
    final switchFinder = find.descendant(
      of: tileFinder,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(tester.widget<Switch>(switchFinder).onChanged, isNotNull);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(
      prefs.getBool(UpdateSettingsRepository.includeDevelopmentKey),
      isTrue,
    );

    await pumpPage();
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
  });
}
