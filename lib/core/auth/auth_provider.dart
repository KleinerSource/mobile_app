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

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final config = ref.watch(serverConfigProvider);
    ref.watch(authExpiryProvider);
    if (config == null) {
      return const AuthState(phase: AuthPhase.unconfigured);
    }

    final candidates = config.lines.where((line) => line.enabled).toList();
    final current = candidates.firstWhere(
      (line) => line.baseUrl == config.baseUrl,
      orElse: () => candidates.isEmpty
          ? ServerLine(
              id: 'active',
              name: '当前线路',
              baseUrl: config.baseUrl,
            )
          : candidates.first,
    );
    final alternatives = candidates.where((line) => line.id != current.id);
    final selection = await ServerLineProbeCoordinator().selectPreferred(
      current: current,
      alternatives: alternatives,
    );
    final selected = selection.selected;
    if (selected == null) {
      final incompatible = selection.results.any((result) => result.incompatible);
      final detail = selection.results
          .map((result) => '${result.line.name}：${result.message}')
          .join('\n');
      return AuthState(
        phase: incompatible ? AuthPhase.incompatible : AuthPhase.unavailable,
        message: incompatible
            ? serverCompatibilityRequirementMessage
            : detail.isEmpty
                ? '没有可用的服务器线路'
                : detail,
      );
    }

    final selectedConfig = _withSelectedLine(config, selected);
    if (selectedConfig.baseUrl != config.baseUrl) {
      await ref.read(serverConfigProvider.notifier).save(selectedConfig);
    }
    final client = ApiClient.fromConfig(
      selectedConfig,
      sessionRepository: ref.read(authSessionRepositoryProvider),
      onSessionExpired: () => ref.read(authExpiryProvider.notifier).state++,
    );
    return _bootstrap(client);
  }

  Future<AuthState> _bootstrap(ApiClient client) async {
    AuthStatus status;
    try {
      status = await client.auth.status();
    } catch (error) {
      final exception = toApiException(error);
      return AuthState(
        phase: exception.status == 401 || exception.status == 404
            ? AuthPhase.incompatible
            : AuthPhase.unavailable,
        message: exception.message,
      );
    }

    if (!status.enabled) {
      // 鉴权关闭后清除历史会话，避免任务 WebSocket 继续携带旧 token。
      await ref.read(authSessionRepositoryProvider).clear();
      return AuthState(phase: AuthPhase.authenticated, status: status);
    }
    if (status.authenticated) {
      return AuthState(phase: AuthPhase.authenticated, status: status);
    }

    final session = await ref.read(authSessionRepositoryProvider).load();
    if (session != null && await _refresh(client)) {
      try {
        final refreshed = await client.auth.status();
        if (!refreshed.enabled || refreshed.authenticated) {
          return AuthState(phase: AuthPhase.authenticated, status: refreshed);
        }
        status = refreshed;
      } catch (_) {
        // 刷新成功但状态检查失败时，仍按登录页处理，避免绕过鉴权。
      }
    }

    return AuthState(phase: AuthPhase.needsLogin, status: status);
  }

  Future<bool> login({required String password, String? totpCode}) async {
    final client = ref.read(requiredApiClientProvider);
    final current = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final session = await client.auth.login(
        password: password,
        totpCode: totpCode,
      );
      if (!session.isUsable) {
        throw ApiException('登录响应缺少有效会话');
      }
      await ref.read(authSessionRepositoryProvider).save(session);
      final status = await client.auth.status();
      state = AsyncData(AuthState(
        phase: AuthPhase.authenticated,
        status: status,
      ));
      return true;
    } catch (error) {
      final exception = toApiException(error);
      final data = exception.data;
      final totpRequired = data is Map && data['totp_required'] == true;
      if (totpRequired) {
        state = AsyncData(AuthState(
          phase: AuthPhase.totpRequired,
          status: current?.status,
          message: exception.message,
        ));
        return false;
      }
      state = AsyncData(AuthState(
        phase: AuthPhase.needsLogin,
        status: current?.status,
        message: exception.message,
      ));
      throw exception;
    }
  }

  Future<bool> _refresh(ApiClient client) async {
    final current = await ref.read(authSessionRepositoryProvider).current();
    if (current == null || current.refreshToken.isEmpty) return false;
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
    return config.copyWith(baseUrl: selected.line.baseUrl, lines: lines);
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
      state = AsyncData(AuthState(
        phase: AuthPhase.needsLogin,
        status: current?.status,
      ));
    }
  }
}
