import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
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
  }) async {
    loginCalls.add((password: password, totpCode: totpCode));
    return true;
  }
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
