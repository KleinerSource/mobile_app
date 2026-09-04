import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:omm/features/media_browser/api/media_browser_config.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/dio_factory.dart';
import '../api/providers.dart';
import '../api/server_compatibility.dart';
import '../config/server_config.dart';
import '../config/server_config_provider.dart';
import '../config/server_line_probe.dart';
import 'auth_session.dart';
import 'auth_session_repository.dart';
import 'auth_session_provider.dart';
import 'totp_code.dart';
import '../platform/device_id.dart';

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
    if (config.activeServer?.project?.isFileSource == true) {
      return const AuthState(phase: AuthPhase.authenticated);
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
      stashApiKeyRepository: ref.read(stashApiKeyRepositoryProvider),
      onSessionExpired: () => ref.read(authExpiryProvider.notifier).state++,
      onStashApiKeyInvalid: () => ref.read(authExpiryProvider.notifier).state++,
    );
    return _bootstrap(client);
  }

  Future<AuthState> _bootstrap(ApiClient client) async {
    final project = client.config?.activeServer?.project;
    final isDbOnline = project == ServerProject.dbOnline;
    if (project == ServerProject.stash) {
      return _bootstrapStash(client);
    }
    final mediaBrowserConfig = MediaBrowserConfig.byProject[project];
    if (project == ServerProject.feiniu) {
      return _bootstrapFeiniu(client);
    }
    if (mediaBrowserConfig != null) {
      return _bootstrapMediaBrowser(client, mediaBrowserConfig);
    }
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
      // Oh My Media 会话必须同时具备 access/refresh 两个令牌；旧版或
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
    if (config.activeServer?.project?.isFileSource == true) {
      const result = AuthState(phase: AuthPhase.authenticated);
      state = const AsyncData(result);
      return result;
    }

    // 检查期间保留既有状态，不置为裸 AsyncLoading：根路由的 loading 分支
    // 会替换整个登录选择页，导致内联登录表单丢失。调用方各自展示 busy。
    final client = ApiClient.fromConfig(
      config,
      sessionRepository: ref.read(authSessionRepositoryProvider),
      stashApiKeyRepository: ref.read(stashApiKeyRepositoryProvider),
      onSessionExpired: () => ref.read(authExpiryProvider.notifier).state++,
      onStashApiKeyInvalid: () => ref.read(authExpiryProvider.notifier).state++,
    );
    final result = await _bootstrap(client);
    state = AsyncData(result);
    return result;
  }

  Future<bool> login({
    String? username,
    required String password,
    String? totpCode,
  }) async {
    final client = ref.read(requiredApiClientProvider);
    // 登录期间服务器列表仍可能在后台加载其他服务器资料；固定本次
    // 客户端对应的会话作用域，避免 token/cookie 被写到其他服务器。
    final sessionRepository = _sessionRepositoryForClient(client);
    final isDbOnline =
        client.config?.activeServer?.project == ServerProject.dbOnline;
    final mediaBrowserConfig =
        MediaBrowserConfig.byProject[client.config?.activeServer?.project];
    if (client.config?.activeServer?.project == ServerProject.feiniu) {
      return _loginFeiniu(
        client,
        sessionRepository: sessionRepository,
        username: username,
        password: password,
      );
    }
    if (mediaBrowserConfig != null) {
      return _loginMediaBrowser(
        client,
        sessionRepository: sessionRepository,
        config: mediaBrowserConfig,
        username: username,
        password: password,
      );
    }
    final current = state.value;
    // 登录请求期间保留 needsLogin 状态（页面有自己的 busy 指示），避免根
    // 路由进入 loading 分支重建登录页。
    try {
      var code = totpCode?.trim() ?? '';
      if (code.isEmpty) {
        // 已配置 TOTP 密钥的服务器直接本地生成验证码，用户无需手输。
        code = await _autoTotpCode(sessionRepository) ?? '';
      }
      await _completePasswordLogin(
        client,
        sessionRepository: sessionRepository,
        isDbOnline: isDbOnline,
        password: password,
        totpCode: code.isEmpty ? null : code,
      );
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

  /// MediaBrowser（Emby/Jellyfin）启动校验：用用户端点验证令牌，失效
  /// 回到登录页。
  ///
  /// 两家都没有 OMM 的 /auth/status 接口，鉴权状态只能由令牌有效性
  /// 推导。Jellyfin 有 /Users/Me（按 token 反查用户）；Emby 实测返回
  /// 500，只能用登录时持久化的 userId 查 /Users/{uid}。
  Future<AuthState> _bootstrapMediaBrowser(
    ApiClient client,
    MediaBrowserConfig config,
  ) async {
    final sessionRepository = _sessionRepositoryForClient(client);
    final session = await sessionRepository.load();
    final userId = session?.userId?.trim() ?? '';
    if (session == null ||
        !session.hasAccessToken ||
        (!config.supportsCurrentUser && userId.isEmpty)) {
      // Emby 没有用户 ID 就无法拼出任何用户端点，只能重新登录。
      await sessionRepository.clear();
      return const AuthState(phase: AuthPhase.needsLogin);
    }
    try {
      final user = await client
          .mediaBrowserFor(config)
          .validateSession(session.userId);
      // 极少数情况下令牌仍有效但绑定用户变化（服务端重建用户），同步本地
      // 记录的 userId，条目查询依赖它拼接 /Users/{uid} 路径。
      if (user.id.isNotEmpty && user.id != session.userId) {
        await sessionRepository.save(
          AuthSession(
            accessToken: session.accessToken,
            refreshToken: '',
            expiresIn: 0,
            userId: user.id,
          ),
        );
      }
      return const AuthState(phase: AuthPhase.authenticated);
    } catch (error) {
      final exception = toApiException(error);
      if (exception.status == 401 ||
          (!config.supportsCurrentUser && exception.status == 404)) {
        await sessionRepository.clear();
        return const AuthState(phase: AuthPhase.needsLogin);
      }
      return AuthState(
        phase: AuthPhase.unavailable,
        message: exception.message,
      );
    }
  }

  Future<AuthState> _bootstrapStash(ApiClient client) async {
    final config = client.config;
    final serverId = config?.activeServerId?.trim() ?? '';
    final repository = ref.read(stashApiKeyRepositoryProvider);
    final key = serverId.isEmpty ? null : await repository.read(serverId);
    if (key == null) return const AuthState(phase: AuthPhase.needsApiKey);
    try {
      await client.stash.validateApiKey(key);
      return const AuthState(phase: AuthPhase.authenticated);
    } catch (error) {
      final exception = toApiException(error);
      if (exception.status == 401 || exception.status == 403) {
        if (serverId.isNotEmpty) await repository.delete(serverId);
        return AuthState(
          phase: AuthPhase.needsApiKey,
          message: exception.message,
        );
      }
      return AuthState(
        phase: AuthPhase.unavailable,
        message: exception.message,
      );
    }
  }

  /// 为当前 Stash 服务器验证并保存 API Key。
  Future<bool> setStashApiKey(String value) async {
    final config = ref.read(serverConfigProvider);
    if (config?.activeServer?.project != ServerProject.stash) {
      throw ApiException('当前服务器不是 Stash');
    }
    final key = value.trim();
    if (key.isEmpty) {
      state = const AsyncData(AuthState(phase: AuthPhase.needsApiKey));
      return false;
    }
    final client = ref.read(requiredApiClientProvider);
    try {
      await client.stash.validateApiKey(key);
      final serverId = config!.activeServerId;
      if (serverId == null || serverId.trim().isEmpty) {
        throw ApiException('当前 Stash 服务器缺少服务器 ID');
      }
      await ref.read(stashApiKeyRepositoryProvider).save(serverId, key);
      state = const AsyncData(AuthState(phase: AuthPhase.authenticated));
      return true;
    } catch (error) {
      final exception = toApiException(error);
      state = AsyncData(
        AuthState(phase: AuthPhase.needsApiKey, message: exception.message),
      );
      throw exception;
    }
  }

  Future<AuthState> _bootstrapFeiniu(ApiClient client) async {
    final sessionRepository = _sessionRepositoryForClient(client);
    final session = await sessionRepository.load();
    // Cookie 只用于部分图片/媒体资源，飞牛 API 的登录态由 token 验证；
    // 某些版本或网络环境不会在登录响应中暴露 Set-Cookie，不能因此要求重登。
    if (session == null || !session.hasAccessToken) {
      await sessionRepository.clear();
      return const AuthState(phase: AuthPhase.needsLogin);
    }
    try {
      final user = await client.feiniu.userInfo();
      if (user.id.isEmpty) throw ApiException('飞牛用户信息缺少用户 ID');
      if (session.userId != user.id) {
        await sessionRepository.save(
          AuthSession(
            accessToken: session.accessToken,
            refreshToken: '',
            expiresIn: 0,
            userId: user.id,
            cookie: session.cookie,
          ),
        );
      }
      return const AuthState(phase: AuthPhase.authenticated);
    } catch (error) {
      final exception = toApiException(error);
      if (exception.status == 401 || exception.status == 403) {
        await sessionRepository.clear();
        return const AuthState(phase: AuthPhase.needsLogin);
      }
      return AuthState(
        phase: AuthPhase.unavailable,
        message: exception.message,
      );
    }
  }

  AuthSessionRepository _sessionRepositoryForClient(ApiClient client) {
    final config = client.config;
    final project = config?.activeServer?.project;
    final allowLegacyMigration =
        project != ServerProject.dbOnline &&
        project != ServerProject.emby &&
        project != ServerProject.jellyfin;
    return ref
        .read(authSessionRepositoryProvider)
        .forServer(
          config?.activeServerId,
          allowLegacyMigration: allowLegacyMigration,
        );
  }

  Future<bool> _loginFeiniu(
    ApiClient client, {
    required AuthSessionRepository sessionRepository,
    required String? username,
    required String password,
  }) async {
    final current = state.value;
    final user = username?.trim() ?? '';
    if (user.isEmpty) {
      state = AsyncData(
        AuthState(
          phase: AuthPhase.needsLogin,
          status: current?.status,
          message: '请输入用户名',
        ),
      );
      return false;
    }
    try {
      await _completeFeiniuLogin(
        client,
        sessionRepository: sessionRepository,
        username: user,
        password: password,
      );
      state = const AsyncData(AuthState(phase: AuthPhase.authenticated));
      return true;
    } catch (error) {
      await sessionRepository.clear();
      final exception = toApiException(error);
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

  Future<bool> _loginMediaBrowser(
    ApiClient client, {
    required AuthSessionRepository sessionRepository,
    required MediaBrowserConfig config,
    required String? username,
    required String password,
  }) async {
    final current = state.value;
    final user = username?.trim() ?? '';
    if (user.isEmpty) {
      state = AsyncData(
        AuthState(
          phase: AuthPhase.needsLogin,
          status: current?.status,
          message: '请输入用户名',
        ),
      );
      return false;
    }
    try {
      await _completeMediaBrowserLogin(
        client,
        sessionRepository: sessionRepository,
        config: config,
        username: user,
        password: password,
      );
      state = const AsyncData(AuthState(phase: AuthPhase.authenticated));
      return true;
    } catch (error) {
      final exception = toApiException(error);
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

  /// 添加/编辑服务器时用一次性凭据登录目标服务器并保存会话。
  ///
  /// 目标服务器通常尚未激活，这里构造仅包含它的临时配置来建客户端，
  /// 会话写入该服务器的作用域，不改变当前登录状态；TOTP 密钥只用于
  /// 本次算码，是否持久化由调用方决定。失败抛 [ApiException]；OMM/DBO
  /// 鉴权未启用时视为无需登录直接返回。
  Future<void> loginForServer({
    required ServerProfile server,
    String? username,
    required String password,
    String? totpSecret,
  }) async {
    final project = server.project;
    if (project == null) throw ApiException('服务器类型无效');
    final line = server.activeLine ?? server.lines.first;
    final rawSecret = totpSecret?.trim() ?? '';
    final normalizedSecret = rawSecret.isEmpty
        ? null
        : normalizeTotpSecret(rawSecret);
    if (rawSecret.isNotEmpty && normalizedSecret == null) {
      throw ApiException('TOTP 密钥格式无效（应为 base32 字符串）');
    }

    final sessionRepository = ref
        .read(authSessionRepositoryProvider)
        .forServer(server.id, allowLegacyMigration: false);
    final client = ApiClient.fromConfig(
      ServerConfig(
        baseUrl: line.baseUrl,
        lines: server.lines,
        servers: [server],
        activeServerId: server.id,
      ),
      sessionRepository: sessionRepository,
    );

    final mediaBrowserConfig = MediaBrowserConfig.byProject[project];
    if (project == ServerProject.stash) return;
    if (project == ServerProject.feiniu) {
      final user = username?.trim() ?? '';
      if (user.isEmpty) throw ApiException('请输入用户名');
      await _completeFeiniuLogin(
        client,
        sessionRepository: sessionRepository,
        username: user,
        password: password,
      );
      return;
    }
    if (mediaBrowserConfig != null) {
      final user = username?.trim() ?? '';
      if (user.isEmpty) throw ApiException('请输入用户名');
      await _completeMediaBrowserLogin(
        client,
        sessionRepository: sessionRepository,
        config: mediaBrowserConfig,
        username: user,
        password: password,
      );
      return;
    }

    // OMM/DBO：鉴权未启用或尚未配置密码的服务器无需登录。
    final status = await client.auth.status();
    if (!status.enabled || !status.configured) return;
    final effectiveSecret =
        normalizedSecret ?? await sessionRepository.readTotpSecret();
    await _completePasswordLogin(
      client,
      sessionRepository: sessionRepository,
      isDbOnline: project == ServerProject.dbOnline,
      password: password,
      totpCode: effectiveSecret == null
          ? null
          : tryGenerateTotpCode(effectiveSecret),
    );
  }

  /// OMM/DBO 密码登录内核：换取会话并校验，DBO 追加令牌 verify。
  /// 成功后保存会话；失败抛 [ApiException]，由调用方决定状态呈现。
  Future<void> _completePasswordLogin(
    ApiClient client, {
    required AuthSessionRepository sessionRepository,
    required bool isDbOnline,
    required String password,
    String? totpCode,
  }) async {
    final session = await client.auth.login(
      password: password,
      totpCode: totpCode,
    );
    if (isDbOnline ? !session.hasAccessToken : !session.isUsable) {
      throw ApiException('登录响应缺少有效会话');
    }
    await sessionRepository.save(session);
    if (isDbOnline) {
      try {
        if (!await client.auth.verify()) {
          throw ApiException('登录响应令牌无效');
        }
      } catch (_) {
        await sessionRepository.clear();
        rethrow;
      }
    }
  }

  /// 飞牛登录内核：换 token → 存会话 → userInfo 回填 userId 再存。
  Future<void> _completeFeiniuLogin(
    ApiClient client, {
    required AuthSessionRepository sessionRepository,
    required String username,
    required String password,
  }) async {
    final token = await client.feiniu.login(
      username: username,
      password: password,
    );
    final cookie = client.feiniu.lastLoginCookie;
    await sessionRepository.save(
      AuthSession(
        accessToken: token,
        refreshToken: '',
        expiresIn: 0,
        cookie: cookie,
      ),
    );
    final profile = await client.feiniu.userInfo();
    if (profile.id.isEmpty) throw ApiException('飞牛用户信息缺少用户 ID');
    await sessionRepository.save(
      AuthSession(
        accessToken: token,
        refreshToken: '',
        expiresIn: 0,
        userId: profile.id,
        cookie: cookie,
      ),
    );
  }

  /// Emby/Jellyfin 登录内核：AuthenticateByName 换令牌并保存会话。
  Future<void> _completeMediaBrowserLogin(
    ApiClient client, {
    required AuthSessionRepository sessionRepository,
    required MediaBrowserConfig config,
    required String username,
    required String password,
  }) async {
    final deviceId = await stableDeviceId(ref.read(sharedPrefsProvider));
    final result = await client
        .mediaBrowserFor(config)
        .authenticateByName(
          username: username,
          password: password,
          deviceId: deviceId,
          deviceName: Platform.operatingSystem,
          appVersion: await _appVersion(),
        );
    if (result.accessToken.isEmpty || result.user.id.isEmpty) {
      throw ApiException('登录响应缺少有效会话');
    }
    await sessionRepository.save(
      AuthSession(
        accessToken: result.accessToken,
        refreshToken: '',
        expiresIn: 0,
        userId: result.user.id,
      ),
    );
  }

  /// 已配置 TOTP 密钥时生成当前验证码；读取或解码失败按未配置处理，
  /// 让服务端 totp_required 流程兜底。
  Future<String?> _autoTotpCode(AuthSessionRepository sessionRepository) async {
    try {
      final secret = await sessionRepository.readTotpSecret();
      if (secret == null) return null;
      return tryGenerateTotpCode(secret);
    } catch (_) {
      return null;
    }
  }

  Future<String> _appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // 单元测试环境没有注册 package_info_plus 插件，版本号可缺省。
      return '';
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
    final activeProject = client?.config?.activeServer?.project;
    if (activeProject == ServerProject.feiniu) {
      try {
        await client?.feiniu.logout();
      } catch (_) {
        // 退出登录的本地清理必须独立于网络状态。
      }
    }
    // Emby/Jellyfin 的令牌无服务端过期语义，登出只需丢弃本地会话。
    if (activeProject != ServerProject.feiniu &&
        activeProject != ServerProject.emby &&
        activeProject != ServerProject.jellyfin) {
      try {
        await client?.auth.logout();
      } catch (_) {
        // 退出登录的本地清理必须独立于网络状态。
      }
    }
    await ref.read(authSessionRepositoryProvider).clear();
    final current = state.value;
    state = AsyncData(
      AuthState(phase: AuthPhase.needsLogin, status: current?.status),
    );
  }
}
