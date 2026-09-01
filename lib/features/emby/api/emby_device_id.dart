import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Emby 会话绑定到设备维度，DeviceId 必须跨登录稳定，否则服务器会为
/// 同一台手机累积大量设备记录。首次使用时生成并持久化。
const _kEmbyDeviceId = 'emby.device_id';

Future<String> embyDeviceId(SharedPreferences prefs) async {
  final existing = prefs.getString(_kEmbyDeviceId)?.trim() ?? '';
  if (existing.isNotEmpty) return existing;
  final generated = _generateUuid();
  await prefs.setString(_kEmbyDeviceId, generated);
  return generated;
}

String _generateUuid() {
  const hex = '0123456789abcdef';
  final random = Random.secure();
  final units = List<int>.generate(16, (_) => random.nextInt(16));
  // 按 UUID v4 样式标注版本与变体位，仅作展示区分，无加密含义。
  units[6] = (units[6] & 0x0f) | 0x40;
  units[8] = (units[8] & 0x3f) | 0x80;
  final hexUnits = units.map((unit) => hex[unit]).join();
  final parts = [
    hexUnits.substring(0, 8),
    hexUnits.substring(8, 12),
    hexUnits.substring(12, 16),
    hexUnits.substring(16, 20),
    hexUnits.substring(20, 32),
  ];
  return parts.join('-');
}
