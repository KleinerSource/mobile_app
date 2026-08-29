import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/server_avatar.dart';
import '../../shared/shake_error_text.dart';
import '../../shared/totp_input_field.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'home_providers.dart';

enum ServerSwitchPhase {
  idle,
  checking,
  needsLogin,
  error,
  finishing,
  returning,
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

@immutable
class ServerSwitchState {
  const ServerSwitchState._({
    required this.phase,
    this.targetServerId,
    this.previousServerId,
    this.message,
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

  const ServerSwitchState.error({
    required String targetServerId,
    String? previousServerId,
    required String message,
    Rect? avatarOrigin,
    bool returnToSelectionOnCancel = false,
  }) : this._(
         phase: ServerSwitchPhase.error,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         message: message,
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
  final String? message;
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

  Future<void> login({required String password, String? totpCode}) async {
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
          .login(password: password, totpCode: totpCode);
      if (!_isCurrent(operation)) return;
      if (authenticated) {
        await _completeAuthenticatedSwitch(operation);
        return;
      }
      final auth = ref.read(authControllerProvider).valueOrNull;
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
      final auth = await _refreshAuthState();
      if (!_isCurrent(operation)) return;
      if (auth.phase == AuthPhase.authenticated) {
        await _completeAuthenticatedSwitch(operation);
      } else {
        state = ServerSwitchState.error(
          targetServerId: previousServerId,
          previousServerId: current.targetServerId,
          message: '无法恢复当前服务器：${auth.message ?? '服务器鉴权失败'}',
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
      case AuthPhase.incompatible:
      case AuthPhase.unavailable:
        state = ServerSwitchState.error(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          message: auth.message?.trim().isNotEmpty == true
              ? auth.message!
              : '服务器连接失败，请重试或返回当前服务器',
          avatarOrigin: state.avatarOrigin,
          returnToSelectionOnCancel: returnToSelectionOnCancel,
        );
        break;
      case AuthPhase.serverSelection:
      case AuthPhase.unconfigured:
        state = ServerSwitchState.error(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          message: '目标服务器配置无效，请重试或返回当前服务器',
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
        auth,
        targetServerId: serverId,
        previousServerId: previousServerId,
        returnToSelectionOnCancel: returnToSelectionOnCancel,
        operation: operation,
      );
    } catch (error) {
      if (!_isCurrent(operation)) return;
      final exception = toApiException(error);
      state = ServerSwitchState.error(
        targetServerId: serverId,
        previousServerId: previousServerId,
        message: exception.message.trim().isEmpty
            ? '服务器连接失败，请重试或返回当前服务器'
            : exception.message,
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
  /// 状态；超时则转成可重试错误，避免网络异常造成无限等待。
  Future<AuthState> _refreshAuthState() async {
    try {
      return await ref
          .read(authControllerProvider.notifier)
          .refreshCurrentServer()
          .timeout(_authCheckTimeout);
    } on TimeoutException {
      return const AuthState(
        phase: AuthPhase.unavailable,
        message: '检查服务器鉴权状态超时，请检查网络后重试',
      );
    }
  }
}

/// 服务器切换的全屏材质层。切换期间根路由只挂载静态背景和此层，目标服务器
/// 的探测和登录都在此层完成，因此不会在鉴权完成前构建首页请求。
class ServerSwitchTransitionOverlay extends ConsumerStatefulWidget {
  const ServerSwitchTransitionOverlay({super.key});

  @override
  ConsumerState<ServerSwitchTransitionOverlay> createState() =>
      _ServerSwitchTransitionOverlayState();
}

class _ServerSwitchTransitionOverlayState
    extends ConsumerState<ServerSwitchTransitionOverlay>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  late final AnimationController _entryController;
  late final AnimationController _handoffController;
  late final AnimationController _finishController;
  String? _entryServerId;
  Rect? _entryOrigin;
  String? _finishingServerId;
  String? _returningServerId;
  bool _loginBusy = false;
  bool _totpRequired = false;
  String? _localError;

  static const _avatarFlightDuration = Duration(milliseconds: 460);
  static const _avatarHandoffDuration = Duration(milliseconds: 240);
  static const _avatarFinishDuration = Duration(milliseconds: 620);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: _avatarFlightDuration,
    );
    _handoffController = AnimationController(
      vsync: this,
      duration: _avatarHandoffDuration,
    );
    _finishController = AnimationController(
      vsync: this,
      duration: _avatarFinishDuration,
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _handoffController.dispose();
    _finishController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transition = ref.watch(serverSwitchTransitionProvider);
    if (!transition.isActive) return const SizedBox.shrink();

    final colors = appColors(context);
    // 从选择器重新进入服务器时，旧服务器运行态可能已经释放；目标信息
    // 仍应从本地持久化配置读取，不能在这段过渡期把页面渲染成“配置无效”。
    final config = ref.watch(serverSelectionConfigProvider);
    final target = _targetServer(config, transition.targetServerId);
    if (target == null) {
      return _buildMaterial(
        context,
        const _TransitionContent(
          icon: Icons.dns_outlined,
          title: '服务器配置无效',
          message: '无法找到目标服务器，请返回后重试。',
        ),
        transition: transition,
      );
    }

    if (transition.phase == ServerSwitchPhase.finishing) {
      _ensureFinishing(context, transition);
    } else if (transition.phase == ServerSwitchPhase.returning) {
      _ensureReturning(context, transition);
    } else {
      _ensureEntry(context, transition);
    }

    // 验证码界面由本地状态驱动：服务端返回 totp_required 时置位，「返回
    // 输入密码」时复位；provider 的 totpRequired 阶段会一直保持，不能
    // 作为切换依据。服务器开启 TOTP 但尚未验证密码时仍先显示密码表单。
    final requiresTotp = _totpRequired;
    final content = switch (transition.phase) {
      ServerSwitchPhase.checking => _buildChecking(context, colors, target),
      ServerSwitchPhase.needsLogin => _buildLogin(
        context,
        colors,
        target,
        requiresTotp,
        transition.message,
      ),
      ServerSwitchPhase.error => _buildError(
        context,
        colors,
        target,
        transition.message,
      ),
      ServerSwitchPhase.finishing => const SizedBox.shrink(),
      ServerSwitchPhase.returning => const SizedBox.shrink(),
      ServerSwitchPhase.idle => const SizedBox.shrink(),
    };

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: _buildMaterial(
        context,
        transition: transition,
        target: target,
        content,
      ),
    );
  }

  void _ensureEntry(BuildContext context, ServerSwitchState transition) {
    final targetServerId = transition.targetServerId;
    if (targetServerId == null || _entryServerId == targetServerId) return;

    _entryServerId = targetServerId;
    _entryOrigin = transition.avatarOrigin;
    _entryController.stop();
    _handoffController.stop();
    _entryController.value = _entryOrigin == null ? 1 : 0;
    _handoffController.value = _entryOrigin == null ? 1 : 0;
    if (_entryOrigin == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entryServerId != targetServerId) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _entryController.value = 1;
        _handoffController.value = 1;
      } else {
        unawaited(
          _entryController.forward().then((_) {
            if (mounted && _entryServerId == targetServerId) {
              if (ref.read(serverSwitchTransitionProvider).phase ==
                  ServerSwitchPhase.returning) {
                return;
              }
              unawaited(_handoffController.forward());
            }
          }),
        );
      }
    });
  }

  void _ensureFinishing(BuildContext context, ServerSwitchState transition) {
    final targetServerId = transition.targetServerId;
    if (targetServerId == null || _finishingServerId == targetServerId) return;

    _finishingServerId = targetServerId;
    _entryController.stop();
    _handoffController.stop();
    _entryController.value = 1;
    _handoffController.value = 1;
    _finishController.stop();
    _finishController.value = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finishingServerId != targetServerId) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _finishController.value = 1;
        ref.read(serverSwitchTransitionProvider.notifier).finishTransition();
        return;
      }
      unawaited(
        _finishController.forward().then((_) {
          if (mounted && _finishingServerId == targetServerId) {
            ref
                .read(serverSwitchTransitionProvider.notifier)
                .finishTransition();
          }
        }),
      );
    });
  }

  void _ensureReturning(BuildContext context, ServerSwitchState transition) {
    final targetServerId = transition.targetServerId;
    if (targetServerId == null || _returningServerId == targetServerId) return;

    _returningServerId = targetServerId;
    _entryController.stop();
    _handoffController.stop();
    _finishController.stop();
    _handoffController.value = 0;

    if (_entryOrigin == null || _entryController.value <= 0) {
      _entryController.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _returningServerId == targetServerId) {
          ref
              .read(serverSwitchTransitionProvider.notifier)
              .finishReturnTransition();
        }
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _returningServerId != targetServerId) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _entryController.value = 0;
        ref
            .read(serverSwitchTransitionProvider.notifier)
            .finishReturnTransition();
        return;
      }
      unawaited(
        _entryController.reverse().then((_) {
          if (mounted && _returningServerId == targetServerId) {
            ref
                .read(serverSwitchTransitionProvider.notifier)
                .finishReturnTransition();
          }
        }),
      );
    });
  }

  Widget _buildMaterial(
    BuildContext context,
    Widget content, {
    required ServerSwitchState transition,
    ServerProfile? target,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final renderObject = context.findRenderObject();
          final overlayOrigin = renderObject is RenderBox
              ? renderObject.localToGlobal(Offset.zero)
              : Offset.zero;
          final localEntryOrigin = _entryOrigin?.shift(
            Offset(-overlayOrigin.dx, -overlayOrigin.dy),
          );
          final isFinishing = transition.phase == ServerSwitchPhase.finishing;

          return AnimatedBuilder(
            animation: Listenable.merge([
              _entryController,
              _handoffController,
              _finishController,
            ]),
            builder: (context, _) {
              final entryProgress = _entryOrigin == null
                  ? 1.0
                  : Curves.easeOutCubic.transform(_entryController.value);
              final handoffProgress = Curves.easeOutCubic.transform(
                _handoffController.value,
              );
              final finishProgress = Curves.easeInCubic.transform(
                _finishController.value,
              );
              if (isFinishing) {
                return Material(
                  color: Colors.transparent,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildRevealMask(
                        isDark: isDark,
                        viewport: constraints.biggest,
                        progress: finishProgress,
                      ),
                      const Positioned.fill(
                        child: ModalBarrier(
                          dismissible: false,
                          color: Colors.transparent,
                        ),
                      ),
                      if (target != null)
                        _buildFinishingAvatar(
                          colors: appColors(context),
                          server: target,
                          progress: finishProgress,
                        ),
                    ],
                  ),
                );
              }

              if (transition.phase == ServerSwitchPhase.returning) {
                final overlayProgress = entryProgress;
                return Material(
                  color: Colors.transparent,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 24 * overlayProgress,
                          sigmaY: 24 * overlayProgress,
                        ),
                        child: ColoredBox(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(
                                alpha: (isDark ? 0.62 : 0.72) * overlayProgress,
                              ),
                        ),
                      ),
                      const Positioned.fill(
                        child: ModalBarrier(
                          dismissible: false,
                          color: Colors.transparent,
                        ),
                      ),
                      if (target != null && localEntryOrigin != null)
                        _buildEntryAvatar(
                          colors: appColors(context),
                          server: target,
                          origin: localEntryOrigin,
                          destination: ServerSwitchTransitionMetrics.avatarRect(
                            constraints.biggest,
                          ),
                          progress: entryProgress,
                          opacity: 1,
                        ),
                    ],
                  ),
                );
              }

              final overlayProgress = entryProgress;
              final baseAlpha = isDark ? 0.62 : 0.72;
              final contentOpacity = _entryOrigin == null
                  ? 1.0
                  : handoffProgress;
              final contentOffset = _entryOrigin == null
                  ? Offset.zero
                  : Offset(0, (1 - handoffProgress) * 10);

              return Material(
                color: Colors.transparent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 24 * overlayProgress,
                        sigmaY: 24 * overlayProgress,
                      ),
                      child: ColoredBox(
                        color: (isDark ? Colors.black : Colors.white)
                            .withValues(alpha: baseAlpha * overlayProgress),
                      ),
                    ),
                    const Positioned.fill(
                      child: ModalBarrier(
                        dismissible: false,
                        color: Colors.transparent,
                      ),
                    ),
                    IgnorePointer(
                      ignoring: contentOpacity < 1,
                      child: Opacity(
                        opacity: contentOpacity,
                        child: Transform.translate(
                          offset: contentOffset,
                          child: _buildContentViewport(
                            constraints: constraints,
                            content: content,
                            server: target,
                            avatarBusy:
                                transition.phase ==
                                    ServerSwitchPhase.checking ||
                                _loginBusy,
                          ),
                        ),
                      ),
                    ),
                    if (!isFinishing &&
                        target != null &&
                        localEntryOrigin != null &&
                        (_entryController.value < 1 ||
                            _handoffController.value < 1))
                      _buildEntryAvatar(
                        colors: appColors(context),
                        server: target,
                        origin: localEntryOrigin,
                        destination: ServerSwitchTransitionMetrics.avatarRect(
                          constraints.biggest,
                        ),
                        progress: entryProgress,
                        opacity: 1 - handoffProgress,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContentViewport({
    required BoxConstraints constraints,
    required Widget content,
    required ServerProfile? server,
    required bool avatarBusy,
  }) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    // 头像是滚动内容的一部分：键盘出现或表单自动滚动时，头像与表单
    // 必须共享同一个 scroll offset。顶部位置仍与外层飞行头像的中心
    // 几何完全一致，避免交接时发生位置跳变。
    final contentTop = math.max(
      0.0,
      constraints.biggest.height / 2 -
          ServerSwitchTransitionMetrics.avatarRadius,
    );
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          contentTop,
          24,
          viewInsets.bottom + 32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (server != null) ...[
                  SizedBox(
                    width: ServerSwitchTransitionMetrics.avatarSize,
                    height: ServerSwitchTransitionMetrics.avatarSize,
                    child: _buildAvatar(
                      colors: appColors(context),
                      server: server,
                      size: ServerSwitchTransitionMetrics.avatarSize,
                      busy: avatarBusy,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  reverseDuration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryAvatar({
    required AppColors colors,
    required ServerProfile server,
    required Rect origin,
    required Rect destination,
    required double progress,
    required double opacity,
  }) {
    final profile = _cachedProfileFor(server);
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : server.name;
    final rect = Rect.lerp(origin, destination, progress)!;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ServerAvatar(
            displayName: name,
            avatarUrl: profile?.avatarUrl ?? server.avatarUrl,
            size: rect.width,
            colors: colors,
            project: server.project,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required AppColors colors,
    required ServerProfile server,
    required double size,
    bool busy = false,
  }) {
    final profile = _cachedProfileFor(server);
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : server.name;
    return ServerAvatar(
      displayName: name,
      avatarUrl: profile?.avatarUrl ?? server.avatarUrl,
      size: size,
      busy: busy,
      colors: colors,
      project: server.project,
    );
  }

  Widget _buildFinishingAvatar({
    required AppColors colors,
    required ServerProfile server,
    required double progress,
  }) {
    final fadeProgress = Curves.easeInCubic.transform(
      ((progress - 0.16) / 0.26).clamp(0.0, 1.0),
    );
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 1 - fadeProgress,
          child: _buildAvatar(
            colors: colors,
            server: server,
            size: ServerSwitchTransitionMetrics.avatarSize,
          ),
        ),
      ),
    );
  }

  Widget _buildRevealMask({
    required bool isDark,
    required Size viewport,
    required double progress,
  }) {
    final center = ServerSwitchTransitionMetrics.center(viewport);
    final farthestCornerDistance = [
      (Offset.zero - center).distance,
      (Offset(viewport.width, 0) - center).distance,
      (Offset(0, viewport.height) - center).distance,
      (Offset(viewport.width, viewport.height) - center).distance,
    ].reduce(math.max);
    final radius = lerpDouble(
      ServerSwitchTransitionMetrics.avatarRadius,
      farthestCornerDistance + 2,
      Curves.easeOutCubic.transform(progress),
    )!;
    return CustomPaint(
      painter: _CircularRevealPainter(
        color: isDark ? const Color(0xFF101114) : const Color(0xFFF7F8FA),
        center: center,
        radius: radius,
      ),
      child: const SizedBox.expand(),
    );
  }

  /// checking 阶段：目标服务器头像加边框进度环，与选择页的加载语义一致。
  Widget _buildChecking(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
  ) {
    final profile = _cachedProfileFor(server);
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : server.name;
    return Column(
      key: const ValueKey('server-switch-checking'),
      children: [
        Text(
          '连接 $name',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.pageTitle(context).copyWith(fontSize: 25),
        ),
        const SizedBox(height: 16),
        Text(
          '正在检查服务器鉴权状态…',
          textAlign: TextAlign.center,
          style: AppText.body(
            context,
          ).copyWith(color: colors.muted, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildLogin(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
    bool requiresTotp,
    String? message,
  ) {
    final profile = _cachedProfileFor(server);
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : server.name;
    final error =
        (_localError?.trim().isNotEmpty == true ? _localError : message)
            ?.trim();
    // 头像由外层转场统一绘制在屏幕中心，表单从头像下方淡入，避免
    // 飞行头像交接到另一套纵向布局时发生跳变。
    return Column(
      key: const ValueKey('server-switch-login'),
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.pageTitle(context).copyWith(fontSize: 25),
        ),
        const SizedBox(height: 16),
        Text(
          requiresTotp ? '输入动态验证码完成切换。' : '请输入此服务器的密码继续。',
          textAlign: TextAlign.center,
          style: AppText.body(
            context,
          ).copyWith(color: colors.muted, fontSize: 15),
        ),
        const SizedBox(height: 24),
        if (requiresTotp) ...[
          TotpInputField(
            controller: _totpController,
            enabled: !_loginBusy,
            autofocus: true,
            onCompleted: (_) => _submitTotp(),
          ),
        ] else ...[
          _input(
            context,
            controller: _passwordController,
            label: '密码',
            obscureText: true,
            icon: Icons.key_outlined,
            enabled: !_loginBusy,
            onSubmitted: (_) => _submitLogin(),
          ),
        ],
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: ShakeErrorText(error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loginBusy
                ? null
                : requiresTotp
                ? _submitTotp
                : _submitLogin,
            icon: _loginBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    requiresTotp
                        ? Icons.verified_user_outlined
                        : Icons.login_rounded,
                  ),
            label: Text(
              _loginBusy
                  ? '验证中…'
                  : requiresTotp
                  ? '验证并切换'
                  : '登录并切换',
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loginBusy
              ? null
              : requiresTotp
              ? _backToPassword
              : _cancel,
          icon: Icon(
            requiresTotp ? Icons.arrow_back_rounded : Icons.close_rounded,
            size: 18,
          ),
          label: Text(requiresTotp ? '返回输入密码' : '取消切换'),
        ),
      ],
    );
  }

  Widget _buildError(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
    String? message,
  ) {
    final profile = _cachedProfileFor(server);
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : server.name;
    return Column(
      key: const ValueKey('server-switch-error'),
      children: [
        Text(
          '无法连接 $name',
          textAlign: TextAlign.center,
          style: AppText.pageTitle(context).copyWith(fontSize: 23),
        ),
        const SizedBox(height: 10),
        Text(
          message?.trim().isNotEmpty == true ? message! : '请检查网络或服务器配置。',
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: colors.muted),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('返回'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitLogin() async {
    final password = _passwordController.text;
    if (password.trim().isEmpty) {
      setState(() => _localError = '请输入密码');
      return;
    }
    setState(() {
      _loginBusy = true;
      _localError = null;
    });
    try {
      await ref
          .read(serverSwitchTransitionProvider.notifier)
          .login(password: password);
      if (!mounted) return;
      // 密码正确但服务器要求 TOTP：切换到验证码界面。
      final phase = ref.read(authControllerProvider).valueOrNull?.phase;
      if (phase == AuthPhase.totpRequired) {
        setState(() => _totpRequired = true);
      }
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  /// 密码验证通过后提交 TOTP 验证码。
  Future<void> _submitTotp() async {
    final totpCode = _totpController.text.trim();
    if (totpCode.length < totpCodeLength) {
      setState(() => _localError = '请输入 $totpCodeLength 位 TOTP 验证码');
      return;
    }
    setState(() {
      _loginBusy = true;
      _localError = null;
    });
    try {
      await ref
          .read(serverSwitchTransitionProvider.notifier)
          .login(password: _passwordController.text, totpCode: totpCode);
    } finally {
      if (mounted) {
        setState(() {
          _loginBusy = false;
          _totpController.clear();
        });
      }
    }
  }

  /// 返回密码表单，复位本地验证码状态。
  void _backToPassword() {
    setState(() {
      _totpRequired = false;
      _localError = null;
      _totpController.clear();
    });
  }

  Future<void> _retry() async {
    setState(() {
      _localError = null;
      _totpRequired = false;
      _totpController.clear();
    });
    await ref.read(serverSwitchTransitionProvider.notifier).retry();
  }

  Future<void> _cancel() async {
    if (_loginBusy) return;
    setState(() {
      _localError = null;
      _totpRequired = false;
      _totpController.clear();
    });
    await ref.read(serverSwitchTransitionProvider.notifier).cancel();
  }

  Widget _input(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool enabled,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? icon,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = appColors(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
      ),
    );
  }

  ServerProfile? _targetServer(ServerConfig? config, String? id) {
    if (config == null || id == null) return null;
    for (final server in config.servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }
}

class _CircularRevealPainter extends CustomPainter {
  const _CircularRevealPainter({
    required this.color,
    required this.center,
    required this.radius,
  });

  final Color color;
  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CircularRevealPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius;
  }
}

class _TransitionContent extends StatelessWidget {
  const _TransitionContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Column(
      key: ValueKey(title),
      children: [
        _TransitionIcon(icon: icon, colors: colors),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppText.pageTitle(context).copyWith(fontSize: 24),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

class _TransitionIcon extends StatelessWidget {
  const _TransitionIcon({required this.icon, required this.colors});

  final IconData icon;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.text,
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [Icon(icon, color: colors.bg, size: 36)],
        ),
      ),
    );
  }
}
