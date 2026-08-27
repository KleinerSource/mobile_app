import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('进入服务器编辑不会删除已保存配置', () async {
    SharedPreferences.setMockInitialValues({
      'server.servers': jsonEncode([
        {
          'id': 'saved',
          'name': '已保存服务器',
          'lines': [
            {
              'id': 'saved-line',
              'name': '主线路',
              'base_url': 'https://saved.example:8001',
            },
          ],
          'active_line_id': 'saved-line',
          'project_name': 'oh-my-media',
        },
      ]),
      'server.active_server_id': 'saved',
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
              return ServerLineProbeResult.success(
                line,
                18,
                versionInfo: const ServerVersionInfo(
                  projectName: 'db_online',
                  version: '1.13.0',
                ),
              );
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
      projectName: 'oh-my-media',
      lines: [homeLine],
      activeLineId: 'home-line',
    );
    const remote = ServerProfile(
      id: 'remote',
      name: '远程服务器',
      projectName: 'db_online',
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
      projectName: 'oh-my-media',
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
      projectName: 'db_online',
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
              return ServerLineProbeResult.success(
                line,
                24,
                versionInfo: const ServerVersionInfo(
                  projectName: 'db_online',
                  version: '1.13.0',
                ),
              );
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const home = ServerProfile(
      id: 'home',
      name: '当前服务器',
      projectName: 'oh-my-media',
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
      projectName: 'db_online',
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

  test('线路探测返回的项目类型不会覆盖已保存类型', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => ServerLineProbeResult.success(
              line,
              18,
              versionInfo: const ServerVersionInfo(
                projectName: 'OH-MY-MEDIA',
                version: '2.1.0',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const line = ServerLine(
      id: 'line',
      name: '主线路',
      baseUrl: 'https://media.example',
    );
    const server = ServerProfile(
      id: 'server',
      name: '媒体服务器',
      lines: [line],
      activeLineId: 'line',
      projectName: 'oh-my-media',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://media.example',
            lines: [line],
            servers: [server],
            activeServerId: 'server',
          ),
        );

    await container.read(serverConfigProvider.notifier).selectServer(server.id);

    final saved = container.read(serverConfigProvider)!.activeServer!;
    expect(saved.projectName, 'oh-my-media');
    expect(saved.serverVersion, '2.1.0');
  });

  test('同一服务器禁止保存不同项目的线路元数据', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const line = ServerLine(
      id: 'omm-line',
      name: '主线路',
      baseUrl: 'https://omm.example',
    );
    const server = ServerProfile(
      id: 'server',
      name: '媒体服务器',
      lines: [line],
      activeLineId: 'omm-line',
      projectName: 'oh-my-media',
      serverVersion: '2.0.0',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://omm.example',
            lines: [line],
            servers: [server],
            activeServerId: 'server',
          ),
        );

    await expectLater(
      container
          .read(serverConfigProvider.notifier)
          .saveServer(
            server.copyWith(
              projectName: 'db_online',
              serverVersion: '1.13.14-dev',
            ),
          ),
      throwsA(isA<StateError>()),
    );

    expect(
      container.read(serverConfigProvider)?.activeServer?.projectName,
      'oh-my-media',
    );
  });
}
