import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PlayerNetworkType {
  wifi('wifi', 'Wi-Fi'),
  cellular4G('4g', '4G'),
  cellular5G('5g', '5G'),
  mobile('mobile', '流量'),
  ethernet('ethernet', '以太网'),
  offline('offline', '离线'),
  unknown('unknown', '网络');

  const PlayerNetworkType(this.value, this.label);

  final String value;
  final String label;

  static PlayerNetworkType fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'wifi' => PlayerNetworkType.wifi,
      '4g' || 'lte' => PlayerNetworkType.cellular4G,
      '5g' || 'nr' => PlayerNetworkType.cellular5G,
      'mobile' || 'cellular' => PlayerNetworkType.mobile,
      'ethernet' => PlayerNetworkType.ethernet,
      'offline' || 'none' => PlayerNetworkType.offline,
      _ => PlayerNetworkType.unknown,
    };
  }
}

@immutable
class PlayerDeviceStats {
  const PlayerDeviceStats({
    this.cpuPercent,
    this.processCpuPercent,
    this.ramUsedMegabytes,
    this.batteryPercent,
    this.downloadBytesPerSecond,
    this.uploadBytesPerSecond,
    this.networkType = PlayerNetworkType.unknown,
  });

  final double? cpuPercent;
  final double? processCpuPercent;
  final int? ramUsedMegabytes;
  final int? batteryPercent;
  final int? downloadBytesPerSecond;
  final int? uploadBytesPerSecond;
  final PlayerNetworkType networkType;

  factory PlayerDeviceStats.fromMap(Map<Object?, Object?> map) {
    return PlayerDeviceStats(
      cpuPercent: _asDouble(map['cpu_percent']),
      processCpuPercent: _asDouble(map['process_cpu_percent']),
      ramUsedMegabytes: _asInt(map['ram_used_mb']),
      batteryPercent: _asInt(map['battery_percent']),
      downloadBytesPerSecond: _asInt(map['download_bps']),
      uploadBytesPerSecond: _asInt(map['upload_bps']),
      networkType: PlayerNetworkType.fromValue(map['network_type']?.toString()),
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}

class PlayerDeviceStatsReader {
  const PlayerDeviceStatsReader();

  static const _channel = MethodChannel('omm/player_stats');

  Future<PlayerDeviceStats> read() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const PlayerDeviceStats();
    }
    try {
      final raw = await _channel.invokeMethod<Object?>('readStats');
      if (raw is! Map) return const PlayerDeviceStats();
      return PlayerDeviceStats.fromMap(Map<Object?, Object?>.from(raw));
    } on MissingPluginException {
      return const PlayerDeviceStats();
    } on PlatformException {
      return const PlayerDeviceStats();
    } catch (_) {
      return const PlayerDeviceStats();
    }
  }
}

String formatPlayerNetworkRate(int? bytesPerSecond) {
  if (bytesPerSecond == null) return '--';
  if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
  final kb = bytesPerSecond / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB/s';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB/s';
  return '${(mb / 1024).toStringAsFixed(2)} GB/s';
}
