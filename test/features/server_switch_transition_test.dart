import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_line_probe.dart';
import 'package:omm/core/models/db_online_movie.dart';
import 'package:omm/features/db_online/db_online_home_providers.dart';
import 'package:omm/features/home/server_switch_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
                  version: '1.13.0',
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
      ServerSwitchPhase.idle,
    );
  });
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.refreshCalls, this.loginCalls);

  final List<int> refreshCalls;
  final List<({String password, String? totpCode})> loginCalls;

  @override
  Future<AuthState> build() async =>
      const AuthState(phase: AuthPhase.needsLogin);

  @override
  Future<AuthState> refreshCurrentServer() async {
    refreshCalls.add(1);
    return const AuthState(phase: AuthPhase.needsLogin);
  }

  @override
  Future<bool> login({required String password, String? totpCode}) async {
    loginCalls.add((password: password, totpCode: totpCode));
    return true;
  }
}
