// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/app_update_startup_gate_test.dart
//   - test/features/app_update_settings_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_log_store.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/core/update/update_repository.dart';
import 'package:omm/features/settings/app_log_page.dart';
import 'package:omm/features/settings/app_update_settings_page.dart';
import 'package:omm/features/settings/app_update_startup_gate.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/features/app_update_startup_gate_test.dart ====================
void _main_0() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('鉴权与安全锁就绪后才执行启动更新检查', (tester) async {
    SharedPreferences.setMockInitialValues({
      UpdateSettingsRepository.githubRepositoryKey:
          'https://github.com/example/mobile_app',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    var checkCount = 0;

    Widget app(bool enabled) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: StartupUpdateGate(
          enabled: enabled,
          startDelay: Duration.zero,
          retryDelays: const [Duration.zero],
          retryAfterFailure: const Duration(hours: 1),
          checkForUpdate: (_, __) async {
            checkCount++;
            return true;
          },
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(checkCount, 0);

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(checkCount, 1);
  });

  testWidgets('更新源在启动门控创建后就绪仍会自动检查', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    var checkCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StartupUpdateGate(
            enabled: true,
            startDelay: Duration.zero,
            retryDelays: const [Duration.zero],
            retryAfterFailure: const Duration(hours: 1),
            checkForUpdate: (_, __) async {
              checkCount++;
              return true;
            },
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(checkCount, 0);

    await container
        .read(updateRepositoryUrlProvider.notifier)
        .save('https://github.com/example/mobile_app');
    await tester.pumpAndSettle();
    expect(checkCount, 1);
  });
}

// ==================== 原 test/features/app_update_settings_page_test.dart ====================
void _main_1() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLogStore.instance.clear();
  });

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

  testWidgets('应用更新页提供播放日志入口', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    appLog('[FilePlaybackProxy] 测试日志');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AppUpdateSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看播放日志'), findsOneWidget);
  });

  testWidgets('播放日志页显示当前运行日志', (tester) async {
    appLog('[FilePlaybackProxy] 测试日志');
    await tester.pumpWidget(const MaterialApp(home: AppLogPage()));
    await tester.pumpAndSettle();

    expect(find.byType(AppLogPage), findsOneWidget);
    expect(find.textContaining('测试日志'), findsOneWidget);
  });
}

void main() {
  group('app_update_startup_gate', _main_0);
  group('app_update_settings_page', _main_1);
}
