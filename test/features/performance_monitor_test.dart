import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/core/platform/performance_monitor_overlay.dart';
import 'package:omm/features/player/common/player_settings.dart';
import 'package:omm/features/player/video/player_device_stats.dart';
import 'package:omm/features/settings/app_update_settings_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('性能监视器设置默认关闭并可持久化恢复', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = PlayerSettingsRepository(prefs);

    expect(repository.load().performanceMonitorEnabled, isFalse);

    await repository.save(
      const PlayerSettings(debugMode: true, performanceMonitorEnabled: true),
    );

    expect(repository.load().performanceMonitorEnabled, isTrue);
    expect(prefs.getBool('player.performance_monitor_enabled'), isTrue);
  });

  test('设备状态解析应用 CPU 和 RAM 指标，缺失时安全回退', () {
    final stats = PlayerDeviceStats.fromMap(const <Object?, Object?>{
      'process_cpu_percent': 12.5,
      'ram_used_mb': 156,
    });

    expect(stats.processCpuPercent, 12.5);
    expect(stats.ramUsedMegabytes, 156);

    const empty = PlayerDeviceStats();
    expect(empty.processCpuPercent, isNull);
    expect(empty.ramUsedMegabytes, isNull);
  });

  testWidgets('Debug 关闭时性能监视器开关禁用，开启后可操作', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_settingsApp(prefs));
    await tester.pumpAndSettle();

    Switch findSwitch(String title) {
      final tile = find.ancestor(
        of: find.text(title),
        matching: find.byType(SettingsTile),
      );
      return tester.widget<Switch>(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
    }

    expect(findSwitch('性能监视器').onChanged, isNull);

    await prefs.setBool('player.debug_mode', true);
    await tester.pumpWidget(_settingsApp(prefs));
    await tester.pumpAndSettle();

    expect(findSwitch('性能监视器').onChanged, isNotNull);

    final performanceTile = find.ancestor(
      of: find.text('性能监视器'),
      matching: find.byType(SettingsTile),
    );
    final performanceSwitch = find.descendant(
      of: performanceTile,
      matching: find.byType(Switch),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pump();
    await tester.tap(performanceSwitch);
    await tester.pumpAndSettle();
    expect(prefs.getBool('player.performance_monitor_enabled'), isTrue);
  });

  testWidgets('性能覆盖层显示应用 CPU 和 RAM，并按采样更新', (tester) async {
    final reader = _FakeStatsReader([
      const PlayerDeviceStats(processCpuPercent: 12.5, ramUsedMegabytes: 156),
      const PlayerDeviceStats(processCpuPercent: 34, ramUsedMegabytes: 160),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PerformanceMonitorOverlay(statsReader: reader)),
      ),
    );
    await tester.pump();

    expect(find.text('FPS -- · CPU 13% · RAM 156M'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('FPS 0 · CPU 34% · RAM 160M'), findsOneWidget);
  });
}

Widget _settingsApp(SharedPreferences prefs) {
  return ProviderScope(
    key: UniqueKey(),
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
    child: const MaterialApp(home: AppUpdateSettingsPage()),
  );
}

class _FakeStatsReader extends PlayerDeviceStatsReader {
  _FakeStatsReader(this._values);

  final List<PlayerDeviceStats> _values;
  var _index = 0;

  @override
  Future<PlayerDeviceStats> read() async {
    final index = _index < _values.length ? _index++ : _values.length - 1;
    return _values[index];
  }
}
