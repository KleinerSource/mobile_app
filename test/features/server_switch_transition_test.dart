import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/home/server_switch_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Emby/Jellyfin 转场头像优先使用用户头像并支持回退', () {
    const line = ServerLine(
      id: 'media-line',
      name: '主线路',
      baseUrl: 'https://media.example',
    );
    const profile = ServerProfileData(
      name: 'Alice',
      avatarUrl: 'https://media.example/logo.png',
      userAvatarUrl: 'https://media.example/user.png?ApiKey=secret',
    );

    for (final project in [ServerProject.emby, ServerProject.jellyfin]) {
      final server = ServerProfile(
        id: project.projectName,
        name: project.displayName,
        lines: const [line],
        projectName: project.projectName,
        avatarUrl: 'https://media.example/configured.png',
      );
      expect(
        serverSwitchTransitionAvatarUrl(
          server: server,
          profile: profile,
          showUserAvatar: true,
        ),
        profile.userAvatarUrl,
      );
      expect(
        serverSwitchTransitionAvatarUrl(
          server: server,
          profile: profile,
          showUserAvatar: false,
        ),
        profile.avatarUrl,
      );
      expect(
        serverSwitchTransitionAvatarUrl(
          server: server,
          profile: const ServerProfileData(name: 'Alice'),
          showUserAvatar: true,
        ),
        server.avatarUrl,
      );
    }

    final feiniu = ServerProfile(
      id: 'feiniu',
      name: '飞牛',
      lines: const [line],
      projectName: ServerProject.feiniu.projectName,
      avatarUrl: 'https://feiniu.example/logo.png',
    );
    expect(
      serverSwitchTransitionAvatarUrl(
        server: feiniu,
        profile: const ServerProfileData(name: 'Alice'),
        showUserAvatar: true,
      ),
      feiniu.avatarUrl,
    );

    final omm = ServerProfile(
      id: 'omm',
      name: 'OMM',
      lines: const [line],
      projectName: ServerProject.ohMyMedia.projectName,
      avatarUrl: 'https://omm.example/logo.png',
    );
    expect(
      serverSwitchTransitionAvatarUrl(
        server: omm,
        profile: const ServerProfileData(
          name: 'OMM',
          avatarUrl: 'https://omm.example/profile.png',
          userAvatarUrl: 'https://omm.example/user.png',
        ),
        showUserAvatar: true,
      ),
      isNull,
    );
  });

  test('自动恢复失败标记会打开当前服务器的登录阶段', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const line = ServerLine(
      id: 'server-line',
      name: '主线路',
      baseUrl: 'https://server.example',
    );
    final server = ServerProfile(
      id: 'server-1',
      name: '服务器一',
      lines: const [line],
      activeLineId: line.id,
      projectName: 'oh-my-media',
    );
    final config = ServerConfig(
      baseUrl: line.baseUrl,
      lines: const [line],
      servers: [server],
      activeServerId: server.id,
    );
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverConfigProvider.overrideWith(
          () => _SwitchTestServerConfigNotifier(config),
        ),
        serverSelectionReadyProvider.overrideWith((ref) => true),
        authControllerProvider.overrideWith(
          () => _RecoveryRequiredAuthController(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(serverSwitchTransitionProvider);
    await container.read(authControllerProvider.future);
    container.read(authExpiryEventProvider.notifier).state =
        const AuthExpiryEvent(id: 1, serverId: 'server-1');
    await Future<void>.delayed(Duration.zero);

    final transition = container.read(serverSwitchTransitionProvider);
    expect(transition.phase, ServerSwitchPhase.needsLogin);
    expect(transition.targetServerId, server.id);
  });

  test('多线路切换立即进入 checking，首条成功线路返回后再继续鉴权', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final currentProbe = Completer<ServerLineProbeResult>();
    final backupProbe = Completer<ServerLineProbeResult>();
    final started = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) {
              started.add(line.id);
              return line.id == 'target-current'
                  ? currentProbe.future
                  : backupProbe.future;
            },
          ),
        ),
        authControllerProvider.overrideWith(() => _FakeAuthController([], [])),
      ],
    );
    addTearDown(container.dispose);

    const currentLine = ServerLine(
      id: 'source-line',
      name: '当前服务器线路',
      baseUrl: 'https://source.example',
    );
    const targetCurrentLine = ServerLine(
      id: 'target-current',
      name: '目标主线路',
      baseUrl: 'https://target.example',
    );
    const targetBackupLine = ServerLine(
      id: 'target-backup',
      name: '目标备用线路',
      baseUrl: 'https://target-backup.example',
    );
    const source = ServerProfile(
      id: 'source-server',
      name: '当前服务器',
      lines: [currentLine],
      activeLineId: 'source-line',
      projectName: 'db_online',
    );
    const target = ServerProfile(
      id: 'target-server',
      name: '目标服务器',
      lines: [targetCurrentLine, targetBackupLine],
      activeLineId: 'target-current',
      projectName: 'db_online',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://source.example',
            lines: [currentLine],
            servers: [source, target],
            activeServerId: 'source-server',
          ),
        );

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final switching = transition.switchTo(target.id);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.checking,
    );
    expect(
      started,
      containsAll(<String>[targetCurrentLine.id, targetBackupLine.id]),
    );

    backupProbe.complete(
      const ServerLineProbeResult.success(
        targetBackupLine,
        18,
        versionInfo: ServerVersionInfo(
          projectName: 'db_online',
          version: '1.14.0',
        ),
      ),
    );
    await switching;

    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsLogin,
    );
    expect(
      container.read(serverConfigProvider)?.activeServer?.activeLine?.id,
      targetBackupLine.id,
    );
    currentProbe.complete(
      const ServerLineProbeResult.failure(targetCurrentLine, '连接超时'),
    );
  });

  test('切换开始同步断开旧连接，取消后迟到探测不能提交目标服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final targetProbe = Completer<ServerLineProbeResult>();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(probe: (_) => targetProbe.future),
        ),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            [],
            [],
            refreshResult: const AuthState(phase: AuthPhase.authenticated),
          ),
        ),
        dbOnlineRecommendProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestUpdatedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestReleasedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    const sourceLine = ServerLine(
      id: 'source-line',
      name: '当前服务器',
      baseUrl: 'https://source.example',
    );
    const targetLine = ServerLine(
      id: 'target-line',
      name: '目标服务器',
      baseUrl: 'https://target.example',
    );
    const source = ServerProfile(
      id: 'source-server',
      name: '当前服务器',
      lines: [sourceLine],
      activeLineId: 'source-line',
      projectName: 'db_online',
    );
    const target = ServerProfile(
      id: 'target-server',
      name: '目标服务器',
      lines: [targetLine],
      activeLineId: 'target-line',
      projectName: 'db_online',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://source.example',
            lines: [sourceLine],
            servers: [source, target],
            activeServerId: 'source-server',
          ),
        );

    final oldConnection = container.read(serverConnectionProvider);
    final oldLease = oldConnection.lease!;
    var cancelledSynchronously = false;
    oldLease.register(() => cancelledSynchronously = true);

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final switching = transition.switchTo(target.id);

    expect(cancelledSynchronously, isTrue);
    expect(oldLease.isActive, isFalse);
    expect(container.read(serverConnectionProvider).suspended, isTrue);
    expect(container.read(apiClientProvider), isNull);

    await transition.cancel();
    final restoredConnection = container.read(serverConnectionProvider);
    expect(container.read(serverConfigProvider)?.activeServerId, source.id);
    expect(restoredConnection.accepts(source.id), isTrue);
    expect(restoredConnection.lease, isNot(same(oldLease)));

    targetProbe.complete(
      const ServerLineProbeResult.success(
        targetLine,
        12,
        versionInfo: ServerVersionInfo(
          projectName: 'db_online',
          version: '1.14.0',
        ),
      ),
    );
    await switching;

    expect(container.read(serverConfigProvider)?.activeServerId, source.id);
    expect(container.read(serverConnectionProvider).accepts(source.id), isTrue);
  });

  test('DB Online 初始化点击当前服务器复用统一登录流程', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final probedLines = <String>[];
    final refreshCalls = <int>[];
    final loginCalls = <({String password, String? totpCode})>[];
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async {
              probedLines.add(line.id);
              return ServerLineProbeResult.success(
                line,
                10,
                versionInfo: const ServerVersionInfo(
                  projectName: 'db_online',
                  version: '1.14.0',
                ),
              );
            },
          ),
        ),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(refreshCalls, loginCalls),
        ),
        dbOnlineRecommendProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestUpdatedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestReleasedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    const line = ServerLine(
      id: 'db-line',
      name: 'DB Online 主线路',
      baseUrl: 'https://db.example',
    );
    final server = ServerProfile(
      id: 'db-server',
      name: 'DB Online',
      lines: const [line],
      activeLineId: line.id,
      projectName: 'db_online',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: line.baseUrl,
            lines: const [line],
            servers: [server],
            activeServerId: server.id,
          ),
        );

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    await transition.switchTo(server.id, allowActiveTarget: true);

    expect(probedLines, [line.id]);
    expect(refreshCalls, [1]);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsLogin,
    );

    await transition.login(password: 'password', totpCode: '123456');

    expect(loginCalls, [(password: 'password', totpCode: '123456')]);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.finishing,
    );
    transition.finishTransition();
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );
  });

  test('Stash 缺少 API Key 时进入专用切换阶段', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final refreshCalls = <int>[];
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => ServerLineProbeResult.success(
              line,
              10,
              versionInfo: const ServerVersionInfo(
                projectName: 'stash',
                version: '',
              ),
            ),
          ),
        ),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            refreshCalls,
            [],
            refreshResult: const AuthState(phase: AuthPhase.needsApiKey),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    const line = ServerLine(
      id: 'stash-line',
      name: 'Stash 主线路',
      baseUrl: 'https://stash.example',
    );
    final server = ServerProfile(
      id: 'stash-server',
      name: 'Stash',
      lines: const [line],
      activeLineId: line.id,
      projectName: 'stash',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: line.baseUrl,
            lines: const [line],
            servers: [server],
            activeServerId: server.id,
          ),
        );

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(server.id, allowActiveTarget: true);

    expect(refreshCalls, [1]);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsApiKey,
    );
  });

  test('取消切换返回服务器选择器，不恢复上一台未登录服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final refreshCalls = <int>[];
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
                version: '1.14.0',
              ),
            ),
          ),
        ),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(refreshCalls, []),
        ),
      ],
    );
    addTearDown(container.dispose);

    const firstLine = ServerLine(
      id: 'first-line',
      name: '第一台服务器',
      baseUrl: 'https://first.example',
    );
    const secondLine = ServerLine(
      id: 'second-line',
      name: '第二台服务器',
      baseUrl: 'https://second.example',
    );
    const firstServer = ServerProfile(
      id: 'first-server',
      name: '第一台服务器',
      lines: [firstLine],
      activeLineId: 'first-line',
      projectName: 'db_online',
    );
    const secondServer = ServerProfile(
      id: 'second-server',
      name: '第二台服务器',
      lines: [secondLine],
      activeLineId: 'second-line',
      projectName: 'db_online',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: firstLine.baseUrl,
            lines: const [firstLine],
            servers: const [firstServer, secondServer],
            activeServerId: firstServer.id,
          ),
        );

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    await transition.switchTo(
      secondServer.id,
      avatarOrigin: const Rect.fromLTRB(24, 120, 117, 213),
      returnToSelectionOnCancel: true,
    );
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsLogin,
    );

    await transition.cancel();

    expect(
      container.read(serverConfigProvider)?.activeServerId,
      secondServer.id,
    );
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.returning,
    );
    transition.finishReturnTransition();
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );
    expect(container.read(serverSelectionReadyProvider), isFalse);
    expect(refreshCalls, [1]);
  });

  test('释放运行态后仍可从持久化配置重新选择文件服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const firstLine = ServerLine(
      id: 'first-line',
      name: '第一台线路',
      baseUrl: 'smb://first.example/share',
    );
    const secondLine = ServerLine(
      id: 'second-line',
      name: '第二台线路',
      baseUrl: 'https://second.example/dav',
    );
    final firstServer = ServerProfile(
      id: 'first-server',
      name: '第一台服务器',
      lines: const [firstLine],
      activeLineId: firstLine.id,
      projectName: 'smb',
    );
    final secondServer = ServerProfile(
      id: 'second-server',
      name: '第二台服务器',
      lines: const [secondLine],
      activeLineId: secondLine.id,
      projectName: 'webdav',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: firstLine.baseUrl,
            lines: const [firstLine],
            servers: [firstServer, secondServer],
            activeServerId: firstServer.id,
          ),
        );

    container.read(serverConfigProvider.notifier).showServerSelection();
    expect(container.read(serverConfigProvider), isNull);

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(
          secondServer.id,
          allowActiveTarget: true,
          returnToSelectionOnCancel: true,
        );

    expect(
      container.read(serverConfigProvider)?.activeServerId,
      secondServer.id,
    );
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );
  });

  test('登录后取消切换仍恢复原服务器', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final refreshCalls = <int>[];
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
                version: '1.14.0',
              ),
            ),
          ),
        ),
        authControllerProvider.overrideWith(
          () => _RestoringAuthController(refreshCalls),
        ),
        dbOnlineRecommendProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestUpdatedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestReleasedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    const firstLine = ServerLine(
      id: 'first-line',
      name: '第一台服务器',
      baseUrl: 'https://first.example',
    );
    const secondLine = ServerLine(
      id: 'second-line',
      name: '第二台服务器',
      baseUrl: 'https://second.example',
    );
    final firstServer = ServerProfile(
      id: 'first-server',
      name: '第一台服务器',
      lines: const [firstLine],
      activeLineId: firstLine.id,
      projectName: 'db_online',
    );
    final secondServer = ServerProfile(
      id: 'second-server',
      name: '第二台服务器',
      lines: const [secondLine],
      activeLineId: secondLine.id,
      projectName: 'db_online',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: firstLine.baseUrl,
            lines: const [firstLine],
            servers: [firstServer, secondServer],
            activeServerId: firstServer.id,
          ),
        );

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    await transition.switchTo(secondServer.id);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsLogin,
    );

    await transition.cancel();

    expect(
      container.read(serverConfigProvider)?.activeServerId,
      firstServer.id,
    );
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.finishing,
    );
    transition.finishTransition();
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );
    expect(refreshCalls, [1, 1]);
  });

  test('快速 A 到 B 到 C 时迟到的 B 结果不能覆盖 C', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bProbe = Completer<ServerLineProbeResult>();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) {
              if (line.id == 'b-line') return bProbe.future;
              return Future.value(
                ServerLineProbeResult.success(
                  line,
                  8,
                  versionInfo: const ServerVersionInfo(
                    projectName: 'db_online',
                    version: '1.14.0',
                  ),
                ),
              );
            },
          ),
        ),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            [],
            [],
            refreshResult: const AuthState(phase: AuthPhase.authenticated),
          ),
        ),
        dbOnlineRecommendProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestUpdatedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
        dbOnlineLatestReleasedProvider.overrideWith(
          (ref) async => const <DbOnlineMovie>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    const aLine = ServerLine(
      id: 'a-line',
      name: 'A',
      baseUrl: 'https://a.example',
    );
    const bLine = ServerLine(
      id: 'b-line',
      name: 'B',
      baseUrl: 'https://b.example',
    );
    const cLine = ServerLine(
      id: 'c-line',
      name: 'C',
      baseUrl: 'https://c.example',
    );
    const servers = [
      ServerProfile(
        id: 'a-server',
        name: 'A',
        lines: [aLine],
        activeLineId: 'a-line',
        projectName: 'db_online',
      ),
      ServerProfile(
        id: 'b-server',
        name: 'B',
        lines: [bLine],
        activeLineId: 'b-line',
        projectName: 'db_online',
      ),
      ServerProfile(
        id: 'c-server',
        name: 'C',
        lines: [cLine],
        activeLineId: 'c-line',
        projectName: 'db_online',
      ),
    ];
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://a.example',
            lines: [aLine],
            servers: servers,
            activeServerId: 'a-server',
          ),
        );

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final bSwitch = transition.switchTo('b-server');
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(serverSwitchTransitionProvider).targetServerId,
      'b-server',
    );

    await transition.switchTo('c-server');
    expect(container.read(serverConfigProvider)?.activeServerId, 'c-server');
    expect(container.read(serverConnectionProvider).serverId, 'c-server');

    bProbe.complete(
      const ServerLineProbeResult.success(
        bLine,
        50,
        versionInfo: ServerVersionInfo(
          projectName: 'db_online',
          version: '1.14.0',
        ),
      ),
    );
    await bSwitch;

    expect(container.read(serverConfigProvider)?.activeServerId, 'c-server');
    expect(container.read(serverConnectionProvider).serverId, 'c-server');
  });

  test('B 已提交但鉴权未完成时切换 C，C 失败仍恢复最初的 A', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authStarted = Completer<void>();
    final authResult = Completer<AuthState>();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => line.id == 'c-line'
                ? ServerLineProbeResult.failure(line, 'C 不可用')
                : ServerLineProbeResult.success(
                    line,
                    8,
                    versionInfo: const ServerVersionInfo(
                      projectName: 'db_online',
                      version: '1.14.0',
                    ),
                  ),
          ),
        ),
        authControllerProvider.overrideWith(
          () => _BlockingAuthController(authStarted, authResult),
        ),
      ],
    );
    addTearDown(container.dispose);

    const aLine = ServerLine(
      id: 'a-line',
      name: 'A',
      baseUrl: 'https://a.example',
    );
    const bLine = ServerLine(
      id: 'b-line',
      name: 'B',
      baseUrl: 'https://b.example',
    );
    const cLine = ServerLine(
      id: 'c-line',
      name: 'C',
      baseUrl: 'https://c.example',
    );
    const servers = [
      ServerProfile(
        id: 'a-server',
        name: 'A',
        lines: [aLine],
        activeLineId: 'a-line',
        projectName: 'db_online',
      ),
      ServerProfile(
        id: 'b-server',
        name: 'B',
        lines: [bLine],
        activeLineId: 'b-line',
        projectName: 'db_online',
      ),
      ServerProfile(
        id: 'c-server',
        name: 'C',
        lines: [cLine],
        activeLineId: 'c-line',
        projectName: 'db_online',
      ),
    ];
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://a.example',
            lines: [aLine],
            servers: servers,
            activeServerId: 'a-server',
          ),
        );

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final bSwitch = transition.switchTo('b-server');
    await authStarted.future;
    expect(container.read(serverConfigProvider)?.activeServerId, 'b-server');

    await transition.switchTo('c-server');

    expect(container.read(serverConfigProvider)?.activeServerId, 'a-server');
    expect(container.read(serverConnectionProvider).serverId, 'a-server');
    authResult.complete(const AuthState(phase: AuthPhase.authenticated));
    await bSwitch;
    expect(container.read(serverConfigProvider)?.activeServerId, 'a-server');
  });

  test('目标探测失败后自动恢复原服务器并创建新连接代际', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async =>
                ServerLineProbeResult.failure(line, '目标服务器不可用'),
          ),
        ),
        authControllerProvider.overrideWith(() => _FakeAuthController([], [])),
      ],
    );
    addTearDown(container.dispose);

    const aLine = ServerLine(
      id: 'a-line',
      name: 'A',
      baseUrl: 'https://a.example',
    );
    const bLine = ServerLine(
      id: 'b-line',
      name: 'B',
      baseUrl: 'https://b.example',
    );
    const aServer = ServerProfile(
      id: 'a-server',
      name: 'A',
      lines: [aLine],
      activeLineId: 'a-line',
      projectName: 'db_online',
    );
    const bServer = ServerProfile(
      id: 'b-server',
      name: 'B',
      lines: [bLine],
      activeLineId: 'b-line',
      projectName: 'db_online',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://a.example',
            lines: [aLine],
            servers: [aServer, bServer],
            activeServerId: 'a-server',
          ),
        );
    final initialLease = container.read(serverConnectionProvider).lease;

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo('b-server');

    final restored = container.read(serverConnectionProvider);
    expect(container.read(serverConfigProvider)?.activeServerId, 'a-server');
    expect(restored.accepts('a-server'), isTrue);
    expect(restored.lease, isNot(same(initialLease)));
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.error,
    );
  });
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(
    this.refreshCalls,
    this.loginCalls, {
    this.refreshResult = const AuthState(phase: AuthPhase.needsLogin),
  });

  final List<int> refreshCalls;
  final List<({String password, String? totpCode})> loginCalls;
  final AuthState refreshResult;

  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.needsLogin);

  @override
  Future<AuthState> refreshCurrentServer() async {
    refreshCalls.add(1);
    return refreshResult;
  }

  @override
  Future<bool> login({
    String? username,
    required String password,
    String? totpCode,
    String? apiKey,
  }) async {
    loginCalls.add((password: password, totpCode: totpCode));
    return true;
  }
}

class _RecoveryRequiredAuthController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState(
    phase: AuthPhase.needsLogin,
    requiresCredentialInput: true,
  );
}

class _BlockingAuthController extends AuthController {
  _BlockingAuthController(this.started, this.result);

  final Completer<void> started;
  final Completer<AuthState> result;

  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.needsLogin);

  @override
  Future<AuthState> refreshCurrentServer() {
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _SwitchTestServerConfigNotifier extends ServerConfigNotifier {
  _SwitchTestServerConfigNotifier(this.config);

  final ServerConfig config;

  @override
  ServerConfig build() => config;
}

class _RestoringAuthController extends AuthController {
  _RestoringAuthController(this.refreshCalls);

  final List<int> refreshCalls;

  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.needsLogin);

  @override
  Future<AuthState> refreshCurrentServer() async {
    refreshCalls.add(1);
    return AuthState(
      phase: refreshCalls.length == 1
          ? AuthPhase.needsLogin
          : AuthPhase.authenticated,
    );
  }
}
