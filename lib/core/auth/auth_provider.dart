import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/dio_factory.dart';
import '../api/providers.dart';
import '../api/server_compatibility.dart';
import '../config/server_config.dart';
import '../config/server_config_provider.dart';
import '../config/server_line_probe.dart';
import 'auth_session.dart';
import 'auth_session_provider.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final config = ref.watch(serverConfigProvider);
    ref.watch(authExpiryProvider);
    if (config == null) {
      return const AuthState(phase: AuthPhase.unconfigured);
    }

    ref
        .read(authSessionRepositoryProvider)
        .setActiveServerId(config.activeServerId);

    final serverSelectionReady = ref.watch(serverSelectionReadyProvider);
    if (config.hasMultipleServers && !serverSelectionReady) {
      return const AuthState(phase: AuthPhase.serverSelection);
    }

    // 用户刚刚明确选择服务器时，当前线路已经是用户选择的目标，不再重复
    // 探测所有线路；这样初始化和首页切换都可以立即检查鉴权状态。
    var selectedConfig = config;
    ServerLineProbeResult? selectedProbe;
    if (!serverSelectionReady) {
      final candidates = config.lines.where((line) => line.enabled).toList();
      final current = candidates.firstWhere(
        (line) => line.baseUrl == config.baseUrl,
        orElse: () => candidates.isEmpty
            ? ServerLine(id: 'active', name: '当前线路', baseUrl: config.baseUrl)
            : candidates.first,
      );
      final alternatives = candidates.where((line) => line.id != current.id);
      final activeProject = config.activeServer?.projectName;
      final selection = await ServerLineProbeCoordinator().selectPreferred(
        current: current,
        alternatives: alternatives,
        expectedProjectName: activeProject,
      );
      final selected = selection.selected;
      if (selected == null) {
        final incompatible = selection.results.any(
          (result) => result.incompatible,
        );
        final detail = selection.results
            .map((result) => '${result.line.name}：${result.message}')
            .where((message) => message.trim().isNotEmpty)
            .join('\n');
        return AuthState(
          phase: incompatible ? AuthPhase.incompatible : AuthPhase.unavailable,
          message: detail.isEmpty ? '没有可用的服务器线路' : detail,
        );
      }
      selectedConfig = _withSelectedLine(config, selected);
      selectedProbe = selected;
    }

    if (selectedConfig != config) {
      // 线路探测是异步的，期间用户可能已经在初始化页新增服务器。
      // 这里只回写当前服务器的线路结果，不能用探测开始时的旧完整配置
      // 覆盖后来追加的服务器。
      final selectedServer = selectedConfig.activeServer;
      final latestConfig = ref.read(serverConfigProvider);
      if (selectedServer != null &&
          latestConfig?.activeServer == config.activeServer) {
        await ref
            .read(serverConfigProvider.notifier)
            .saveServer(selectedServer, validatedProbe: selectedProbe);
      }
    }
    final client = ApiClient.fromConfig(
      selectedConfig,
      sessionRepository: ref.read(authSessionRepositoryProvider),
      onSessionExpired: () => ref.read(authExpiryProvider.notifier).state++,
    );
    return _bootstrap(client);
  }

  Future<AuthState> _bootstrap(ApiClient client) async {
    final isDbOnline =
        client.config?.activeServer?.project == ServerProject.dbOnline;
    AuthStatus status;
    try {
      status = await client.auth.status();
    } catch (error) {
      final exception = toApiException(error);
      if (isDbOnline && exception.status == 401) {
        await ref.read(authSessionRepositoryProvider).clear();
        return AuthState(
          phase: AuthPhase.needsLogin,
          message: exception.message,
        );
      }
      if (!isDbOnline && exception.status == 401 && await _refresh(client)) {
        try {
          status = await client.auth.status();
        } catch (retryError) {
          final retryException = toApiException(retryError);
          return AuthState(
            phase: retryException.status == 401 || retryException.status == 404
                ? AuthPhase.incompatible
                : AuthPhase.unavailable,
            message: retryException.message,
          );
        }
      } else {
        return AuthState(
          phase: exception.status == 401 || exception.status == 404
              ? AuthPhase.incompatible
              : AuthPhase.unavailable,
          message: exception.message,
        );
      }
    }

    if (!status.enabled || !status.configured) {
      // 鉴权关闭或尚未配置时清除历史会话，避免任务 WebSocket 继续携带旧 token。
      // Keychain/安全存储清理不应阻塞未配置鉴权服务器的切换流程。
      unawaited(
        ref.read(authSessionRepositoryProvider).clear().catchError((_) {}),
      );
      return AuthState(phase: AuthPhase.authenticated, status: status);
    }
    if (isDbOnline) {
      final session = await ref.read(authSessionRepositoryProvider).load();
      if (session == null || !session.hasAccessToken) {
        return AuthState(phase: AuthPhase.needsLogin, status: status);
      }
      try {
        final valid = await client.auth.verify();
        if (valid) {
          return AuthState(phase: AuthPhase.authenticated, status: status);
        }
      } catch (error) {
        final exception = toApiException(error);
        if (exception.status != 401) {
          return AuthState(
            phase: AuthPhase.unavailable,
            status: status,
            message: exception.message,
          );
        }
      }
      await ref.read(authSessionRepositoryProvider).clear();
      return AuthState(phase: AuthPhase.needsLogin, status: status);
    }
    if (status.authenticated) {
      final session = await ref.read(authSessionRepositoryProvider).load();
      if (session?.isUsable == true) {
        return AuthState(phase: AuthPhase.authenticated, status: status);
      }
      // Oh-My-Media 会话必须同时具备 access/refresh 两个令牌；旧版或
      // 异常迁移留下的 token-only 会话不能绕过登录页。
      await ref.read(authSessionRepositoryProvider).clear();
      return AuthState(phase: AuthPhase.needsLogin, status: status);
    }

    final session = await ref.read(authSessionRepositoryProvider).load();
    if (session != null && await _refresh(client)) {
      try {
        final refreshed = await client.auth.status();
        if (!refreshed.enabled ||
            !refreshed.configured ||
            refreshed.authenticated) {
          return AuthState(phase: AuthPhase.authenticated, status: refreshed);
        }
        status = refreshed;
      } catch (_) {
        // 刷新成功但状态检查失败时，仍按登录页处理，避免绕过鉴权。
      }
    }

    return AuthState(phase: AuthPhase.needsLogin, status: status);
  }

  /// 在服务器切换后直接检查当前配置对应的服务器。
  ///
  /// 切换服务器会让本 Provider 同时触发一次自动重建。切换界面不能再
  /// 等待那次旧的异步构建，否则目标服务器未启用鉴权时也可能一直停留在
  /// “检查服务器鉴权状态”。直接复用当前客户端的 bootstrap 流程，完成后
  /// 同步 Provider 状态，避免重复的线路探测和旧 Future 竞争。
  Future<AuthState> refreshCurrentServer() async {
    final config = ref.read(serverConfigProvider);
    if (config == null) {
      const result = AuthState(phase: AuthPhase.unconfigured);
      state = const AsyncData(result);
      return result;
    }

    ref
        .read(authSessionRepositoryProvider)
        .setActiveServerId(config.activeServerId);
    if (config.hasMultipleServers && !ref.read(serverSelectionReadyProvider)) {
      const result = AuthState(phase: AuthPhase.serverSelection);
      state = const AsyncData(result);
      return result;
    }

    // 检查期间保留既有状态，不置为裸 AsyncLoading：根路由的 loading 分支
    // 会替换整个登录选择页，导致内联登录表单丢失。调用方各自展示 busy。
    final client = ApiClient.fromConfig(
      config,
      sessionRepository: ref.read(authSessionRepositoryProvider),
      onSessionExpired: () => ref.read(authExpiryProvider.notifier).state++,
    );
    final result = await _bootstrap(client);
    state = AsyncData(result);
    return result;
  }

  Future<bool> login({required String password, String? totpCode}) async {
    final client = ref.read(requiredApiClientProvider);
    final isDbOnline =
        client.config?.activeServer?.project == ServerProject.dbOnline;
    final current = state.valueOrNull;
    // 登录请求期间保留 needsLogin 状态（页面有自己的 busy 指示），避免根
    // 路由进入 loading 分支重建登录页。
    try {
      final session = await client.auth.login(
        password: password,
        totpCode: totpCode,
      );
      if (isDbOnline ? !session.hasAccessToken : !session.isUsable) {
        throw ApiException('登录响应缺少有效会话');
      }
      await ref.read(authSessionRepositoryProvider).save(session);
      if (isDbOnline) {
        try {
          if (!await client.auth.verify()) {
            throw ApiException('登录响应令牌无效');
          }
        } catch (_) {
          await ref.read(authSessionRepositoryProvider).clear();
          rethrow;
        }
      }
      final status = await client.auth.status();
      state = AsyncData(
        AuthState(phase: AuthPhase.authenticated, status: status),
      );
      return true;
    } catch (error) {
      final exception = toApiException(error);
      final data = exception.data;
      final totpRequired = data is Map && data['totp_required'] == true;
      if (totpRequired) {
        state = AsyncData(
          AuthState(
            phase: AuthPhase.totpRequired,
            status: current?.status,
            message: exception.message,
          ),
        );
        return false;
      }
      state = AsyncData(
        AuthState(
          phase: AuthPhase.needsLogin,
          status: current?.status,
          message: exception.message,
        ),
      );
      throw exception;
    }
  }

  Future<bool> _refresh(ApiClient client) async {
    if (client.config?.activeServer?.project == ServerProject.dbOnline) {
      return false;
    }
    final current = await ref.read(authSessionRepositoryProvider).current();
    if (current == null || !current.canRefresh) return false;
    try {
      final session = await client.auth.refresh(current.refreshToken);
      if (!session.isUsable) {
        await ref.read(authSessionRepositoryProvider).clear();
        return false;
      }
      await ref.read(authSessionRepositoryProvider).save(session);
      return true;
    } catch (_) {
      await ref.read(authSessionRepositoryProvider).clear();
      return false;
    }
  }

  ServerConfig _withSelectedLine(
    ServerConfig config,
    ServerLineProbeResult selected,
  ) {
    final testedAt = DateTime.now();
    final lines = config.lines
        .map(
          (line) => line.id == selected.line.id
              ? line.copyWith(
                  latencyMs: selected.latencyMs,
                  lastTestedAt: testedAt,
                )
              : line,
        )
        .toList();
    final activeServer = config.activeServer;
    final updatedServers = activeServer == null
        ? config.servers
        : config.servers
              .map(
                (server) => server.id == activeServer.id
                    ? server.copyWith(
                        lines: lines,
                        activeLineId: selected.line.id,
                        serverVersion:
                            selected.versionInfo?.version ??
                            server.serverVersion,
                      )
                    : server,
              )
              .toList();
    return config.copyWith(
      baseUrl: selected.line.baseUrl,
      lines: lines,
      servers: updatedServers,
    );
  }

  Future<void> logout() async {
    final client = ref.read(apiClientProvider);
    try {
      await client?.auth.logout();
    } catch (_) {
      // 退出登录的本地清理必须独立于网络状态。
    } finally {
      await ref.read(authSessionRepositoryProvider).clear();
      final current = state.valueOrNull;
      state = AsyncData(
        AuthState(phase: AuthPhase.needsLogin, status: current?.status),
      );
    }
  }
}
