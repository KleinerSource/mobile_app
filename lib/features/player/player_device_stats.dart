import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class PlayerDeviceStats {
  const PlayerDeviceStats({
    this.cpuPercent,
    this.batteryPercent,
    this.downloadBytesPerSecond,
    this.uploadBytesPerSecond,
  });

  final double? cpuPercent;
  final int? batteryPercent;
  final int? downloadBytesPerSecond;
  final int? uploadBytesPerSecond;

  factory PlayerDeviceStats.fromMap(Map<Object?, Object?> map) {
    return PlayerDeviceStats(
      cpuPercent: _asDouble(map['cpu_percent']),
      batteryPercent: _asInt(map['battery_percent']),
      downloadBytesPerSecond: _asInt(map['download_bps']),
      uploadBytesPerSecond: _asInt(map['upload_bps']),
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
  static const _channel = MethodChannel('md_center/player_stats');

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
  if (bytesPerSecond < 1024) return '${bytesPerSecond} B/s';
  final kb = bytesPerSecond / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB/s';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB/s';
  return '${(mb / 1024).toStringAsFixed(2)} GB/s';
}
