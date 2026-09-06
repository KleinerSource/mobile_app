import 'package:omm/shared/server_presentation.dart';
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
import '../../core/config/server_profile_runtime_loader.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/server_avatar.dart';
import '../../shared/shake_error_text.dart';
import '../../shared/totp_input_field.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_config.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/settings/server_selection_display_settings.dart';
import 'package:omm/features/settings/server_setup_page.dart';
import 'home_providers.dart';

part 'server_switch_controller.dart';

part 'server_switch_widgets.dart';

part 'server_switch_auth_view.dart';

class ServerSwitchTransitionOverlay extends ConsumerStatefulWidget {
  const ServerSwitchTransitionOverlay({super.key});

  @override
  ConsumerState<ServerSwitchTransitionOverlay> createState() =>
      _ServerSwitchTransitionOverlayState();
}

class _ServerSwitchTransitionOverlayState
    extends ConsumerState<ServerSwitchTransitionOverlay>
    with SingleTickerProviderStateMixin {
  void _updateViewState(VoidCallback update) => setState(update);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _authScrollController = ScrollController();
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
  bool _authScrollResetScheduled = false;

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
    _usernameController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _authScrollController.dispose();
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
      final l = AppL10n.of(context);
      return _buildMaterial(
        context,
        _TransitionContent(
          icon: Icons.dns_outlined,
          title: l.homeSwitchTargetMissingTitle,
          message: l.homeSwitchTargetMissingMessage,
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
      ServerSwitchPhase.needsApiKey => _buildApiKeyRequired(
        context,
        colors,
        target,
        transition.message,
      ),
      ServerSwitchPhase.error => _buildError(
        context,
        colors,
        target,
        transition,
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
    _finishController.stop();
    _finishController.value = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finishingServerId != targetServerId) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _finishController.value = 1;
        _entryController.value = 1;
        _handoffController.value = 1;
        ref.read(serverSwitchTransitionProvider.notifier).finishTransition();
        return;
      }
      if (_entryController.value < 1) {
        unawaited(
          _entryController.forward().then((_) {
            if (mounted && _finishingServerId == targetServerId) {
              _handoffController.value = 1;
              _startFinishAnimation(targetServerId);
            }
          }),
        );
      } else {
        _entryController.value = 1;
        _handoffController.value = 1;
        _startFinishAnimation(targetServerId);
      }
    });
  }

  void _startFinishAnimation(String targetServerId) {
    if (!mounted || _finishingServerId != targetServerId) return;
    unawaited(
      _finishController.forward().then((_) {
        if (mounted && _finishingServerId == targetServerId) {
          ref.read(serverSwitchTransitionProvider.notifier).finishTransition();
        }
      }),
    );
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
    final showUserAvatar = ref.watch(serverSelectionShowAvatarProvider);
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
                        revealStarted: _entryController.value >= 1,
                      ),
                      const Positioned.fill(
                        child: ModalBarrier(
                          dismissible: false,
                          color: Colors.transparent,
                        ),
                      ),
                      if (target != null &&
                          localEntryOrigin != null &&
                          _entryController.value < 1)
                        _buildEntryAvatar(
                          colors: appColors(context),
                          server: target,
                          showUserAvatar: showUserAvatar,
                          origin: localEntryOrigin,
                          destination: ServerSwitchTransitionMetrics.avatarRect(
                            constraints.biggest,
                          ),
                          progress: entryProgress,
                          opacity: 1,
                        )
                      else if (target != null)
                        _buildFinishingAvatar(
                          colors: appColors(context),
                          server: target,
                          showUserAvatar: showUserAvatar,
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
                          showUserAvatar: showUserAvatar,
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
                      child: _buildContentViewport(
                        constraints: constraints,
                        content: content,
                        contentOpacity: contentOpacity,
                        showAvatar:
                            _entryOrigin == null || _entryController.value >= 1,
                        showUserAvatar: showUserAvatar,
                        colors: appColors(context),
                        server: target,
                        busy:
                            transition.phase == ServerSwitchPhase.checking ||
                            _loginBusy,
                      ),
                    ),
                    if (!isFinishing &&
                        target != null &&
                        localEntryOrigin != null &&
                        _entryController.value < 1)
                      _buildEntryAvatar(
                        colors: appColors(context),
                        server: target,
                        showUserAvatar: showUserAvatar,
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
            },
          );
        },
      ),
    );
  }

  Widget _buildContentViewport({
    required BoxConstraints constraints,
    required Widget content,
    required double contentOpacity,
    required bool showAvatar,
    required bool showUserAvatar,
    required AppColors colors,
    required ServerProfile? server,
    required bool busy,
  }) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardBottom == 0) _scheduleAuthScrollReset();
    // 头像和鉴权控件属于同一个滚动组。键盘弹出时视口本身随键盘上收
    // （而不只是加大滚动 padding），头像与表单在剩余可见区域重新居中，
    // 同时让焦点输入框的自动滚入可视区逻辑按真实可见范围生效。
    final visibleHeight = constraints.biggest.height - keyboardBottom;
    final avatarTop = math.max(
      24.0,
      visibleHeight / 2 - ServerSwitchTransitionMetrics.avatarRadius,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: SizedBox.expand(
        child: SingleChildScrollView(
          controller: _authScrollController,
          primary: false,
          padding: EdgeInsets.fromLTRB(24, avatarTop, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                children: [
                  if (server != null && showAvatar) ...[
                    _buildAvatar(
                      colors: colors,
                      server: server,
                      size: ServerSwitchTransitionMetrics.avatarSize,
                      showUserAvatar: showUserAvatar,
                      busy: busy,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Opacity(
                    opacity: contentOpacity,
                    child: AnimatedSwitcher(
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleAuthScrollReset() {
    if (_authScrollResetScheduled) return;
    _authScrollResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authScrollResetScheduled = false;
      if (!mounted || !_authScrollController.hasClients) return;
      if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
      final position = _authScrollController.position;
      if (position.pixels <= position.minScrollExtent) return;
      unawaited(
        _authScrollController.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Widget _buildEntryAvatar({
    required AppColors colors,
    required ServerProfile server,
    required bool showUserAvatar,
    required Rect origin,
    required Rect destination,
    required double progress,
    required double opacity,
  }) {
    final profile = _cachedProfileFor(server);
    final name = serverDisplayName(server, profile);
    final rect = Rect.lerp(origin, destination, progress)!;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ServerAvatar(
            displayName: name,
            avatarUrl: serverSwitchTransitionAvatarUrl(
              server: server,
              profile: profile,
              showUserAvatar: showUserAvatar,
            ),
            size: rect.width,
            colors: colors,
            project: server.project,
            showBackground: false,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required AppColors colors,
    required ServerProfile server,
    required double size,
    required bool showUserAvatar,
    bool busy = false,
  }) {
    final profile = _cachedProfileFor(server);
    final name = serverDisplayName(server, profile);
    return ServerAvatar(
      displayName: name,
      avatarUrl: serverSwitchTransitionAvatarUrl(
        server: server,
        profile: profile,
        showUserAvatar: showUserAvatar,
      ),
      size: size,
      busy: busy,
      colors: colors,
      project: server.project,
      showBackground: false,
    );
  }

  Widget _buildFinishingAvatar({
    required AppColors colors,
    required ServerProfile server,
    required bool showUserAvatar,
    required double progress,
  }) {
    final fadeProgress = Curves.easeOutCubic.transform(
      ((progress - 0.06) / 0.24).clamp(0.0, 1.0),
    );
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 1 - fadeProgress,
          child: _buildAvatar(
            colors: colors,
            server: server,
            size: ServerSwitchTransitionMetrics.avatarSize,
            showUserAvatar: showUserAvatar,
          ),
        ),
      ),
    );
  }

  Widget _buildRevealMask({
    required bool isDark,
    required Size viewport,
    required double progress,
    required bool revealStarted,
  }) {
    final color = isDark ? const Color(0xFF101114) : const Color(0xFFF7F8FA);
    if (!revealStarted) return ColoredBox(color: color);

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
      // [progress] 在 _buildMaterial 中已经使用 easeInCubic，保持单一
      // 加速曲线，避免再叠加反向曲线后抵消成近似匀速。
      progress,
    )!;
    return CustomPaint(
      painter: _CircularRevealPainter(
        color: color,
        center: center,
        radius: radius,
      ),
      child: const SizedBox.expand(),
    );
  }

  /// checking 阶段：目标服务器头像加边框进度环，与选择页的加载语义一致。

  /// Notifier 无法本地化固定文案，按 messageKind 解析成展示文本。

  /// 密码验证通过后提交 TOTP 验证码。

  /// 返回密码表单，复位本地验证码状态。

  ServerProfile? _targetServer(ServerConfig? config, String? id) {
    if (config == null || id == null) return null;
    for (final server in config.servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    if (server.project == ServerProject.ohMyMedia) return null;
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }
}
