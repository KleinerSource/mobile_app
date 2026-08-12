import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/dio_factory.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';

/// 多服务器启动选择页。
///
/// 服务器使用横向滚动列表展示；选中没有本地会话的服务器后，仍留在本页
/// 完成登录，让头像和登录表单形成连续的 macOS 登录式过渡。
class ServerSelectionPage extends ConsumerStatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  ConsumerState<ServerSelectionPage> createState() =>
      _ServerSelectionPageState();
}

class _ServerSelectionPageState extends ConsumerState<ServerSelectionPage>
    with TickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _profileFutures = <String, Future<ServerProfileData?>>{};
  final _profiles = <String, ServerProfileData?>{};

  String? _selectedServerId;
  String? _selectingId;
  bool? _needsLogin;
  bool _authCheckPending = false;
  bool _loginBusy = false;
  bool _totpRequired = false;
  bool _transitionLocked = false;
  String? _error;
  ServerProfile? _transitionServer;
  String? _transitionDisplayName;
  String? _transitionAvatarUrl;
  Rect? _transitionFromRect;
  Rect? _transitionToRect;

  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;
  late final AnimationController _transitionController;
  late final Animation<double> _pickerOpacity;
  late final Animation<double> _detailOpacity;
  final _sceneKey = GlobalKey();
  final _detailAvatarKey = GlobalKey();
  final _pickerAvatarKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_entryOpacity);
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _pickerOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0, 0.42, curve: Curves.easeInCubic),
      ),
    );
    _detailOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.48, 1, curve: Curves.easeOutCubic),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _totpController.dispose();
    _entryController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    final selected = _selectedServerFor(servers);
    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
      final state = next.valueOrNull;
      if (!mounted || _selectedServerId == null || _authCheckPending) {
        return;
      }
      if (state == null) return;
      if (state.phase == AuthPhase.needsLogin ||
          state.phase == AuthPhase.totpRequired) {
        setState(() => _needsLogin = _requiresServerLogin(state));
      } else if (state.phase == AuthPhase.authenticated) {
        setState(() => _needsLogin = false);
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: AnimatedBuilder(
          animation: _transitionController,
          builder: (context, child) {
            final progress =
                _transitionController.value.clamp(0.0, 1.0).toDouble();
            final materialize = 4 * progress * (1 - progress);
            return Stack(
              key: _sceneKey,
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                if (materialize > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: 14 * materialize,
                            sigmaY: 14 * materialize,
                          ),
                          child: ColoredBox(
                            color: colors.bg.withValues(
                              alpha: 0.12 * materialize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_transitionFromRect != null &&
                    _transitionToRect != null &&
                    _transitionServer != null)
                  _buildSharedAvatar(colors, progress),
              ],
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: selected != null || _transitionLocked,
                child: FadeTransition(
                  opacity: _pickerOpacity,
                  child: _buildPickerScene(context, colors, servers),
                ),
              ),
              if (selected != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _transitionLocked,
                    child: FadeTransition(
                      opacity: _detailOpacity,
                      child: _buildDetailScene(
                        context,
                        colors,
                        selected,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSharedAvatar(AppColors colors, double progress) {
    final from = _transitionFromRect!;
    final to = _transitionToRect!;
    final left = ui.lerpDouble(from.left, to.left, progress)!;
    final top = ui.lerpDouble(from.top, to.top, progress)!;
    final width = ui.lerpDouble(from.width, to.width, progress)!;
    final scale = from.width == 0 ? 1.0 : width / from.width;
    return Positioned(
      left: from.left,
      top: from.top,
      width: from.width,
      height: from.height,
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(left - from.left, top - from.top),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              child: _ServerAvatar(
                displayName:
                    _transitionDisplayName ?? _transitionServer!.name,
                avatarUrl: _transitionAvatarUrl,
                size: from.width,
                busy: false,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerScene(
    BuildContext context,
    AppColors colors,
    List<ServerProfile> servers,
  ) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 42),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                SizedBox(
                  height: 108,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildBrand(context, colors),
                  ),
                ),
                const SizedBox(height: 44),
                _buildPicker(context, colors, servers),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailScene(
    BuildContext context,
    AppColors colors,
    ServerProfile selected,
  ) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 42),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                const SizedBox(height: 108),
                const SizedBox(height: 44),
                _needsLogin == true
                    ? _buildInlineLogin(context, colors, selected)
                    : _buildPendingServer(context, colors, selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ServerProfile? _selectedServerFor(List<ServerProfile> servers) {
    final id = _selectedServerId;
    if (id == null) return null;
    for (final server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  Widget _buildBrand(BuildContext context, AppColors colors) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.text,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.movie_filter_outlined, color: colors.bg, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          'MD Center',
          style: AppText.cardTitle(context).copyWith(
                fontSize: 17,
                letterSpacing: 0.2,
              ),
        ),
      ],
    );
  }

  Widget _buildPicker(
    BuildContext context,
    AppColors colors,
    List<ServerProfile> servers,
  ) {
    return Column(
      key: const ValueKey('server-picker'),
      children: [
        Text(
          '选择服务器',
          style: AppText.pageTitle(context).copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          '选择要连接的服务器',
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: colors.muted),
        ),
        const SizedBox(height: 32),
        _buildServerStrip(colors, servers),
      ],
    );
  }

  Widget _buildServerStrip(AppColors colors, List<ServerProfile> servers) {
    if (servers.isEmpty) {
      return Text('暂无可用服务器', style: AppText.body(context));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 132.0;
        const gap = 20.0;
        final gaps = servers.length > 1 ? servers.length - 1 : 0;
        final contentWidth = servers.length * itemWidth + gaps * gap;
        final horizontalPadding = contentWidth < constraints.maxWidth
            ? (constraints.maxWidth - contentWidth) / 2
            : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < servers.length; index++) ...[
                if (index > 0) const SizedBox(width: gap),
                FadeTransition(
                  opacity: _entryOpacity,
                  child: SlideTransition(
                    position: _entrySlide,
                    child: SizedBox(
                      width: itemWidth,
                      child: _ServerAvatarCard(
                        key: ValueKey(servers[index].id),
                        avatarKey: _pickerAvatarKeys.putIfAbsent(
                          servers[index].id,
                          () => GlobalKey(),
                        ),
                        server: servers[index],
                        profileFuture: _profileFor(servers[index]),
                        busy: _selectingId == servers[index].id,
                        hideAvatar: _transitionLocked &&
                            _transitionServer?.id == servers[index].id,
                        onTap: () => _selectServer(servers[index]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineLogin(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
  ) {
    final authValue = ref.watch(authControllerProvider);
    final auth = authValue.valueOrNull;
    final status = auth?.status;
    final requiresTotp = _totpRequired || auth?.phase == AuthPhase.totpRequired;
    final error = _error?.trim();
    final authError = auth?.message?.trim();
    final visibleError = error?.isNotEmpty == true
        ? error
        : authError?.isNotEmpty == true
            ? authError
            : null;

    return FutureBuilder<ServerProfileData?>(
      key: ValueKey('server-login-${server.id}'),
      future: _profileFor(server),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : server.name;
        final avatarUrl = profile?.avatarUrl ?? server.avatarUrl;
        final selecting = _selectingId != null ||
            (_needsLogin != true && authValue.isLoading);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              Opacity(
                opacity: _transitionLocked ? 0 : 1,
                child: _ServerAvatar(
                  key: _detailAvatarKey,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  size: 128,
                  busy: selecting || _loginBusy,
                  colors: colors,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.pageTitle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                status?.totpConfigured == true
                    ? '请输入密码和 TOTP 验证码继续。'
                    : '请输入此服务器的密码继续。',
                textAlign: TextAlign.center,
                style: AppText.body(context).copyWith(color: colors.muted),
              ),
              const SizedBox(height: 22),
              _loginField(
                context,
                controller: _passwordController,
                label: '密码',
                obscureText: true,
                enabled: !selecting && !_loginBusy,
                onSubmitted: (_) => _login(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: requiresTotp
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _loginField(
                          context,
                          controller: _totpController,
                          label: 'TOTP 验证码',
                          keyboardType: TextInputType.number,
                          enabled: !selecting && !_loginBusy,
                          onSubmitted: (_) => _login(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (visibleError != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    visibleError,
                    style: TextStyle(color: colors.danger, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selecting || _loginBusy ? null : _login,
                  icon: _loginBusy || selecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(selecting ? '连接中...' : '登录'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: selecting || _loginBusy ? null : _showServerList,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('选择其他服务器'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingServer(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
  ) {
    final displayName = _displayNameFor(server);
    final avatarUrl = _avatarUrlFor(server);
    return ConstrainedBox(
      key: ValueKey('server-pending-${server.id}'),
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        children: [
          Opacity(
            opacity: _transitionLocked ? 0 : 1,
            child: _ServerAvatar(
              key: _detailAvatarKey,
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: 128,
              busy: false,
              colors: colors,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.pageTitle(context).copyWith(fontSize: 24),
          ),
        ],
      ),
    );
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (_selectingId != null || _loginBusy || _transitionLocked) return;
    AppHaptics.medium();
    final sourceRect = _rectFor(_pickerAvatarKeys[server.id]);
    setState(() {
      _selectedServerId = server.id;
      _selectingId = server.id;
      _needsLogin = null;
      _authCheckPending = true;
      _totpRequired = false;
      _error = null;
      _transitionLocked = true;
      _transitionServer = server;
      _transitionDisplayName = _displayNameFor(server);
      _transitionAvatarUrl = _avatarUrlFor(server);
      _transitionFromRect = sourceRect;
      _transitionToRect = sourceRect;
      _passwordController.clear();
      _totpController.clear();
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final targetRect = _rectFor(_detailAvatarKey);
    setState(() {
      _transitionFromRect = sourceRect ?? targetRect;
      _transitionToRect = targetRect ?? sourceRect;
    });
    final selectFuture = ref
        .read(serverConfigProvider.notifier)
        .selectServer(server.id);
    // 配置保存与头像过渡并行，避免动画结束后才开始等待鉴权状态。
    final authFuture = () async {
      try {
        await selectFuture;
        if (!mounted) return null;
        ref.invalidate(authControllerProvider);
        return await ref.read(authControllerProvider.future);
      } catch (_) {
        // 启动错误由根路由统一展示；这里保持当前页面不误报切换失败。
        return null;
      }
    }();
    try {
      await _animateTransition(forward: true);
      await selectFuture;
      final authState = await authFuture;
      if (mounted) {
        setState(() {
          _selectingId = null;
          _authCheckPending = false;
          _needsLogin = authState == null
              ? null
              : _requiresServerLogin(authState);
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (!_transitionLocked) {
        final sourceRect = _rectFor(_detailAvatarKey);
        final targetRect = _rectFor(_pickerAvatarKeys[server.id]);
        setState(() {
          _transitionLocked = true;
          _transitionServer = server;
          _transitionDisplayName = _displayNameFor(server);
          _transitionAvatarUrl = _avatarUrlFor(server);
          _transitionFromRect = targetRect ?? sourceRect;
          _transitionToRect = sourceRect ?? targetRect;
        });
      }
      await _animateTransition(forward: false);
      if (!mounted) return;
      setState(() {
        _selectedServerId = null;
        _selectingId = null;
        _authCheckPending = false;
        _needsLogin = null;
        _error = '选择服务器失败：$error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择服务器失败：$error')),
      );
    }
  }

  Future<void> _login() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (_totpRequired && _totpController.text.trim().isEmpty) {
      setState(() => _error = '请输入 TOTP 验证码');
      return;
    }
    setState(() {
      _loginBusy = true;
      _error = null;
    });
    try {
      final authenticated = await ref.read(authControllerProvider.notifier).login(
            password: password,
            totpCode: _totpRequired ? _totpController.text : null,
          );
      if (mounted && !authenticated) {
        setState(() {
          _totpRequired = true;
          _error = '请输入 TOTP 验证码';
        });
      }
    } catch (error) {
      if (!mounted) return;
      final exception = toApiException(error);
      final status = ref.read(authControllerProvider).valueOrNull?.status;
      if (status?.passwordLoginDisabled == true) {
        setState(() => _error = '服务器已禁用密码登录，当前版本暂不支持 Passkey');
      } else {
        final message = exception.message.trim();
        setState(() {
          _error = message.isEmpty ? '登录失败，请检查密码或服务器连接' : message;
        });
      }
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  Future<void> _showServerList() async {
    if (_selectingId != null || _loginBusy || _transitionLocked) return;
    final server = _selectedServerFor(
      ref.read(serverConfigProvider)?.servers ?? const <ServerProfile>[],
    );
    if (server == null) return;
    AppHaptics.selection();
    final sourceRect = _rectFor(_detailAvatarKey);
    final targetRect = _rectFor(_pickerAvatarKeys[server.id]);
    setState(() {
      _transitionLocked = true;
      _transitionServer = server;
      _transitionDisplayName = _displayNameFor(server);
      _transitionAvatarUrl = _avatarUrlFor(server);
      _transitionFromRect = targetRect ?? sourceRect;
      _transitionToRect = sourceRect ?? targetRect;
      _authCheckPending = false;
    });
    await _animateTransition(forward: false);
    if (!mounted) return;
    setState(() {
      _selectedServerId = null;
      _selectingId = null;
      _needsLogin = null;
      _totpRequired = false;
      _error = null;
      _passwordController.clear();
      _totpController.clear();
    });
  }

  Future<void> _animateTransition({required bool forward}) async {
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _transitionController.value = forward ? 1 : 0;
    } else {
      final target = forward ? 1.0 : 0.0;
      const spring = SpringDescription(
        mass: 1,
        stiffness: 190,
        damping: 27,
      );
      try {
        await _transitionController
            .animateWith(
              SpringSimulation(
                spring,
                _transitionController.value,
                target,
                _transitionController.velocity,
              ),
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
      _transitionController.value = target;
    }
    if (!mounted) return;
    setState(() {
      _transitionLocked = false;
      _transitionServer = null;
      _transitionDisplayName = null;
      _transitionAvatarUrl = null;
      _transitionFromRect = null;
      _transitionToRect = null;
    });
  }

  Rect? _rectFor(GlobalKey? key) {
    final scene = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (scene == null || box == null || !scene.hasSize || !box.hasSize) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: scene);
    return origin & box.size;
  }

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
  }

  bool _requiresServerLogin(AuthState state) {
    final status = state.status;
    return status?.enabled == true &&
        status?.configured == true &&
        (state.phase == AuthPhase.needsLogin ||
            state.phase == AuthPhase.totpRequired);
  }

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final line = server.activeLine;
    if (line == null) return null;
    try {
      final profile = await ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
          servers: [server],
          activeServerId: server.id,
        ),
      ).systemExtended.serverProfile();
      _profiles[server.id] = profile;
      return profile;
    } catch (_) {
      // 兼容尚未提供服务器资料接口的旧后端，继续使用本地名称和首字母头像。
      _profiles[server.id] = null;
      return null;
    }
  }

  String _displayNameFor(ServerProfile server) {
    final name = _profiles[server.id]?.name.trim();
    return name?.isNotEmpty == true ? name! : server.name;
  }

  String? _avatarUrlFor(ServerProfile server) {
    return _profiles[server.id]?.avatarUrl ?? server.avatarUrl;
  }

  Widget _loginField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool enabled,
    bool obscureText = false,
    TextInputType? keyboardType,
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
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
      ),
    );
  }
}

class _ServerAvatarCard extends StatelessWidget {
  const _ServerAvatarCard({
    super.key,
    required this.avatarKey,
    required this.server,
    required this.profileFuture,
    required this.busy,
    required this.hideAvatar,
    required this.onTap,
  });

  final GlobalKey avatarKey;
  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final bool busy;
  final bool hideAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return FutureBuilder<ServerProfileData?>(
      future: profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : server.name;
        final avatarUrl = profile?.avatarUrl ?? server.avatarUrl;
        return Semantics(
          button: true,
          label: '选择$displayName',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : onTap,
              borderRadius: BorderRadius.circular(22),
              splashColor: colors.accent.withValues(alpha: 0.12),
              highlightColor: colors.accent.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  children: [
                    Opacity(
                      opacity: hideAvatar ? 0 : 1,
                      child: _ServerAvatar(
                        key: avatarKey,
                        displayName: displayName,
                        avatarUrl: avatarUrl,
                        size: 104,
                        busy: busy,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.cardTitle(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.size,
    required this.busy,
    required this.colors,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;
  final bool busy;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials(displayName),
        style: TextStyle(
          color: colors.surface,
          fontSize: size * 0.30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final sizeProgress = ((size - 104) / 24).clamp(0.0, 1.0).toDouble();
    final borderWidth = 4 + sizeProgress;
    final shadowBlur = 20 + (6 * sizeProgress);
    return AnimatedScale(
      scale: busy ? 0.94 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.accent.withValues(alpha: 0.95),
                    colors.accent.withValues(alpha: 0.52),
                  ],
                  ),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.2),
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(borderWidth),
                child: ClipOval(
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? fallback
                      : Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => fallback,
                        ),
                ),
              ),
            ),
            if (busy)
              Padding(
                padding: EdgeInsets.all(borderWidth),
                child: ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colors.surface,
                        strokeWidth: 2.5 + (0.3 * sizeProgress),
                      ),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.94),
                    width: borderWidth,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'S';
  final runes = trimmed.runes.toList();
  if (runes.length == 1) return String.fromCharCode(runes.first);
  return String.fromCharCodes(runes.take(2));
}
