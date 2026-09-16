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
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/core/sources/files/file_source_providers.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/home/home_providers.dart';
import 'package:omm/features/home/server_switch_transition.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';
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

    _activateRuntimeLane(container, ServerRuntimeLane.media, server.id);
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
    _activateRuntimeLane(container, ServerRuntimeLane.media, source.id);

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final switching = transition.switchTo(target.id);
    await Future<void>.value();
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

  test('切换开始停止任务后断开旧连接，取消后迟到探测不能提交目标服务器', () async {
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
    _activateRuntimeLane(container, ServerRuntimeLane.media, source.id);

    final oldConnection = container.read(serverConnectionProvider);
    final oldLease = oldConnection.lease!;
    var cancelledSynchronously = false;
    oldLease.register(() => cancelledSynchronously = true);

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final switching = transition.switchTo(target.id);
    await Future<void>.value();

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

  test('OMM 冷启动首次刷新在媒体槽 ready 后启动', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const line = ServerLine(
      id: 'omm-line',
      name: 'OMM 主线路',
      baseUrl: 'https://omm.example',
    );
    const server = ServerProfile(
      id: 'omm-server',
      name: 'OMM',
      lines: [line],
      activeLineId: 'omm-line',
      projectName: 'oh-my-media',
    );
    final observedPhases = <ServerRuntimePhase>[];
    final observedConnections = <bool>[];

    Never recordRefresh(Ref ref) {
      observedPhases.add(ref.read(serverRuntimeProvider).media.phase);
      observedConnections.add(
        ref.read(mediaServerConnectionProvider).accepts(server.id),
      );
      throw StateError('测试刷新已记录');
    }

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
                version: '2.4.0',
              ),
            ),
          ),
        ),
        authControllerProvider.overrideWith(
          _AlwaysAuthenticatedAuthController.new,
        ),
        recentlyAddedProvider.overrideWith(recordRefresh),
        continueWatchingProvider.overrideWith(recordRefresh),
        librariesProvider.overrideWith(recordRefresh),
        recommendCarouselProvider.overrideWith(recordRefresh),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://omm.example',
            lines: [line],
            servers: [server],
            activeServerId: 'omm-server',
          ),
        );

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(server.id, allowActiveTarget: true);
    await Future<void>.delayed(Duration.zero);

    expect(observedPhases, hasLength(4));
    expect(observedPhases, everyElement(ServerRuntimePhase.ready));
    expect(observedConnections, everyElement(isTrue));
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.finishing,
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
    _activateRuntimeLane(container, ServerRuntimeLane.media, firstServer.id);

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

  test('B 已进入目标槽但鉴权未完成时切换 C，C 失败恢复 B', () async {
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
    _activateRuntimeLane(container, ServerRuntimeLane.media, 'a-server');

    final transition = container.read(serverSwitchTransitionProvider.notifier);
    final bSwitch = transition.switchTo('b-server');
    await authStarted.future;
    expect(container.read(serverConfigProvider)?.activeServerId, 'b-server');

    await transition.switchTo('c-server');

    expect(container.read(serverConfigProvider)?.activeServerId, 'b-server');
    expect(container.read(serverConnectionProvider).serverId, 'b-server');
    authResult.complete(const AuthState(phase: AuthPhase.authenticated));
    await bSwitch;
    expect(container.read(serverConfigProvider)?.activeServerId, 'b-server');
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
    _activateRuntimeLane(container, ServerRuntimeLane.media, aServer.id);
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

  test('媒体与文件槽已就绪时，跨槽往返复用原 lease 与 generation', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith(
          _AlwaysAuthenticatedAuthController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    const mediaLine = ServerLine(
      id: 'media-line',
      name: '媒体线路',
      baseUrl: 'https://media.example',
    );
    const fileLine = ServerLine(
      id: 'file-line',
      name: '文件线路',
      baseUrl: 'https://files.example/dav',
    );
    const mediaServer = ServerProfile(
      id: 'media-server',
      name: '媒体服务器',
      lines: [mediaLine],
      activeLineId: 'media-line',
      projectName: 'db_online',
    );
    const fileServer = ServerProfile(
      id: 'file-server',
      name: '文件服务器',
      lines: [fileLine],
      activeLineId: 'file-line',
      projectName: 'webdav',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: mediaLine.baseUrl,
            lines: const [mediaLine],
            servers: const [mediaServer, fileServer],
            activeServerId: mediaServer.id,
          ),
        );
    _activateRuntimeLane(container, ServerRuntimeLane.media, mediaServer.id);
    _activateRuntimeLane(container, ServerRuntimeLane.files, fileServer.id);
    container
        .read(serverRuntimeProvider.notifier)
        .showLane(ServerRuntimeLane.media);
    await container.read(authControllerProvider.future);

    final mediaBefore = container.read(mediaServerConnectionProvider);
    final filesBefore = container.read(fileServerConnectionProvider);
    final transition = container.read(serverSwitchTransitionProvider.notifier);

    await transition.switchTo(fileServer.id);
    expect(
      container.read(serverRuntimeProvider).visibleLane,
      ServerRuntimeLane.files,
    );
    expect(
      container.read(mediaServerConnectionProvider).lease,
      same(mediaBefore.lease),
    );
    expect(
      container.read(fileServerConnectionProvider).lease,
      same(filesBefore.lease),
    );

    await container.read(authControllerProvider.future);
    await transition.switchTo(mediaServer.id);
    expect(
      container.read(serverRuntimeProvider).visibleLane,
      ServerRuntimeLane.media,
    );
    final mediaAfter = container.read(mediaServerConnectionProvider);
    final filesAfter = container.read(fileServerConnectionProvider);
    expect(mediaAfter.lease, same(mediaBefore.lease));
    expect(mediaAfter.generation, mediaBefore.generation);
    expect(filesAfter.lease, same(filesBefore.lease));
    expect(filesAfter.generation, filesBefore.generation);
  });

  test('媒体同槽换实例只替换媒体 lease，文件槽保持不变', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        serverLineProbeCoordinatorProvider.overrideWithValue(
          ServerLineProbeCoordinator(
            probe: (line) async => ServerLineProbeResult.success(
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
          _AlwaysAuthenticatedAuthController.new,
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

    const mediaOneLine = ServerLine(
      id: 'media-one-line',
      name: '媒体一',
      baseUrl: 'https://media-one.example',
    );
    const mediaTwoLine = ServerLine(
      id: 'media-two-line',
      name: '媒体二',
      baseUrl: 'https://media-two.example',
    );
    const fileLine = ServerLine(
      id: 'file-line',
      name: '文件',
      baseUrl: 'https://files.example/dav',
    );
    const mediaOne = ServerProfile(
      id: 'media-one',
      name: '媒体一',
      lines: [mediaOneLine],
      activeLineId: 'media-one-line',
      projectName: 'db_online',
    );
    const mediaTwo = ServerProfile(
      id: 'media-two',
      name: '媒体二',
      lines: [mediaTwoLine],
      activeLineId: 'media-two-line',
      projectName: 'db_online',
    );
    const fileServer = ServerProfile(
      id: 'file-server',
      name: '文件服务器',
      lines: [fileLine],
      activeLineId: 'file-line',
      projectName: 'webdav',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: mediaOneLine.baseUrl,
            lines: const [mediaOneLine],
            servers: const [mediaOne, mediaTwo, fileServer],
            activeServerId: mediaOne.id,
          ),
        );
    _activateRuntimeLane(container, ServerRuntimeLane.media, mediaOne.id);
    _activateRuntimeLane(container, ServerRuntimeLane.files, fileServer.id);
    container
        .read(serverRuntimeProvider.notifier)
        .showLane(ServerRuntimeLane.media);

    final mediaBefore = container.read(mediaServerConnectionProvider);
    final filesBefore = container.read(fileServerConnectionProvider);
    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(mediaTwo.id);

    final mediaAfter = container.read(mediaServerConnectionProvider);
    final filesAfter = container.read(fileServerConnectionProvider);
    expect(mediaBefore.lease?.isActive, isFalse);
    expect(mediaAfter.accepts(mediaTwo.id), isTrue);
    expect(mediaAfter.lease, isNot(same(mediaBefore.lease)));
    expect(mediaAfter.generation, greaterThan(mediaBefore.generation));
    expect(filesAfter.lease, same(filesBefore.lease));
    expect(filesAfter.generation, filesBefore.generation);
    expect(filesAfter.accepts(fileServer.id), isTrue);
    expect(
      container.read(serverRuntimeProvider).media.phase,
      ServerRuntimePhase.ready,
    );
  });

  test('媒体切换失败只回滚媒体槽，可见文件槽与 lease 不变', () async {
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
        authControllerProvider.overrideWith(
          _AlwaysAuthenticatedAuthController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    const mediaOneLine = ServerLine(
      id: 'media-one-line',
      name: '媒体一',
      baseUrl: 'https://media-one.example',
    );
    const mediaTwoLine = ServerLine(
      id: 'media-two-line',
      name: '媒体二',
      baseUrl: 'https://media-two.example',
    );
    const fileLine = ServerLine(
      id: 'file-line',
      name: '文件',
      baseUrl: 'https://files.example/dav',
    );
    const mediaOne = ServerProfile(
      id: 'media-one',
      name: '媒体一',
      lines: [mediaOneLine],
      activeLineId: 'media-one-line',
      projectName: 'db_online',
    );
    const mediaTwo = ServerProfile(
      id: 'media-two',
      name: '媒体二',
      lines: [mediaTwoLine],
      activeLineId: 'media-two-line',
      projectName: 'db_online',
    );
    const fileServer = ServerProfile(
      id: 'file-server',
      name: '文件服务器',
      lines: [fileLine],
      activeLineId: 'file-line',
      projectName: 'webdav',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          ServerConfig(
            baseUrl: fileLine.baseUrl,
            lines: const [fileLine],
            servers: const [mediaOne, mediaTwo, fileServer],
            activeServerId: fileServer.id,
          ),
        );
    _activateRuntimeLane(container, ServerRuntimeLane.media, mediaOne.id);
    _activateRuntimeLane(container, ServerRuntimeLane.files, fileServer.id);
    final mediaBefore = container.read(mediaServerConnectionProvider);
    final filesBefore = container.read(fileServerConnectionProvider);

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(mediaTwo.id);

    final runtime = container.read(serverRuntimeProvider);
    final mediaAfter = container.read(mediaServerConnectionProvider);
    final filesAfter = container.read(fileServerConnectionProvider);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.error,
    );
    expect(runtime.media.serverId, mediaOne.id);
    expect(runtime.media.phase, ServerRuntimePhase.ready);
    expect(runtime.visibleLane, ServerRuntimeLane.files);
    expect(mediaBefore.lease?.isActive, isFalse);
    expect(mediaAfter.accepts(mediaOne.id), isTrue);
    expect(mediaAfter.lease, isNot(same(mediaBefore.lease)));
    expect(filesAfter.lease, same(filesBefore.lease));
    expect(filesAfter.generation, filesBefore.generation);
    expect(filesAfter.accepts(fileServer.id), isTrue);
  });

  test('文件槽可见时取消首次媒体登录只清理媒体槽', () async {
    final setup = await _crossLaneSetup(
      const AuthState(phase: AuthPhase.needsLogin),
    );
    addTearDown(setup.container.dispose);

    await setup.container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(setup.mediaServer.id);

    expect(
      setup.container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.needsLogin,
    );
    expect(
      setup.container.read(serverRuntimeProvider).visibleLane,
      ServerRuntimeLane.files,
    );
    final fileBefore = setup.container.read(fileServerConnectionProvider);

    await setup.container
        .read(serverSwitchTransitionProvider.notifier)
        .cancel();

    final runtime = setup.container.read(serverRuntimeProvider);
    final fileAfter = setup.container.read(fileServerConnectionProvider);
    expect(
      setup.container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.idle,
    );
    expect(runtime.media.serverId, isNull);
    expect(runtime.files.serverId, setup.fileServer.id);
    expect(runtime.visibleLane, ServerRuntimeLane.files);
    expect(
      setup.container.read(mediaServerConnectionProvider).suspended,
      isTrue,
    );
    expect(fileAfter.lease, same(fileBefore.lease));
    expect(fileAfter.accepts(setup.fileServer.id), isTrue);
    expect(
      setup.container.read(serverConfigProvider)?.activeServerId,
      setup.fileServer.id,
    );
  });

  test('媒体鉴权硬失败自动回滚且保持文件槽可见', () async {
    final setup = await _crossLaneSetup(
      const AuthState(phase: AuthPhase.unavailable, message: '连接失败'),
    );
    addTearDown(setup.container.dispose);
    final fileBefore = setup.container.read(fileServerConnectionProvider);

    await setup.container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(setup.mediaServer.id);

    final runtime = setup.container.read(serverRuntimeProvider);
    final fileAfter = setup.container.read(fileServerConnectionProvider);
    expect(
      setup.container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.error,
    );
    expect(runtime.media.serverId, isNull);
    expect(runtime.files.serverId, setup.fileServer.id);
    expect(runtime.visibleLane, ServerRuntimeLane.files);
    expect(
      setup.container.read(mediaServerConnectionProvider).suspended,
      isTrue,
    );
    expect(fileAfter.lease, same(fileBefore.lease));
    expect(fileAfter.accepts(setup.fileServer.id), isTrue);
    expect(
      setup.container.read(serverConfigProvider)?.activeServerId,
      setup.fileServer.id,
    );
  });

  test('文件同槽切换注册失败会恢复旧文件实例并保持媒体可见', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        fileSourceRegistryProvider.overrideWith(
          (ref) async => throw StateError('文件来源连接失败'),
        ),
      ],
    );
    addTearDown(container.dispose);
    const mediaLine = ServerLine(
      id: 'media-line',
      name: '媒体',
      baseUrl: 'https://media.example',
    );
    const fileOneLine = ServerLine(
      id: 'file-one-line',
      name: '文件一',
      baseUrl: 'https://files-one.example/dav',
    );
    const fileTwoLine = ServerLine(
      id: 'file-two-line',
      name: '文件二',
      baseUrl: 'https://files-two.example/dav',
    );
    const mediaServer = ServerProfile(
      id: 'media-server',
      name: '媒体服务器',
      lines: [mediaLine],
      activeLineId: 'media-line',
      projectName: 'db_online',
    );
    const fileOne = ServerProfile(
      id: 'file-one',
      name: '文件一',
      lines: [fileOneLine],
      activeLineId: 'file-one-line',
      projectName: 'webdav',
    );
    const fileTwo = ServerProfile(
      id: 'file-two',
      name: '文件二',
      lines: [fileTwoLine],
      activeLineId: 'file-two-line',
      projectName: 'webdav',
    );
    await container
        .read(serverConfigProvider.notifier)
        .save(
          const ServerConfig(
            baseUrl: 'https://media.example',
            lines: [mediaLine],
            servers: [mediaServer, fileOne, fileTwo],
            activeServerId: 'media-server',
          ),
        );
    _activateRuntimeLane(container, ServerRuntimeLane.media, mediaServer.id);
    _activateRuntimeLane(container, ServerRuntimeLane.files, fileOne.id);
    container
        .read(serverRuntimeProvider.notifier)
        .showLane(ServerRuntimeLane.media);
    final mediaBefore = container.read(mediaServerConnectionProvider);
    final fileBefore = container.read(fileServerConnectionProvider);

    await container
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(fileTwo.id);

    final runtime = container.read(serverRuntimeProvider);
    final mediaAfter = container.read(mediaServerConnectionProvider);
    final fileAfter = container.read(fileServerConnectionProvider);
    expect(
      container.read(serverSwitchTransitionProvider).phase,
      ServerSwitchPhase.error,
    );
    expect(runtime.files.serverId, fileOne.id);
    expect(runtime.files.phase, ServerRuntimePhase.ready);
    expect(runtime.visibleLane, ServerRuntimeLane.media);
    expect(mediaAfter.lease, same(mediaBefore.lease));
    expect(mediaAfter.accepts(mediaServer.id), isTrue);
    expect(fileBefore.lease?.isActive, isFalse);
    expect(fileAfter.lease, isNot(same(fileBefore.lease)));
    expect(fileAfter.accepts(fileOne.id), isTrue);
  });
}

Future<
  ({
    ProviderContainer container,
    ServerProfile mediaServer,
    ServerProfile fileServer,
  })
>
_crossLaneSetup(AuthState refreshResult) async {
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
              version: '1.14.0',
            ),
          ),
        ),
      ),
      authControllerProvider.overrideWith(
        () => _FakeAuthController([], [], refreshResult: refreshResult),
      ),
    ],
  );
  const mediaLine = ServerLine(
    id: 'media-line',
    name: '媒体',
    baseUrl: 'https://media.example',
  );
  const fileLine = ServerLine(
    id: 'file-line',
    name: '文件',
    baseUrl: 'https://files.example/dav',
  );
  const mediaServer = ServerProfile(
    id: 'media-server',
    name: '媒体服务器',
    lines: [mediaLine],
    activeLineId: 'media-line',
    projectName: 'db_online',
  );
  const fileServer = ServerProfile(
    id: 'file-server',
    name: '文件服务器',
    lines: [fileLine],
    activeLineId: 'file-line',
    projectName: 'webdav',
  );
  await container
      .read(serverConfigProvider.notifier)
      .save(
        const ServerConfig(
          baseUrl: 'https://files.example/dav',
          lines: [fileLine],
          servers: [mediaServer, fileServer],
          activeServerId: 'file-server',
        ),
      );
  _activateRuntimeLane(container, ServerRuntimeLane.files, fileServer.id);
  return (
    container: container,
    mediaServer: mediaServer,
    fileServer: fileServer,
  );
}

void _activateRuntimeLane(
  ProviderContainer container,
  ServerRuntimeLane lane,
  String serverId,
) {
  final runtime = container.read(serverRuntimeProvider.notifier);
  runtime.beginSwitch(lane, serverId);
  switch (lane) {
    case ServerRuntimeLane.media:
      container.read(mediaServerConnectionProvider.notifier).activate(serverId);
    case ServerRuntimeLane.files:
      container.read(fileServerConnectionProvider.notifier).activate(serverId);
  }
  runtime.commit(lane, serverId);
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

class _AlwaysAuthenticatedAuthController extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.authenticated);

  @override
  Future<AuthState> refreshCurrentServer() async =>
      const AuthState(phase: AuthPhase.authenticated);
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
