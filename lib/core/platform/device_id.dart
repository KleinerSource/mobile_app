import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 设备维度的稳定 ID，供 Emby/Jellyfin 等 MediaBrowser 系后端登录时
/// 声明客户端身份。
///
/// DeviceId 标识的是这台手机而不是某个后端，因此全局共用一个键；
/// 必须跨登录稳定，否则服务器会为同一台手机累积大量设备记录。
/// 首次使用时生成 UUID v4 并持久化，同时兼容读取两个后端各自的
/// 历史键，避免已登录设备在升级后更换身份。
const _kDeviceId = 'device.stable_id';

const _legacyDeviceIdKeys = <String>['emby.device_id', 'jellyfin.device_id'];

Future<String> stableDeviceId(SharedPreferences prefs) async {
  final existing = prefs.getString(_kDeviceId)?.trim() ?? '';
  if (existing.isNotEmpty) return existing;
  for (final legacyKey in _legacyDeviceIdKeys) {
    final legacy = prefs.getString(legacyKey)?.trim() ?? '';
    if (legacy.isNotEmpty) {
      await prefs.setString(_kDeviceId, legacy);
      return legacy;
    }
  }
  final generated = generateUuidV4();
  await prefs.setString(_kDeviceId, generated);
  return generated;
}

/// 生成 UUID v4 样式的随机标识。
///
/// 版本位/变体位定义在字节上：先取 16 个随机字节再设置位，最后编码
/// 成 hex；顺序反了会拿版本位的 0x4x 去索引 16 长度的 hex 字母表。
String generateUuidV4() {
  const hexDigits = '0123456789abcdef';
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // 版本 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // 变体 10x
  final hex = bytes
      .map((byte) => '${hexDigits[byte >> 4]}${hexDigits[byte & 0x0f]}')
      .join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20, 32),
  ].join('-');
}
