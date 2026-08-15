import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/features/player/player_device_stats.dart';
import 'package:md_center/features/player/player_status_overlay.dart';

void main() {
  test('设备状态可以从原生通道数据解析', () {
    final stats = PlayerDeviceStats.fromMap(const <Object?, Object?>{
      'cpu_percent': 42.5,
      'battery_percent': 87,
      'download_bps': 1536,
      'upload_bps': 512,
      'network_type': '5g',
    });

    expect(stats.cpuPercent, 42.5);
    expect(stats.batteryPercent, 87);
    expect(stats.downloadBytesPerSecond, 1536);
    expect(stats.uploadBytesPerSecond, 512);
    expect(stats.networkType, PlayerNetworkType.cellular5G);
  });

  test('网络类型可以区分 Wi-Fi、4G 和流量兜底状态', () {
    expect(PlayerNetworkType.fromValue('wifi'), PlayerNetworkType.wifi);
    expect(PlayerNetworkType.fromValue('lte'), PlayerNetworkType.cellular4G);
    expect(PlayerNetworkType.fromValue('mobile'), PlayerNetworkType.mobile);
    expect(PlayerNetworkType.fromValue('unsupported'),
        PlayerNetworkType.unknown);
  });

  test('网速格式化按可读单位输出', () {
    expect(formatPlayerNetworkRate(null), '--');
    expect(formatPlayerNetworkRate(512), '512 B/s');
    expect(formatPlayerNetworkRate(2048), '2 KB/s');
    expect(formatPlayerNetworkRate(2 * 1024 * 1024), '2.0 MB/s');
  });

  testWidgets('网络和 CPU OSD 使用图标并保留数值', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerStatusOverlay(
            title: '测试影片',
            stats: const PlayerDeviceStats(
              cpuPercent: 42.5,
              downloadBytesPerSecond: 2048,
              networkType: PlayerNetworkType.wifi,
            ),
            showSystemTime: false,
            showNetworkSpeed: true,
            showCpuUsage: true,
            showBattery: false,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.memory), findsOneWidget);
    expect(find.text('2 KB/s'), findsOneWidget);
    expect(find.text('43%'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsNothing);
    expect(find.text('CPU'), findsNothing);
  });
}
