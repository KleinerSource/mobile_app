import 'dart:async';
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
import '../libraries/libraries_providers.dart';
import '../db_online/db_online_home_providers.dart';
import 'home_providers.dart';

enum ServerSwitchPhase { idle, checking, needsLogin, error }

@immutable
class ServerSwitchState {
  const ServerSwitchState._({
    required this.phase,
    this.targetServerId,
    this.previousServerId,
    this.message,
  });

  const ServerSwitchState.idle() : this._(phase: ServerSwitchPhase.idle);

  const ServerSwitchState.checking({
    required String targetServerId,
    String? previousServerId,
  }) : this._(
         phase: ServerSwitchPhase.checking,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
       );

  const ServerSwitchState.needsLogin({
    required String targetServerId,
    String? previousServerId,
    String? message,
  }) : this._(
         phase: ServerSwitchPhase.needsLogin,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         message: message,
       );

  const ServerSwitchState.error({
    required String targetServerId,
    String? previousServerId,
    required String message,
  }) : this._(
         phase: ServerSwitchPhase.error,
         targetServerId: targetServerId,
         previousServerId: previousServerId,
         message: message,
       );

  final ServerSwitchPhase phase;
  final String? targetServerId;
  final String? previousServerId;
  final String? message;

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
    final operation = ++_operation;
    state = ServerSwitchState.needsLogin(
      targetServerId: targetServerId,
      previousServerId: previousServerId,
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
      );
    } catch (error) {
      if (!_isCurrent(operation)) return;
      final exception = toApiException(error);
      state = ServerSwitchState.needsLogin(
        targetServerId: targetServerId,
        previousServerId: previousServerId,
        message: exception.message,
      );
    }
  }

  Future<void> retry() async {
    final current = state;
    final targetServerId = current.targetServerId;
    final previousServerId = current.previousServerId;
    if (!current.isActive || targetServerId == null) return;
    await switchTo(
      targetServerId,
      allowActiveTarget: true,
      previousServerIdOverride: previousServerId,
    );
  }

  Future<void> cancel() async {
    final current = state;
    final previousServerId = current.previousServerId;
    if (!current.isActive) return;
    final operation = ++_operation;
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
        );
        break;
      case AuthPhase.serverSelection:
      case AuthPhase.unconfigured:
        state = ServerSwitchState.error(
          targetServerId: targetServerId,
          previousServerId: previousServerId,
          message: '目标服务器配置无效，请重试或返回当前服务器',
        );
        break;
    }
    return Future<void>.value();
  }

  Future<void> _completeAuthenticatedSwitch(int operation) async {
    if (!_isCurrent(operation)) return;
    final project = ref.read(serverConfigProvider)?.activeServer?.project;
    if (project == ServerProject.dbOnline) {
      final refresh = Future.wait([
        ref.refresh(dbOnlineRecommendProvider.future),
        ref.refresh(dbOnlineLatestUpdatedProvider.future),
        ref.refresh(dbOnlineLatestReleasedProvider.future),
      ]);
      if (_isCurrent(operation)) {
        state = const ServerSwitchState.idle();
      }
      unawaited(refresh);
      return;
    }
    // 鉴权状态已经确认后立即解除遮罩。首页刷新在后台启动，避免未配置鉴权
    // 的服务器在清理旧会话或某个首页区块响应较慢时一直停留在检查状态。
    final refresh = refreshHomeProviders(
      refreshRecentlyAdded: () => ref.refresh(recentlyAddedProvider.future),
      refreshContinueWatching: () =>
          ref.refresh(continueWatchingProvider.future),
      refreshLibraries: () => ref.refresh(librariesProvider.future),
      refreshRecommendCarousel: () =>
          ref.refresh(recommendCarouselProvider.future),
    );
    if (_isCurrent(operation)) {
      state = const ServerSwitchState.idle();
    }
    unawaited(refresh);
  }

  Future<void> switchTo(
    String serverId, {
    bool allowActiveTarget = false,
    String? previousServerIdOverride,
  }) async {
    final current = ref.read(serverConfigProvider);
    if (current == null) return;
    if (current.activeServerId == serverId && !allowActiveTarget) return;
    if (state.isActive && !allowActiveTarget) return;

    final previousServerId = previousServerIdOverride ?? current.activeServerId;
    final operation = ++_operation;
    state = ServerSwitchState.checking(
      targetServerId: serverId,
      previousServerId: previousServerId,
    );
    try {
      if (current.activeServerId != serverId) {
        await ref.read(serverConfigProvider.notifier).selectServer(serverId);
      }
      if (!_isCurrent(operation)) return;
      final auth = await _refreshAuthState();
      if (!_isCurrent(operation)) return;
      await _applyAuthResult(
        auth,
        targetServerId: serverId,
        previousServerId: previousServerId,
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

/// 首页服务器切换的全屏材质层。底层主界面保持不变，目标服务器的探测和登录
/// 都在此层完成，因此不会短暂渲染服务器选择页。
class ServerSwitchTransitionOverlay extends ConsumerStatefulWidget {
  const ServerSwitchTransitionOverlay({super.key});

  @override
  ConsumerState<ServerSwitchTransitionOverlay> createState() =>
      _ServerSwitchTransitionOverlayState();
}

class _ServerSwitchTransitionOverlayState
    extends ConsumerState<ServerSwitchTransitionOverlay> {
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  bool _loginBusy = false;
  bool _totpRequired = false;
  String? _localError;

  @override
  void dispose() {
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transition = ref.watch(serverSwitchTransitionProvider);
    if (!transition.isActive) return const SizedBox.shrink();

    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final target = _targetServer(config, transition.targetServerId);
    if (target == null) {
      return _buildMaterial(
        context,
        const _TransitionContent(
          icon: Icons.dns_outlined,
          title: '服务器配置无效',
          message: '无法找到目标服务器，请返回后重试。',
        ),
      );
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
      ServerSwitchPhase.idle => const SizedBox.shrink(),
    };

    return _buildMaterial(context, content);
  }

  Widget _buildMaterial(BuildContext context, Widget content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColoredBox(
                color: (isDark ? Colors.black : Colors.white).withValues(
                  alpha: isDark ? 0.62 : 0.72,
                ),
              ),
            ),
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Colors.transparent,
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
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
                ),
              ),
            ),
          ],
        ),
      ),
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
        ServerAvatar(
          displayName: name,
          avatarUrl: profile?.avatarUrl ?? server.avatarUrl,
          size: 112,
          busy: true,
          colors: colors,
        ),
        const SizedBox(height: 20),
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
    final avatar = profile?.avatarUrl ?? server.avatarUrl;
    final error =
        (_localError?.trim().isNotEmpty == true ? _localError : message)
            ?.trim();
    // 布局与服务器选择页的详情场景保持一致：头像 136、名字 25 号、
    // 副标题/表单间距同节奏，登录动画结束后的最终位置与选择页统一。
    return Column(
      key: const ValueKey('server-switch-login'),
      children: [
        ServerAvatar(
          displayName: name,
          avatarUrl: avatar,
          size: 136,
          busy: _loginBusy,
          colors: colors,
        ),
        const SizedBox(height: 20),
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
        ServerAvatar(
          displayName: name,
          avatarUrl: profile?.avatarUrl ?? server.avatarUrl,
          size: 96,
          colors: colors,
        ),
        const SizedBox(height: 18),
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
