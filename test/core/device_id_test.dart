import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('stableDeviceId 生成 UUID v4 并跨调用保持稳定', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = await stableDeviceId(prefs);
    final second = await stableDeviceId(prefs);

    expect(first, matches(_uuidPattern));
    expect(second, first, reason: '同一存储下的设备 ID 必须跨调用稳定');
    expect(prefs.getString('device.stable_id'), first);
  });

  test('兼容迁移 Emby/Jellyfin 各自键下的历史设备 ID', () async {
    SharedPreferences.setMockInitialValues({
      'emby.device_id': 'legacy-emby-id',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(await stableDeviceId(prefs), 'legacy-emby-id');
    expect(prefs.getString('device.stable_id'), 'legacy-emby-id');

    SharedPreferences.setMockInitialValues({
      'jellyfin.device_id': 'legacy-jellyfin-id',
    });
    final other = await SharedPreferences.getInstance();
    expect(await stableDeviceId(other), 'legacy-jellyfin-id');
  });

  test('连续大量生成不产生越界索引，且互不相同', () async {
    final ids = <String>{};
    // 回归：UUID 版本位/变体位曾按 hex 位索引设置，导致 RangeError(0..15)。
    // 版本位固定为 4，之前的实现必现崩溃；此处大量生成兜住任何回归。
    for (var i = 0; i < 200; i++) {
      final id = generateUuidV4();
      expect(id, matches(_uuidPattern));
      ids.add(id);
    }
    expect(ids, hasLength(200));
  });
}
