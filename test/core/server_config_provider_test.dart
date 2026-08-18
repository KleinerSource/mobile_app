import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/core/config/server_line_probe.dart';
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

  test('切换多服务器时会探测目标服务器并选择可用线路', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final probes = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            fallbackDelay: Duration.zero,
            probe: (line) async {
              probes.add(line.id);
              if (line.id == 'remote-lan') {
                return ServerLineProbeResult.failure(line, '局域网线路不可达');
              }
              return ServerLineProbeResult.success(line, 18);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const homeLine = ServerLine(
      id: 'home-line',
      name: '家庭线路',
      baseUrl: 'https://home.example',
    );
    const remoteLan = ServerLine(
      id: 'remote-lan',
      name: '局域网线路',
      baseUrl: 'http://192.168.1.20:8001',
    );
    const remoteWan = ServerLine(
      id: 'remote-wan',
      name: '公网线路',
      baseUrl: 'https://remote.example',
    );
    const home = ServerProfile(
      id: 'home',
      name: '家庭服务器',
      lines: [homeLine],
      activeLineId: 'home-line',
    );
    const remote = ServerProfile(
      id: 'remote',
      name: '远程服务器',
      lines: [remoteLan, remoteWan],
      activeLineId: 'remote-lan',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://home.example',
            lines: [homeLine],
            servers: [home, remote],
            activeServerId: 'home',
          ),
        );

    await container.read(serverConfigProvider.notifier).selectServer(remote.id);

    final config = container.read(serverConfigProvider)!;
    expect(probes, ['remote-lan', 'remote-wan']);
    expect(config.activeServerId, remote.id);
    expect(config.baseUrl, remoteWan.baseUrl);
    expect(config.activeServer?.activeLine?.id, remoteWan.id);
    expect(config.activeServer?.activeLine?.latencyMs, 18);
    expect(container.read(serverSelectionReadyProvider), isTrue);
  });

  test('目标服务器所有线路失败时不切换当前服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final probes = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            fallbackDelay: Duration.zero,
            probe: (line) async {
              probes.add(line.id);
              return ServerLineProbeResult.failure(line, '线路不可达');
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const home = ServerProfile(
      id: 'home',
      name: '当前服务器',
      lines: [
        ServerLine(
          id: 'home-line',
          name: '当前线路',
          baseUrl: 'https://home.example',
        ),
      ],
      activeLineId: 'home-line',
    );
    const remote = ServerProfile(
      id: 'remote',
      name: '目标服务器',
      lines: [
        ServerLine(
          id: 'remote-lan',
          name: '局域网线路',
          baseUrl: 'http://192.168.1.20:8001',
        ),
        ServerLine(
          id: 'remote-wan',
          name: '公网线路',
          baseUrl: 'https://remote.example',
        ),
      ],
      activeLineId: 'remote-lan',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://home.example',
            lines: [
              ServerLine(
                id: 'home-line',
                name: '当前线路',
                baseUrl: 'https://home.example',
              ),
            ],
            servers: [home, remote],
            activeServerId: 'home',
          ),
        );

    await expectLater(
      container.read(serverConfigProvider.notifier).selectServer(remote.id),
      throwsA(isA<StateError>()),
    );

    final config = container.read(serverConfigProvider)!;
    expect(probes, ['remote-lan', 'remote-wan']);
    expect(config.activeServerId, home.id);
    expect(config.baseUrl, 'https://home.example');
    expect(container.read(serverSelectionReadyProvider), isFalse);
  });

  test('默认线路被禁用时选择目标服务器的启用线路', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final probes = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async {
              probes.add(line.id);
              return ServerLineProbeResult.success(line, 24);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const home = ServerProfile(
      id: 'home',
      name: '当前服务器',
      lines: [
        ServerLine(
          id: 'home-line',
          name: '当前线路',
          baseUrl: 'https://home.example',
        ),
      ],
      activeLineId: 'home-line',
    );
    const remote = ServerProfile(
      id: 'remote',
      name: '目标服务器',
      lines: [
        ServerLine(
          id: 'remote-disabled',
          name: '已禁用内网线路',
          baseUrl: 'http://192.168.1.20:8001',
          enabled: false,
        ),
        ServerLine(
          id: 'remote-wan',
          name: '公网线路',
          baseUrl: 'https://remote.example',
        ),
      ],
      activeLineId: 'remote-disabled',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://home.example',
            lines: [
              ServerLine(
                id: 'home-line',
                name: '当前线路',
                baseUrl: 'https://home.example',
              ),
            ],
            servers: [home, remote],
            activeServerId: 'home',
          ),
        );

    await container.read(serverConfigProvider.notifier).selectServer(remote.id);

    final config = container.read(serverConfigProvider)!;
    expect(probes, ['remote-wan']);
    expect(config.baseUrl, 'https://remote.example');
    expect(config.activeServer?.activeLine?.id, 'remote-wan');
  });
}
