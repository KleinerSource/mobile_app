import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_repository.dart';
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
    expect(repo.load()?.lines, hasLength(1));
    expect(repo.load()?.lines.single.name, '主线路');
  });

  test('旧版单线路配置会迁移为线路列表', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server.base_url', 'http://legacy.example/');
    final repo = ServerConfigRepository(prefs);

    final config = repo.load();

    expect(config?.baseUrl, 'http://legacy.example');
    expect(config?.lines, hasLength(1));
    expect(config?.lines.single.id, 'legacy');
  });

  test('多线路配置会保存并恢复测试信息', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerConfigRepository(prefs);
    final testedAt = DateTime.utc(2026, 8, 10, 12);
    await repo.save(
      ServerConfig(
        baseUrl: 'http://home.example/',
        lines: [
          const ServerLine(
            id: 'home',
            name: '家庭网络',
            baseUrl: 'http://home.example/',
          ),
          ServerLine(
            id: 'remote',
            name: '公网线路',
            baseUrl: 'https://remote.example/api/',
            enabled: false,
            latencyMs: 42,
            lastTestedAt: testedAt,
          ),
        ],
      ),
    );

    final config = repo.load();

    expect(config?.baseUrl, 'http://home.example');
    expect(config?.lines, hasLength(2));
    expect(config?.lines[0].baseUrl, 'http://home.example');
    expect(config?.lines[1].baseUrl, 'https://remote.example');
    expect(config?.lines[1].enabled, isFalse);
    expect(config?.lines[1].latencyMs, 42);
    expect(config?.lines[1].lastTestedAt, testedAt);
  });

  test('多服务器配置会保存各自线路并恢复当前服务器', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerConfigRepository(prefs);
    const home = ServerProfile(
      id: 'home',
      name: '家庭服务器',
      avatarUrl: 'https://media.example/avatar.png',
      lines: [
        ServerLine(
          id: 'home-lan',
          name: '局域网',
          baseUrl: 'http://192.168.1.10:8001/',
        ),
      ],
      activeLineId: 'home-lan',
    );
    const remote = ServerProfile(
      id: 'remote',
      name: '公网服务器',
      projectName: 'db_online',
      serverVersion: '1.13.14-dev',
      lines: [
        ServerLine(
          id: 'remote-cdn',
          name: 'CDN',
          baseUrl: 'https://media.example/',
        ),
      ],
      activeLineId: 'remote-cdn',
    );

    await repo.save(
      ServerConfig(
        baseUrl: 'http://192.168.1.10:8001',
        lines: home.lines,
        servers: const [home, remote],
        activeServerId: 'home',
      ),
    );

    var config = repo.load();
    expect(config?.servers, hasLength(2));
    expect(config?.activeServerId, 'home');
    expect(config?.baseUrl, 'http://192.168.1.10:8001');
    expect(config?.servers[1].lines.single.baseUrl, 'https://media.example');
    expect(config?.servers[1].projectName, 'db_online');
    expect(config?.servers[1].serverVersion, '1.13.14-dev');
    expect(config?.servers[0].avatarUrl, 'https://media.example/avatar.png');

    await repo.save(
      config!.copyWith(
        baseUrl: 'https://media.example',
        lines: remote.lines,
        activeServerId: 'remote',
      ),
    );
    config = repo.load();
    expect(config?.activeServerId, 'remote');
    expect(config?.baseUrl, 'https://media.example');
    expect(config?.servers[0].lines.single.baseUrl, 'http://192.168.1.10:8001');
  });

  test('服务器头像地址会随本地配置保存并恢复', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ServerConfigRepository(prefs);
    const server = ServerProfile(
      id: 'server',
      name: '服务器',
      avatarUrl: 'https://media.example/avatar.png',
      lines: [
        ServerLine(id: 'line', name: '主线路', baseUrl: 'https://media.example'),
      ],
      activeLineId: 'line',
    );

    await repo.save(
      ServerConfig(
        baseUrl: 'https://media.example',
        lines: server.lines,
        servers: const [server],
        activeServerId: 'server',
      ),
    );

    expect(repo.load()?.activeServer?.avatarUrl, server.avatarUrl);
  });

  test('normalize 去除末尾斜杠', () {
    expect(ServerConfig.normalize('http://x:8001/'), 'http://x:8001');
    expect(ServerConfig.normalize(' http://x:8001 '), 'http://x:8001');
  });

  test('normalize 去除用户输入的 API 路径', () {
    expect(ServerConfig.normalize('http://x:8001/api'), 'http://x:8001');
    expect(
      ServerConfig.normalize('https://x.example/API/'),
      'https://x.example',
    );
    expect(
      ServerConfig.normalize('https://x.example/media/api'),
      'https://x.example/media',
    );
  });
}
