import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config.dart';
import 'package:md_center/core/config/server_config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('未设置时返回 null', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerConfigRepository(prefs);
    expect(repo.load(), isNull);
  });

  test('save / load 往返', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerConfigRepository(prefs);
    await repo.save(const ServerConfig(baseUrl: 'http://192.168.1.10:8001'));
    expect(repo.load()?.baseUrl, 'http://192.168.1.10:8001');
  });

  test('normalize 去除末尾斜杠', () {
    expect(ServerConfig.normalize('http://x:8001/'), 'http://x:8001');
    expect(ServerConfig.normalize(' http://x:8001 '), 'http://x:8001');
  });
}
