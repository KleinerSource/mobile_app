import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/features/player/player_device_stats.dart';

void main() {
  test('设备状态可以从原生通道数据解析', () {
    final stats = PlayerDeviceStats.fromMap(const <Object?, Object?>{
      'cpu_percent': 42.5,
      'battery_percent': 87,
      'download_bps': 1536,
      'upload_bps': 512,
    });

    expect(stats.cpuPercent, 42.5);
    expect(stats.batteryPercent, 87);
    expect(stats.downloadBytesPerSecond, 1536);
    expect(stats.uploadBytesPerSecond, 512);
  });

  test('网速格式化按可读单位输出', () {
    expect(formatPlayerNetworkRate(null), '--');
    expect(formatPlayerNetworkRate(512), '512 B/s');
    expect(formatPlayerNetworkRate(2048), '2 KB/s');
    expect(formatPlayerNetworkRate(2 * 1024 * 1024), '2.0 MB/s');
  });
}
