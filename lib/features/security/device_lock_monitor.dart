import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 提供系统设备锁屏周期事件。
///
/// 设备锁屏由系统本身保护，应用安全锁不应把同一次系统验证再重复
/// 解释为一次应用离开。
class DeviceLockMonitor {
  DeviceLockMonitor._();

  static const EventChannel _channel = EventChannel('md_center/device_lock');

  static Stream<String> get events {
    if (kIsWeb) return const Stream<String>.empty();
    return _channel
        .receiveBroadcastStream()
        .where((event) => event is String)
        .cast<String>();
  }
}
