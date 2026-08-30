import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/files/file_move_start_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('默认从根目录开始选择目标目录', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(fileMoveStartProvider), FileMoveStartLocation.root);
  });

  test('切换起始位置后写入本地偏好', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(fileMoveStartProvider.notifier)
        .setLocation(FileMoveStartLocation.current);
    expect(
      container.read(fileMoveStartProvider),
      FileMoveStartLocation.current,
    );

    await container
        .read(fileMoveStartProvider.notifier)
        .setLocation(FileMoveStartLocation.root);
    expect(container.read(fileMoveStartProvider), FileMoveStartLocation.root);
  });

  test('重新构建时读取已保存的偏好，损坏数据回退默认值', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'file.move_start_location',
      FileMoveStartLocation.current.name,
    );
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(
      container.read(fileMoveStartProvider),
      FileMoveStartLocation.current,
    );
    container.dispose();

    await prefs.setString('file.move_start_location', 'unknown-value');
    final brokenContainer = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(brokenContainer.dispose);
    expect(
      brokenContainer.read(fileMoveStartProvider),
      FileMoveStartLocation.root,
    );
  });
}
