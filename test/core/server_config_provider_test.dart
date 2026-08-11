import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('进入服务器编辑不会删除已保存配置', () async {
    SharedPreferences.setMockInitialValues({
      'server.base_url': 'https://saved.example:8001',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(serverConfigProvider)?.baseUrl,
      'https://saved.example:8001',
    );

    container.read(serverConfigProvider.notifier).beginEdit();

    expect(container.read(serverConfigProvider), isNull);
    expect(
      container.read(serverConfigRepoProvider).load()?.baseUrl,
      'https://saved.example:8001',
    );
  });
}
