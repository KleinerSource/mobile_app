part of 'server_switch_transition.dart';

enum ServerSwitchPhase {
  idle,
  checking,
  needsLogin,
  needsApiKey,
  error,
  finishing,
  returning,
}

/// 错误阶段的固定文案类别。Notifier 层拿不到 BuildContext，
/// 只标记类别，最终展示文案由转场 UI 用 AppL10n 解析。
enum ServerSwitchMessageKind {
  restoreFailed,
  connectionFailed,
  invalidTarget,
  authCheckTimeout,
}

/// 服务器切换转场共用的头像几何。所有阶段都以这套尺寸和屏幕中心为锚点，
/// 避免飞行头像、鉴权头像和登录完成后的揭示头像出现跳变。
abstract final class ServerSwitchTransitionMetrics {
  static const avatarSize = 136.0;
  static const avatarRadius = avatarSize / 2;

  static Offset center(Size viewport) => viewport.center(Offset.zero);

  static Rect avatarRect(Size viewport) {
    return Rect.fromCenter(
      center: center(viewport),
      width: avatarSize,
      height: avatarSize,
    );
  }
}

/// 转场头像地址：用户头像仅适用于 Emby/Jellyfin，并受用户头像开关控制。
String? serverSwitchTransitionAvatarUrl({
  required ServerProfile server,
  required ServerProfileData? profile,
  required bool showUserAvatar,
}) => resolveServerAvatarUrl(
  server: server,
  profile: profile,
  showUserAvatar: showUserAvatar,
);

@immutable
class ServerSwitchState {
  const ServerSwitchState._({
    required this.phase,
    this.targetServerId,
    this.previousServerId,
    this.message,
    this.messageKind,
    this.avatarOrigin,
    this.returnToSelectionOnCancel = false,
  });

  const ServerSwitchState.idle() : this._(phase: ServerSwitchPhase.idle);

  const ServerSwitchState.checking({
    required String targetServerId,
    String? previousServerId,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.checking,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         avatarOrigin: avatarOrigin,
         returnToSelectionOnCancel: returnToSelectionOnCancel,
       );

  const ServerSwitchState.needsLogin({
    required String targetServerId,
    String? previousServerId,
    String? message,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.needsLogin,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         message: message,
         avatarOrigin: avatarOrigin,
         returnToSelectionOnCancel: returnToSelectionOnCancel,
       );

  const ServerSwitchState.needsApiKey({
    required String targetServerId,
    String? previousServerId,
    String? message,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.needsApiKey,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         message: message,
         avatarOrigin: avatarOrigin,
         returnToSelectionOnCancel: returnToSelectionOnCancel,
       );

  const ServerSwitchState.error({
    required String targetServerId,
    String? previousServerId,
    String? message,
    ServerSwitchMessageKind? messageKind,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.error,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         message: message,
         messageKind: messageKind,
         avatarOrigin: avatarOrigin,
         returnToSelectionOnCancel: returnToSelectionOnCancel,
       );

  const ServerSwitchState.finishing({
    required String targetServerId,
    String? previousServerId,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.finishing,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         avatarOrigin: avatarOrigin,
         returnToSelectionOnCancel: returnToSelectionOnCancel,
       );

  const ServerSwitchState.returning({
    required String targetServerId,
    String? previousServerId,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.returning,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         avatarOrigin: avatarOrigin,
         returnToSelectionOnCancel: returnToSelectionOnCancel,
       );

  final ServerSwitchPhase phase;
  final String? targetServerId;
  final String? previousServerId;

  /// 动态错误文本（后端/异常消息），固定文案用 [messageKind] 标记。
  final String? message;
  final ServerSwitchMessageKind? messageKind;
  final Rect? avatarOrigin;
  final bool returnToSelectionOnCancel;

  bool get isActive => phase != ServerSwitchPhase.idle;
}

final serverSwitchTransitionProvider =
    NotifierProvider<ServerSwitchTransitionController, ServerSwitchState>(
      ServerSwitchTransitionController.new,
    );

class ServerSwitchTransitionController extends Notifier<ServerSwitchState> {
  int _operation = 0;

  static const _authCheckTimeout = Duration(seconds: 12);

  @override
  ServerSwitchState build() => const ServerSwitchState.idle();

  Future<void> login({
    String? username,
    required String password,
    String? totpCode,
  }) async {
    final current = state;
    final targetServerId = current.targetServerId;
    if (!current.isActive || targetServerId == null) return;

    final previousServerId = current.previousServerId;
    final returnToSelectionOnCancel = current.returnToSelectionOnCancel;
    final operation = ++_operation;
    state = ServerSwitchState.needsLogin(
      targetServerId: targetServerId,
      previousServerId: previousServerId,
      avatarOrigin: current.avatarOrigin,
      returnToSelectionOnCancel: returnToSelectionOnCancel,
    );
    try {
      final authenticated = await ref
          .read(authControllerProvider.notifier)
          .login(username: username, password: password, totpCode: totpCode);
      if (!_isCurrent(operation)) return;
      if (authenticated) {
        await _completeAuthenticatedSwitch(operation);
        return;
      }
      final auth = ref.read(authControllerProvider).value;
      state = ServerSwitchState.needsLogin(
        targetServerId: targetServerId,
        previousServerId: previousServerId,
        message: auth?.message,
        avatarOrigin: current.avatarOrigin,
        returnToSelectionOnCancel: returnToSelectionOnCancel,
      );
    } catch (error) {
      if (!_isCurrent(operation)) return;
      final exception = toApiException(error);
      state = ServerSwitchState.needsLogin(
        targetServerId: targetServerId,
        previousServerId: previousServerId,
        message: exception.message,
        avatarOrigin: current.avatarOrigin,
        returnToSelectionOnCancel: returnToSelectionOnCancel,
      );
    }
  }

  Future<void> retry() async {
    final current = state;
    final targetServerId = current.targetServerId;
    final previousServerId = current.previousServerId;
    final returnToSelectionOnCancel = current.returnToSelectionOnCancel;
    if (!current.isActive || targetServerId == null) return;
    await switchTo(
      targetServerId,
      allowActiveTarget: true,
      previousServerIdOverride: previousServerId,
      avatarOrigin: current.avatarOrigin,
      returnToSelectionOnCancel: returnToSelectionOnCancel,
    );
  }

  Future<void> cancel() async {
    final current = state;
    final previousServerId = current.previousServerId;
    if (!current.isActive) return;
    if (current.phase == ServerSwitchPhase.finishing ||
        current.phase == ServerSwitchPhase.returning) {
      return;
    }
    if (current.returnToSelectionOnCancel) {
      // 初始化选择器中的返回只取消本次目标服务器登录，不再尝试恢复
      // 上一台服务器。上一台服务器可能从未登录过，恢复它会把用户带回
      // 另一个登录错误页。
      ++_operation;
      ref
          .read(serverConfigProvider.notifier)
          .showServerSelection(releaseResources: false);
      // 没有可用的起点时无法做有意义的反向飞行，保留旧的同步行为。
      // 正常选择器和首页快捷入口都会传入实际头像位置。
      if (current.avatarOrigin == null) {
        state = const ServerSwitchState.idle();
        return;
      }
      state = ServerSwitchState.returning(
        targetServerId: current.targetServerId!,
        previousServerId: previousServerId,
        avatarOrigin: current.avatarOrigin,
        returnToSelectionOnCancel: true,
      );
      return;
    }

    // 登录后的首页切换仍恢复原服务器，避免取消切换后丢失当前工作区。
    ++_operation;
    final operation = _operation;
    if (previousServerId == null) {
      state = const ServerSwitchState.idle();
      return;
    }
    state = ServerSwitchState.checking(
      targetServerId: previousServerId,
      previousServerId: current.targetServerId,
    );
    try {
      await ref
          .read(serverConfigProvider.notifier)
          .selectServer(previousServerId);
      if (!_isCurrent(operation)) return;
      final result = await _refreshAuthState();
      if (!_isCurrent(operation)) return;
      final auth = result.auth;
      if (auth.phase == AuthPhase.authenticated) {
        await _completeAuthenticatedSwitch(operation);
      } else {
        state = ServerSwitchState.error(
          targetServerId: previousServerId,
          previousServerId: current.targetServerId,
          // 固定前缀 + 动态明细在 UI 层按 messageKind 组装。
          message: auth.message,
          messageKind: result.timedOut
              ? ServerSwitchMessageKind.authCheckTimeout
              : ServerSwitchMessageKind.restoreFailed,
        );
      }
    } catch (error) {
      if (!_isCurrent(operation)) return;
      final exception = toApiException(error);
      state = ServerSwitchState.error(
        targetServerId: previousServerId,
        previousServerId: current.targetServerId,
        message: exception.message,
      );
    }
  }

  Future<void> _applyAuthResult(
    AuthState auth, {
    required String targetServerId,
    required String? previousServerId,
    required bool returnToSelectionOnCancel,
    required int operation,
    bool timedOut = false,
  }) {
    switch (auth.phase) {
      case AuthPhase.authenticated:
        return _completeAuthenticatedSwitch(operation);
      case AuthPhase.needsLogin:
      case AuthPhase.totpRequired:
        state = ServerSwitchState.needsLogin(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          message: auth.message,
          avatarOrigin: state.avatarOrigin,
          returnToSelectionOnCancel: returnToSelectionOnCancel,
        );
        break;
      case AuthPhase.needsApiKey:
        state = ServerSwitchState.needsApiKey(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          message: auth.message,
          avatarOrigin: state.avatarOrigin,
          returnToSelectionOnCancel: returnToSelectionOnCancel,
        );
        break;
      case AuthPhase.incompatible:
      case AuthPhase.unavailable:
        final hasServerMessage = auth.message?.trim().isNotEmpty == true;
        state = ServerSwitchState.error(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          message: hasServerMessage ? auth.message : null,
          messageKind: hasServerMessage
              ? null
              : timedOut
              ? ServerSwitchMessageKind.authCheckTimeout
              : ServerSwitchMessageKind.connectionFailed,
          avatarOrigin: state.avatarOrigin,
          returnToSelectionOnCancel: returnToSelectionOnCancel,
        );
        break;
      case AuthPhase.serverSelection:
      case AuthPhase.unconfigured:
        state = ServerSwitchState.error(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          messageKind: ServerSwitchMessageKind.invalidTarget,
          avatarOrigin: state.avatarOrigin,
          returnToSelectionOnCancel: returnToSelectionOnCancel,
        );
        break;
    }
    return Future<void>.value();
  }

  Future<void> _completeAuthenticatedSwitch(int operation) async {
    if (!_isCurrent(operation)) return;
    final current = state;
    final project = ref.read(serverConfigProvider)?.activeServer?.project;
    if (project?.isFileSource == true) {
      state = const ServerSwitchState.idle();
      return;
    }
    final targetServerId = current.targetServerId;
    if (targetServerId == null) {
      state = const ServerSwitchState.idle();
      return;
    }
    await _prefetchTargetMediaBrowserProfile(targetServerId);
    if (!_isCurrent(operation)) return;
    void beginFinishing() {
      if (!_isCurrent(operation)) return;
      state = ServerSwitchState.finishing(
        targetServerId: targetServerId,
        previousServerId: current.previousServerId,
        avatarOrigin: current.avatarOrigin,
        returnToSelectionOnCancel: current.returnToSelectionOnCancel,
      );
    }

    if (project == ServerProject.dbOnline) {
      beginFinishing();
      final refresh = Future.wait([
        ref.refresh(dbOnlineRecommendProvider.future),
        ref.refresh(dbOnlineLatestUpdatedProvider.future),
        ref.refresh(dbOnlineLatestReleasedProvider.future),
      ]);
      unawaited(refresh);
      return;
    }
    if (MediaBrowserConfig.byProject[project] != null) {
      beginFinishing();
      final refresh = Future.wait([
        ref.refresh(mediaBrowserLatestProvider.future),
        ref.refresh(mediaBrowserResumeProvider.future),
        ref.refresh(mediaBrowserNextUpProvider.future),
      ]);
      unawaited(refresh);
      return;
    }
    // 鉴权状态确认后先保留 finishing 遮罩完成头像放大。首页刷新在后台启动，
    // 避免未配置鉴权的服务器在清理旧会话或某个首页区块响应较慢时一直停留。
    final refresh = refreshHomeProviders(
      refreshRecentlyAdded: () => ref.refresh(recentlyAddedProvider.future),
      refreshContinueWatching: () =>
          ref.refresh(continueWatchingProvider.future),
      refreshLibraries: () => ref.refresh(librariesProvider.future),
      refreshRecommendCarousel: () =>
          ref.refresh(recommendCarouselProvider.future),
    );
    beginFinishing();
    unawaited(refresh);
  }

  Future<void> _prefetchTargetMediaBrowserProfile(String serverId) async {
    final config =
        ref.read(serverConfigProvider) ??
        ref.read(serverConfigRepoProvider).load();
    ServerProfile? target;
    for (final server in config?.servers ?? const <ServerProfile>[]) {
      if (server.id == serverId) {
        target = server;
        break;
      }
    }
    if (target?.project != ServerProject.emby &&
        target?.project != ServerProject.jellyfin) {
      return;
    }
    final cachedProfile = ref
        .read(serverProfileCacheRepoProvider)
        .load(serverId);
    if (cachedProfile?.userAvatarUrl?.trim().isNotEmpty == true) return;
    try {
      await loadMediaBrowserUserProfile(ref.read, target!);
    } catch (_) {
      // 资料加载失败时继续转场，由头像组件使用服务器 Logo 兜底。
    }
  }

  /// 登录成功后的内容放大转场结束后，由遮罩层解除切换状态。
  void finishTransition() {
    if (state.phase == ServerSwitchPhase.finishing) {
      state = const ServerSwitchState.idle();
    }
  }

  /// 鉴权取消后的头像反向飞行结束后，由遮罩层解除切换状态。
  void finishReturnTransition() {
    if (state.phase == ServerSwitchPhase.returning) {
      state = const ServerSwitchState.idle();
    }
  }

  Future<void> switchTo(
    String serverId, {
    bool allowActiveTarget = false,
    String? previousServerIdOverride,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) async {
    // 从已登录页面返回选择器时，旧运行态会先被卸载以释放服务器资源；
    // 选择器仍通过持久化配置展示服务器，因此切换也必须使用同一份回退配置。
    final current =
        ref.read(serverConfigProvider) ??
        ref.read(serverConfigRepoProvider).load();
    if (current == null) return;
    if (current.activeServerId == serverId && !allowActiveTarget) return;
    if (state.isActive && !allowActiveTarget) return;

    final previousServerId =
        previousServerIdOverride ??
        (current.activeServerId == serverId ? null : current.activeServerId);
    final operation = ++_operation;
    state = ServerSwitchState.checking(
      targetServerId: serverId,
      previousServerId: previousServerId,
      avatarOrigin: avatarOrigin,
      returnToSelectionOnCancel: returnToSelectionOnCancel,
    );
    try {
      if (current.activeServerId != serverId || allowActiveTarget) {
        await ref.read(serverConfigProvider.notifier).selectServer(serverId);
      }
      if (!_isCurrent(operation)) return;
      final target = current.servers.firstWhere(
        (server) => server.id == serverId,
      );
      if (target.project?.isFileSource == true) {
        state = const ServerSwitchState.idle();
        return;
      }
      final auth = await _refreshAuthState();
      if (!_isCurrent(operation)) return;
      await _applyAuthResult(
        auth.auth,
        targetServerId: serverId,
        previousServerId: previousServerId,
        returnToSelectionOnCancel: returnToSelectionOnCancel,
        operation: operation,
        timedOut: auth.timedOut,
      );
    } catch (error) {
      if (!_isCurrent(operation)) return;
      final exception = toApiException(error);
      state = ServerSwitchState.error(
        targetServerId: serverId,
        previousServerId: previousServerId,
        message: exception.message.trim().isEmpty ? null : exception.message,
        messageKind: exception.message.trim().isEmpty
            ? ServerSwitchMessageKind.connectionFailed
            : null,
        avatarOrigin: avatarOrigin,
        returnToSelectionOnCancel: returnToSelectionOnCancel,
      );
    }
  }

  bool _isCurrent(int operation) => operation == _operation;

  /// 强制读取服务器切换后的新鉴权状态。
  ///
  /// 配置切换会同时触发 [authControllerProvider] 重建；只调用
  /// `invalidate` 后再读取 `.future` 可能仍然接到上一轮异步构建的 Future，
  /// 让切换遮罩一直停留在检查状态。`refresh` 会确保等待本次服务器对应的
  /// 状态；超时则返回无消息的 unavailable 状态并标记 timedOut，
  /// 由 UI 层给出本地化的超时文案，避免网络异常造成无限等待。
  Future<({AuthState auth, bool timedOut})> _refreshAuthState() async {
    try {
      final auth = await ref
          .read(authControllerProvider.notifier)
          .refreshCurrentServer()
          .timeout(_authCheckTimeout);
      return (auth: auth, timedOut: false);
    } on TimeoutException {
      return (
        auth: const AuthState(phase: AuthPhase.unavailable),
        timedOut: true,
      );
    }
  }
}

/// 服务器切换的全屏材质层。切换期间根路由只挂载静态背景和此层，目标服务器
/// 的探测和登录都在此层完成，因此不会在鉴权完成前构建首页请求。
