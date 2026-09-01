// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/server_config_provider_test.dart
//   - test/core/server_config_repository_test.dart
//   - test/core/server_profile_cache_repository_test.dart
//   - test/core/server_compatibility_test.dart
//   - test/core/server_line_probe_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_config_repository.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/core/config/server_profile_cache_repository.dart';
import 'package:omm/core/models/system.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/core/server_config_provider_test.dart ====================
void _main_0() {
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

  test('返回服务器选择器会卸载运行态但保留选择器配置', () async {
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

    final notifier = container.read(serverConfigProvider.notifier);
    notifier.showServerSelection();

    expect(container.read(serverConfigProvider), isNull);
    expect(container.read(serverSelectionRequestedProvider), isTrue);
    expect(
      container.read(serverSelectionConfigProvider)?.activeServerId,
      'saved',
    );

    notifier.completeServerSelection();

    expect(container.read(serverSelectionRequestedProvider), isFalse);
    expect(
      container.read(serverConfigRepoProvider).load()?.activeServerId,
      'saved',
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
                  version: '1.14.0',
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

  test('切换服务器时类型不匹配返回明确的兼容性错误', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => ServerLineProbeResult.success(
              line,
              10,
              versionInfo: const ServerVersionInfo(
                projectName: 'oh-my-media',
                version: '2.1.0',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const current = ServerProfile(
      id: 'current',
      name: '当前服务器',
      projectName: 'oh-my-media',
      lines: [
        ServerLine(
          id: 'current-line',
          name: '当前线路',
          baseUrl: 'https://current.example',
        ),
      ],
      activeLineId: 'current-line',
    );
    const target = ServerProfile(
      id: 'target',
      name: 'DB Online',
      projectName: 'db_online',
      lines: [
        ServerLine(
          id: 'target-line',
          name: '目标线路',
          baseUrl: 'https://target.example',
        ),
      ],
      activeLineId: 'target-line',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: 'https://current.example',
            lines: current.lines,
            servers: const [current, target],
            activeServerId: 'current',
          ),
        );

    await expectLater(
      container.read(serverConfigProvider.notifier).selectServer('target'),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('线路项目不匹配'),
            contains('db_online'),
            contains('oh-my-media'),
          ),
        ),
      ),
    );

    expect(container.read(serverConfigProvider)?.activeServerId, 'current');
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
                  version: '1.14.0',
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

  test('活动线路变更未通过版本检查时禁止保存', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const currentLine = ServerLine(
      id: 'current-line',
      name: '当前线路',
      baseUrl: 'https://current.example',
    );
    const nextLine = ServerLine(
      id: 'next-line',
      name: '新线路',
      baseUrl: 'https://next.example',
    );
    const server = ServerProfile(
      id: 'server',
      name: 'DB Online',
      projectName: 'db_online',
      lines: [currentLine],
      activeLineId: 'current-line',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://current.example',
            lines: [currentLine],
            servers: [server],
            activeServerId: 'server',
          ),
        );

    await expectLater(
      container
          .read(serverConfigProvider.notifier)
          .saveServer(
            server.copyWith(lines: [nextLine], activeLineId: nextLine.id),
          ),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          contains('保存前必须通过服务器版本检查'),
        ),
      ),
    );

    expect(
      container.read(serverConfigProvider)?.activeServer?.activeLine?.baseUrl,
      currentLine.baseUrl,
    );
  });

  test('保存活动线路时拒绝低版本和错误类型的探测结果', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const currentLine = ServerLine(
      id: 'current-line',
      name: '当前线路',
      baseUrl: 'https://current.example',
    );
    const nextLine = ServerLine(
      id: 'next-line',
      name: '新线路',
      baseUrl: 'https://next.example',
    );
    const server = ServerProfile(
      id: 'server',
      name: 'DB Online',
      projectName: 'db_online',
      lines: [currentLine],
      activeLineId: 'current-line',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://current.example',
            lines: [currentLine],
            servers: [server],
            activeServerId: 'server',
          ),
        );

    final notifier = container.read(serverConfigProvider.notifier);
    await expectLater(
      notifier.saveServer(
        server.copyWith(lines: [nextLine], activeLineId: nextLine.id),
        validatedProbe: const ServerLineProbeResult.success(
          nextLine,
          10,
          versionInfo: ServerVersionInfo(
            projectName: 'db_online',
            version: '1.13.9',
          ),
        ),
      ),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          allOf(contains('db_online >= 1.14.0'), contains('1.13.9')),
        ),
      ),
    );

    await expectLater(
      notifier.saveServer(
        server.copyWith(lines: [nextLine], activeLineId: nextLine.id),
        validatedProbe: const ServerLineProbeResult.success(
          nextLine,
          10,
          versionInfo: ServerVersionInfo(
            projectName: 'oh-my-media',
            version: '2.1.0',
          ),
        ),
      ),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('线路项目不匹配'),
            contains('db_online'),
            contains('oh-my-media'),
          ),
        ),
      ),
    );

    expect(
      container.read(serverConfigProvider)?.activeServer?.activeLine?.baseUrl,
      currentLine.baseUrl,
    );
  });

  test('删除当前服务器时拒绝低版本的备用服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => ServerLineProbeResult.success(
              line,
              10,
              versionInfo: const ServerVersionInfo(
                projectName: 'db_online',
                version: '1.13.9',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const currentLine = ServerLine(
      id: 'current-line',
      name: '当前线路',
      baseUrl: 'https://current.example',
    );
    const remainingLine = ServerLine(
      id: 'remaining-line',
      name: '备用线路',
      baseUrl: 'https://remaining.example',
    );
    const currentServer = ServerProfile(
      id: 'current-server',
      name: '当前服务器',
      projectName: 'oh-my-media',
      lines: [currentLine],
      activeLineId: 'current-line',
    );
    const remainingServer = ServerProfile(
      id: 'remaining-server',
      name: '备用服务器',
      projectName: 'db_online',
      lines: [remainingLine],
      activeLineId: 'remaining-line',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://current.example',
            lines: [currentLine],
            servers: [currentServer, remainingServer],
            activeServerId: 'current-server',
          ),
        );

    await expectLater(
      container
          .read(serverConfigProvider.notifier)
          .deleteServer('current-server'),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          allOf(contains('db_online >= 1.14.0'), contains('1.13.9')),
        ),
      ),
    );

    final config = container.read(serverConfigProvider)!;
    expect(config.activeServerId, 'current-server');
    expect(config.servers, hasLength(2));
  });

  test('拖拽重排服务器会更新顺序并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const homeLine = ServerLine(
      id: 'home-line',
      name: '主线路',
      baseUrl: 'https://home.example',
    );
    const remoteLine = ServerLine(
      id: 'remote-line',
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
      name: '公网服务器',
      projectName: 'db_online',
      lines: [remoteLine],
      activeLineId: 'remote-line',
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

    // 运行态同步更新，拖拽落点当帧生效（newIndex 已按移除后的列表校正）。
    final pending = container
        .read(serverConfigProvider.notifier)
        .reorderServers(0, 1);
    final config = container.read(serverConfigProvider)!;
    expect(config.servers.map((server) => server.id), ['remote', 'home']);
    // 重排只调整顺序，不改变当前服务器与线路。
    expect(config.activeServerId, 'home');
    expect(config.baseUrl, 'https://home.example');

    await pending;

    final persisted = container.read(serverConfigRepoProvider).load();
    expect(persisted?.servers.map((server) => server.id), ['remote', 'home']);
    expect(persisted?.activeServerId, 'home');
    expect(persisted?.baseUrl, 'https://home.example');
    expect(persisted?.servers.first.lines.single.baseUrl, remoteLine.baseUrl);
  });

  test('原位或越界的重排请求被忽略', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const homeLine = ServerLine(
      id: 'home-line',
      name: '主线路',
      baseUrl: 'https://home.example',
    );
    const remoteLine = ServerLine(
      id: 'remote-line',
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
      name: '公网服务器',
      projectName: 'db_online',
      lines: [remoteLine],
      activeLineId: 'remote-line',
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

    final notifier = container.read(serverConfigProvider.notifier);
    await notifier.reorderServers(1, 1);
    await notifier.reorderServers(5, 0);
    await notifier.reorderServers(0, -1);

    expect(container.read(serverConfigProvider)?.servers.map((s) => s.id), [
      'home',
      'remote',
    ]);
    expect(
      container.read(serverConfigRepoProvider).load()?.servers.map((s) => s.id),
      ['home', 'remote'],
    );
  });
}

// ==================== 原 test/core/server_config_repository_test.dart ====================
void _main_1() {
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
    const line = ServerLine(
      id: 'main',
      name: '主线路',
      baseUrl: 'http://192.168.1.10:8001',
    );
    await repo.save(
      const ServerConfig(
        baseUrl: 'http://192.168.1.10:8001',
        lines: [line],
        servers: [
          ServerProfile(
            id: 'server',
            name: '主服务器',
            lines: [line],
            activeLineId: 'main',
            projectName: 'oh-my-media',
          ),
        ],
        activeServerId: 'server',
      ),
    );
    expect(repo.load()?.baseUrl, 'http://192.168.1.10:8001');
    expect(repo.load()?.lines, hasLength(1));
    expect(repo.load()?.lines.single.name, '主线路');
  });

  test('没有服务器类型的旧版配置会被清理', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server.base_url', 'http://legacy.example/');
    final repo = ServerConfigRepository(prefs);

    expect(repo.load(), isNull);
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString('server.base_url'), isNull);
    expect(prefs.getString('server.lines'), isNull);
    expect(prefs.getString('server.servers'), isNull);
  });

  test('服务器列表中的未知类型会被清理', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'server.servers',
      jsonEncode([
        {
          'id': 'legacy',
          'name': '旧服务器',
          'lines': [
            {'id': 'line', 'name': '主线路', 'base_url': 'https://legacy'},
          ],
          'active_line_id': 'line',
          'project_name': 'unknown-project',
        },
      ]),
    );
    final repo = ServerConfigRepository(prefs);

    expect(repo.load(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString('server.servers'), isNull);
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
        servers: [
          ServerProfile(
            id: 'home',
            name: '家庭服务器',
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
            activeLineId: 'home',
            projectName: 'oh-my-media',
          ),
        ],
        activeServerId: 'home',
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
      projectName: 'oh-my-media',
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
      projectName: 'oh-my-media',
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

// ==================== 原 test/core/server_profile_cache_repository_test.dart ====================
void _main_2() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('服务器资料可以持久化并按服务器隔离', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerProfileCacheRepository(prefs);
    const home = ServerProfileData(
      name: '家庭服务器',
      avatarUrl: 'https://home.example/api/public/avatar',
    );
    const remote = ServerProfileData(name: '公网服务器');

    await repository.save('home', home);
    await repository.save('remote', remote);

    expect(repository.load('home')?.name, '家庭服务器');
    expect(repository.load('home')?.avatarUrl, home.avatarUrl);
    expect(repository.load('remote')?.name, remote.name);
    expect(repository.load('remote')?.avatarUrl, remote.avatarUrl);
    expect(repository.load('missing'), isNull);
  });

  test('并发保存多台服务器资料不会互相覆盖', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerProfileCacheRepository(prefs);

    await Future.wait([
      repository.save('home', const ServerProfileData(name: '家庭服务器')),
      repository.save('remote', const ServerProfileData(name: '公网服务器')),
    ]);

    expect(repository.load('home')?.name, '家庭服务器');
    expect(repository.load('remote')?.name, '公网服务器');
  });

  test('可以删除单台服务器资料并清空全部缓存', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerProfileCacheRepository(prefs);
    const profile = ServerProfileData(name: '服务器');

    await repository.save('home', profile);
    await repository.save('remote', profile);
    await repository.remove('home');

    expect(repository.load('home'), isNull);
    expect(repository.load('remote')?.name, profile.name);

    await repository.clear();
    expect(repository.load('remote'), isNull);
  });
}

// ==================== 原 test/core/server_compatibility_test.dart ====================
void _main_3() {
  test('各服务器类型返回正确的默认端口', () {
    expect(defaultServerPort(ServerProject.ohMyMedia), 8001);
    expect(defaultServerPort(ServerProject.dbOnline), 9090);
    expect(defaultServerPort(ServerProject.smb), 445);
    expect(defaultServerPort(ServerProject.webDav), 80);
    expect(defaultServerPort(ServerProject.webDav, scheme: 'https'), 443);
    expect(defaultServerPort(ServerProject.openList), 5244);
    expect(defaultServerPort(ServerProject.openList, scheme: 'https'), 443);
  });

  test('最低版本满足要求', () {
    expect(isSupportedServerVersion('2.0.0'), isTrue);
    expect(isSupportedServerVersion('2.0.1'), isTrue);
    expect(isSupportedServerVersion('2.10.0'), isTrue);
  });

  test('低于最低版本或格式非法时拒绝', () {
    expect(isSupportedServerVersion('1.5.99'), isFalse);
    expect(isSupportedServerVersion('1.9.0-beta'), isFalse);
    expect(isSupportedServerVersion('dev'), isFalse);
  });

  test('项目名称和版本均正确时通过', () {
    final info = requireCompatibleServerVersion({
      'success': true,
      'data': {'project_name': 'oh-my-media', 'version': '2.0.0'},
    });

    expect(info.projectName, 'oh-my-media');
    expect(info.version, '2.0.0');
  });

  test('项目名称错误时拒绝', () {
    expect(
      () => requireCompatibleServerVersion({
        'success': true,
        'data': {'project_name': 'other_project', 'version': '9.9.9'},
      }),
      throwsA(isA<ServerCompatibilityException>()),
    );
  });

  test('版本过低时拒绝', () {
    expect(
      () => requireCompatibleServerVersion({
        'success': true,
        'data': {'project_name': 'oh-my-media', 'version': '1.5.9'},
      }),
      throwsA(isA<ServerCompatibilityException>()),
    );
  });

  test('dbonline 项目和开发版/构建元数据版本通过', () {
    final info = requireCompatibleServerVersion({
      'success': true,
      'data': {'project_name': 'db_online', 'version': 'v1.14.0-dev+build.7'},
    });
    expect(info.project, ServerProject.dbOnline);
    expect(isSupportedServerVersion('1.14.14-dev', '1.14.0'), isTrue);
    expect(isSupportedServerVersion('1.12.99-dev', '1.13.0'), isFalse);
  });

  test('四段式版本（Emby）忽略末段 build 号后比较前三段', () {
    expect(isSupportedServerVersion('4.9.5.0', '4.6.0'), isTrue);
    expect(isSupportedServerVersion('4.9.5.10', '4.6.0'), isTrue);
    expect(isSupportedServerVersion('4.6.0.1', '4.6.0'), isTrue);
    expect(isSupportedServerVersion('4.5.9.99', '4.6.0'), isFalse);
    // 三段式行为保持不变。
    expect(isSupportedServerVersion('4.6.0', '4.6.0'), isTrue);
    expect(isSupportedServerVersion('4.5.2', '4.6.0'), isFalse);
  });

  test('dbonline 低于 1.14.0 时拒绝并提示实际版本', () {
    expect(
      () => requireCompatibleServerVersion({
        'success': true,
        'data': {'project_name': 'db_online', 'version': '1.13.9'},
      }),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          allOf(contains('db_online >= 1.14.0'), contains('当前版本为 1.13.9')),
        ),
      ),
    );
  });

  test('未知项目和格式错误包含实际值及兼容要求', () {
    expect(
      () => requireCompatibleServerVersion({
        'success': true,
        'data': {'project_name': 'other', 'version': '9.9.9'},
      }),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          allOf(contains('other'), contains('9.9.9'), contains('db_online')),
        ),
      ),
    );
    expect(
      () => requireCompatibleServerVersion(const {'success': true}),
      throwsA(
        isA<ServerCompatibilityException>().having(
          (error) => error.message,
          'message',
          contains('响应格式不兼容'),
        ),
      ),
    );
  });
}

// ==================== 原 test/core/server_line_probe_test.dart ====================
void _main_4() {
  const current = ServerLine(
    id: 'current',
    name: '当前线路',
    baseUrl: 'https://current.example',
  );
  const backup = ServerLine(
    id: 'backup',
    name: '备用线路',
    baseUrl: 'https://backup.example',
  );

  test('当前线路在优先窗口内可用时不启动备用线路', () async {
    var backupProbeCount = 0;
    final coordinator = ServerLineProbeCoordinator(
      fallbackDelay: const Duration(seconds: 1),
      probe: (line) async {
        if (line.id == backup.id) backupProbeCount++;
        return ServerLineProbeResult.success(line, 20);
      },
    );

    final selection = await coordinator.selectPreferred(
      current: current,
      alternatives: const [backup],
    );

    expect(selection.selected?.line, current);
    expect(backupProbeCount, 0);
  });

  test('当前线路失败后立即启用备用线路', () async {
    final coordinator = ServerLineProbeCoordinator(
      fallbackDelay: const Duration(seconds: 1),
      probe: (line) async {
        if (line.id == current.id) {
          return ServerLineProbeResult.failure(line, '连接失败');
        }
        return ServerLineProbeResult.success(line, 35);
      },
    );

    final selection = await coordinator.selectPreferred(
      current: current,
      alternatives: const [backup],
    );

    expect(selection.selected?.line, backup);
    expect(selection.selected?.latencyMs, 35);
  });

  test('线路探测将鉴权失败与不可用状态区分', () async {
    final coordinator = ServerLineProbeCoordinator(
      probe: (_) async => throw ApiException('请先登录', status: 401),
    );

    final result = await coordinator.probe(current);

    expect(result.success, isFalse);
    expect(result.requiresAuthentication, isTrue);
    expect(result.incompatible, isFalse);
  });

  test('并发测速在首条线路成功时立即返回，不等待慢线路', () async {
    final slowResult = Completer<ServerLineProbeResult>();
    final coordinator = ServerLineProbeCoordinator(
      probe: (line) {
        if (line.id == current.id) return slowResult.future;
        return Future.value(ServerLineProbeResult.success(line, 30));
      },
    );

    final batch = coordinator.probeAll(const [current, backup]);
    final selected = await batch.firstAvailable;

    expect(selected?.line, backup);
    var completed = false;
    unawaited(batch.completed.then((_) => completed = true));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    slowResult.complete(const ServerLineProbeResult.failure(current, '连接超时'));
    final results = await batch.completed;
    expect(results, hasLength(2));
  });

  test('线路探测会拒绝与服务器项目不一致的线路', () async {
    final coordinator = ServerLineProbeCoordinator(
      probe: (line) async => ServerLineProbeResult.success(
        line,
        12,
        versionInfo: const ServerVersionInfo(
          projectName: 'db_online',
          version: '1.13.14-dev',
        ),
      ),
    );

    final selection = await coordinator.selectPreferred(
      current: current,
      expectedProjectName: ServerProject.ohMyMedia.projectName,
    );

    expect(selection.selected, isNull);
    expect(selection.results.single.incompatible, isTrue);
    expect(selection.results.single.message, contains('db_online'));
    expect(selection.results.single.versionInfo?.version, '1.13.14-dev');
  });

  test('线路探测成功结果携带项目和版本信息', () async {
    final coordinator = ServerLineProbeCoordinator(
      probe: (line) async => ServerLineProbeResult.success(
        line,
        8,
        versionInfo: const ServerVersionInfo(
          projectName: 'oh-my-media',
          version: '2.1.0',
        ),
      ),
    );

    final selection = await coordinator.selectPreferred(
      current: current,
      expectedProjectName: ServerProject.ohMyMedia.projectName,
    );

    expect(selection.selected?.versionInfo?.project, ServerProject.ohMyMedia);
    expect(selection.selected?.versionInfo?.version, '2.1.0');
  });

  test('DBO 线路探测会校验健康状态', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/version') {
        request.response.write(
          jsonEncode({
            'success': true,
            'data': {'project_name': 'db_online', 'version': '1.14.0'},
          }),
        );
      } else if (request.uri.path == '/api/health') {
        request.response.write(jsonEncode({'status': 'healthy'}));
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      request.response.close();
    });

    try {
      final result = await probeServerLine(
        ServerLine(
          id: 'db-online',
          name: 'DBO',
          baseUrl: 'http://127.0.0.1:${server.port}',
        ),
      );

      expect(result.success, isTrue);
      expect(result.versionInfo?.project, ServerProject.dbOnline);
      expect(requests, ['/api/version', '/api/health']);
    } finally {
      await server.close(force: true);
    }
  });
}

void main() {
  group('server_config_provider', _main_0);
  group('server_config_repository', _main_1);
  group('server_profile_cache_repository', _main_2);
  group('server_compatibility', _main_3);
  group('server_line_probe', _main_4);
}
