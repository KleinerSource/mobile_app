import 'dart:math' as math;
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
import '../../shared/server_avatar.dart';
import '../../shared/shake_error_text.dart';
import '../../shared/totp_input_field.dart';

/// 多服务器启动选择页。
///
/// 服务器使用横向滚动列表展示，滚动视口延伸到屏幕边缘，卡片不会在
/// 内容区边界被切边；选中没有本地会话的服务器后，仍留在本页完成
/// 登录，让头像和登录表单形成连续的 macOS 登录式过渡。
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
  Rect? _transitionNameFromRect;
  Rect? _transitionNameToRect;

  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;
  late final AnimationController _brandController;
  late final Animation<double> _brandEntry;
  late final Animation<Offset> _brandEntrySlide;
  late final AnimationController _transitionController;
  late final Animation<double> _pickerOpacity;
  late final Animation<double> _detailOpacity;
  final _sceneKey = GlobalKey();
  final _detailAvatarKey = GlobalKey();
  final _detailNameKey = GlobalKey();
  final _pickerAvatarKeys = <String, GlobalKey>{};
  final _pickerNameKeys = <String, GlobalKey>{};

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
    _brandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _brandEntry = CurvedAnimation(
      parent: _brandController,
      curve: Curves.easeOutCubic,
    );
    _brandEntrySlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_brandEntry);
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
      if (!mounted) return;
      _brandController.forward();
      // 品牌区先落位，标题与头像卡片随后浮现，形成分级入场节奏。
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (mounted) _entryController.forward();
      });
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _totpController.dispose();
    _entryController.dispose();
    _brandController.dispose();
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
            final progress = _transitionController.value
                .clamp(0.0, 1.0)
                .toDouble();
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
                    _transitionServer != null) ...[
                  _buildSharedAvatar(colors, progress),
                  if (_transitionNameFromRect != null)
                    _buildSharedName(colors, progress),
                ],
              ],
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: selected != null || _transitionLocked,
                child: AnimatedBuilder(
                  animation: _transitionController,
                  builder: (context, child) {
                    // 过渡前半段列表轻微缩小退后，轴心取起飞头像中心，
                    // 保证飞行起点在过渡全程保持原位（返回不抖动）。
                    final t = (_transitionController.value / 0.55).clamp(
                      0.0,
                      1.0,
                    );
                    final scale = 1 - 0.06 * Curves.easeInCubic.transform(t);
                    final pivot = _transitionPivot;
                    final sceneBox =
                        _sceneKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (pivot == null ||
                        sceneBox == null ||
                        !sceneBox.hasSize) {
                      return Transform.scale(scale: scale, child: child);
                    }
                    final origin = pivot - Offset(
                      sceneBox.size.width / 2,
                      sceneBox.size.height / 2,
                    );
                    return Transform.scale(
                      scale: scale,
                      origin: origin,
                      child: child,
                    );
                  },
                  child: FadeTransition(
                    opacity: _pickerOpacity,
                    child: _buildPickerScene(context, colors, servers),
                  ),
                ),
              ),
              if (selected != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _transitionLocked,
                    child: AnimatedBuilder(
                      animation: _transitionController,
                      builder: (context, child) => Transform.translate(
                        // 详情场景跟随淡入自下浮入，与头像落点衔接。
                        offset: Offset(0, 26 * (1 - _detailOpacity.value)),
                        child: child,
                      ),
                      child: FadeTransition(
                        opacity: _detailOpacity,
                        child: _buildDetailScene(context, colors, selected),
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

  /// 列表缩放退后的轴心取起飞头像中心：飞行起点在过渡全程保持原位，
  /// 返回时头像先落位、场景再恢复，不会出现卡片回位后的横向抖动。
  Offset? get _transitionPivot {
    final from = _transitionFromRect;
    if (from == null) return null;
    return Offset(from.center.dx, from.center.dy);
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
              child: ServerAvatar(
                displayName: _transitionDisplayName ?? _transitionServer!.name,
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

  /// 服务器名称跟随头像一起飞行：位置在卡片名与详情名之间插值，
  /// 字号与字距同步缩放，两端与场景内名字样式完全一致，落位无缝交接。
  Widget _buildSharedName(AppColors colors, double progress) {
    final from = _transitionNameFromRect!;
    final to = _transitionNameToRect ?? from;
    final left = ui.lerpDouble(from.left, to.left, progress)!;
    final top = ui.lerpDouble(from.top, to.top, progress)!;
    final width = ui.lerpDouble(from.width, to.width, progress)!;
    final height = ui.lerpDouble(from.height, to.height, progress)!;
    final style = AppText.cardTitle(context).copyWith(
      fontWeight: FontWeight.w800,
      fontSize: ui.lerpDouble(15, 25, progress),
      letterSpacing: ui.lerpDouble(-0.14, -0.84, progress),
    );
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Center(
          child: Text(
            _transitionDisplayName ?? _transitionServer!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
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
    // 水平内边距下沉到各分区，服务器横向列表的滚动视口才能铺满到屏幕边缘。
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 48, bottom: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 122,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: _brandEntry,
                    child: SlideTransition(
                      position: _brandEntrySlide,
                      child: _buildBrand(context, colors),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildPicker(context, colors, servers),
            ],
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
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                const SizedBox(height: 122),
                const SizedBox(height: 40),
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
        // 品牌 logo 为无透明通道的位图，用圆角裁剪遮罩呈现应用图标质感。
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/branding/oh_my_media_logo.png',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Oh-My-Media',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Oh-My-Media',
          style: AppText.cardTitle(
            context,
          ).copyWith(fontSize: 18, letterSpacing: 0.3),
        ),
      ],
    );
  }

  Widget _buildPicker(
    BuildContext context,
    AppColors colors,
    List<ServerProfile> servers,
  ) {
    final single = servers.length == 1;
    return Column(
      key: const ValueKey('server-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Text(
                  single ? '连接服务器' : '选择服务器',
                  style: AppText.pageTitle(context).copyWith(fontSize: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  single ? '点击头像，输入密码连接' : '选择要连接的服务器',
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    context,
                  ).copyWith(color: colors.muted, fontSize: 15),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
        _buildServerStrip(colors, servers),
        if (single) ...[
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _entryOpacity,
            child: Center(
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(serverConfigProvider.notifier).beginEdit(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('编辑服务器地址'),
                style: TextButton.styleFrom(foregroundColor: colors.muted),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServerStrip(AppColors colors, List<ServerProfile> servers) {
    if (servers.isEmpty) {
      return Text(
        '暂无可用服务器',
        textAlign: TextAlign.center,
        style: AppText.body(context),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 140.0;
        const gap = 22.0;
        const restingInset = 24.0;
        final gaps = servers.length > 1 ? servers.length - 1 : 0;
        final contentWidth = servers.length * itemWidth + gaps * gap;
        // 停靠时首尾卡片与标题保持同样的边距，滚动时卡片一直延伸到屏幕边缘。
        final horizontalPadding = contentWidth < constraints.maxWidth
            ? math.max(restingInset, (constraints.maxWidth - contentWidth) / 2)
            : restingInset;
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
                        nameKey: _pickerNameKeys.putIfAbsent(
                          servers[index].id,
                          () => GlobalKey(),
                        ),
                        server: servers[index],
                        profileFuture: _profileFor(servers[index]),
                        cachedProfile: _cachedProfileFor(servers[index]),
                        busy: _selectingId == servers[index].id,
                        hideAvatar:
                            _transitionLocked &&
                            _transitionServer?.id == servers[index].id,
                        hideName:
                            _transitionNameFromRect != null &&
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
      initialData: _cachedProfileFor(server),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : server.name;
        final avatarUrl = profile?.avatarUrl ?? server.avatarUrl;
        final selecting =
            _selectingId != null ||
            (_needsLogin != true && authValue.isLoading);
        final body = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              Opacity(
                opacity: _transitionLocked ? 0 : 1,
                child: ServerAvatar(
                  key: _detailAvatarKey,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  size: 136,
                  busy: selecting || _loginBusy,
                  colors: colors,
                ),
              ),
              const SizedBox(height: 20),
              // 名字飞行期间由飞行层展示名字，落位后本场景名字淡入。
              AnimatedBuilder(
                animation: _transitionController,
                builder: (context, child) {
                  final flying = _transitionLocked;
                  final reveal = flying
                      ? Curves.easeOutCubic
                            .transform(
                              ((_transitionController.value - 0.85) / 0.15)
                                  .clamp(0.0, 1.0),
                            )
                      : 1.0;
                  return Opacity(opacity: reveal, child: child);
                },
                child: Text(
                  key: _detailNameKey,
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageTitle(context).copyWith(fontSize: 25),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                requiresTotp
                    ? '输入动态验证码完成登录。'
                    : status?.totpConfigured == true
                    ? '密码验证通过后可能需要动态验证码。'
                    : '请输入此服务器的密码继续。',
                textAlign: TextAlign.center,
                style: AppText.body(
                  context,
                ).copyWith(color: colors.muted, fontSize: 15),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _transitionController,
                builder: (context, child) {
                  // 表单在过渡后段自下浮入，与名字落位形成级联节奏。
                  final t = ((_transitionController.value - 0.45) / 0.55)
                      .clamp(0.0, 1.0);
                  final eased = Curves.easeOutCubic.transform(t);
                  return Opacity(
                    opacity: eased,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - eased)),
                      child: child,
                    ),
                  );
                },
                child: requiresTotp
                    ? _buildTotpForm(context, colors, selecting, visibleError)
                    : _buildPasswordForm(
                        context,
                        colors,
                        selecting,
                        visibleError,
                      ),
              ),
            ],
          ),
        );
        return body;
      },
    );
  }

  /// 密码表单：验证通过且服务器开启 TOTP 时切换到验证码界面。
  Widget _buildPasswordForm(
    BuildContext context,
    AppColors colors,
    bool selecting,
    String? visibleError,
  ) {
    return Column(
      children: [
        _loginField(
          context,
          controller: _passwordController,
          label: '密码',
          obscureText: true,
          icon: Icons.key_outlined,
          enabled: !selecting && !_loginBusy,
          onSubmitted: (_) => _login(),
        ),
        if (visibleError != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ShakeErrorText(visibleError),
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
    );
  }

  /// TOTP 界面：不再显示密码框，验证码输满自动提交。
  Widget _buildTotpForm(
    BuildContext context,
    AppColors colors,
    bool selecting,
    String? visibleError,
  ) {
    return Column(
      children: [
        TotpInputField(
          controller: _totpController,
          enabled: !selecting && !_loginBusy,
          autofocus: true,
          onCompleted: (_) => _submitTotp(),
        ),
        if (visibleError != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ShakeErrorText(visibleError),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: selecting || _loginBusy ? null : _submitTotp,
            icon: _loginBusy || selecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(selecting ? '连接中...' : '验证并登录'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: selecting || _loginBusy
              ? null
              : () {
                  setState(() {
                    _totpRequired = false;
                    _error = null;
                    _totpController.clear();
                  });
                },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('返回输入密码'),
        ),
      ],
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
            child: ServerAvatar(
              key: _detailAvatarKey,
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: 128,
              busy: false,
              colors: colors,
            ),
          ),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _transitionController,
            builder: (context, child) {
              final flying = _transitionLocked;
              final reveal = flying
                  ? Curves.easeOutCubic.transform(
                      ((_transitionController.value - 0.85) / 0.15).clamp(
                        0.0,
                        1.0,
                      ),
                    )
                  : 1.0;
              return Opacity(opacity: reveal, child: child);
            },
            child: Text(
              key: _detailNameKey,
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.pageTitle(context).copyWith(fontSize: 25),
            ),
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
    final (nameFrom, nameTo) = _nameFlightRects(server);
    setState(() {
      _transitionFromRect = sourceRect ?? targetRect;
      _transitionToRect = targetRect ?? sourceRect;
      _transitionNameFromRect = nameFrom;
      _transitionNameToRect = nameTo;
    });
    final selectFuture = ref
        .read(serverConfigProvider.notifier)
        .selectServer(server.id);
    // 配置保存与头像过渡并行，避免动画结束后才开始等待鉴权状态。
    final authFuture = () async {
      try {
        await selectFuture;
        if (!mounted) return null;
        return await ref
            .read(authControllerProvider.notifier)
            .refreshCurrentServer()
            .timeout(const Duration(seconds: 12));
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
        final (nameFrom, nameTo) = _nameFlightRects(server);
        setState(() {
          _transitionLocked = true;
          _transitionServer = server;
          _transitionDisplayName = _displayNameFor(server);
          _transitionAvatarUrl = _avatarUrlFor(server);
          _transitionFromRect = targetRect ?? sourceRect;
          _transitionToRect = sourceRect ?? targetRect;
          _transitionNameFromRect = nameFrom;
          _transitionNameToRect = nameTo;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择服务器失败：$error')));
    }
  }

  Future<void> _login() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    setState(() {
      _loginBusy = true;
      _error = null;
    });
    try {
      final authenticated = await ref
          .read(authControllerProvider.notifier)
          .login(password: password);
      if (!mounted) return;
      if (authenticated) {
        AppHaptics.medium();
        return;
      }
      setState(() => _error = '请输入 TOTP 验证码');
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
      AppHaptics.light();
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  /// 密码验证通过后提交 TOTP 验证码。
  Future<void> _submitTotp() async {
    final totpCode = _totpController.text.trim();
    if (totpCode.length < totpCodeLength) {
      setState(() => _error = '请输入 $totpCodeLength 位 TOTP 验证码');
      return;
    }
    setState(() {
      _loginBusy = true;
      _error = null;
    });
    try {
      final authenticated = await ref
          .read(authControllerProvider.notifier)
          .login(password: _passwordController.text, totpCode: totpCode);
      if (!mounted) return;
      if (authenticated) {
        AppHaptics.medium();
        return;
      }
      setState(() {
        _totpController.clear();
        _error = '验证码不正确，请重试';
      });
    } catch (error) {
      if (!mounted) return;
      final exception = toApiException(error);
      final message = exception.message.trim();
      setState(() {
        _totpController.clear();
        _error = message.isEmpty ? '验证失败，请重试' : message;
      });
      AppHaptics.light();
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
    final (nameFrom, nameTo) = _nameFlightRects(server);
    setState(() {
      _transitionLocked = true;
      _transitionServer = server;
      _transitionDisplayName = _displayNameFor(server);
      _transitionAvatarUrl = _avatarUrlFor(server);
      _transitionFromRect = targetRect ?? sourceRect;
      _transitionToRect = sourceRect ?? targetRect;
      _transitionNameFromRect = nameFrom;
      _transitionNameToRect = nameTo;
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
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _transitionController.value = forward ? 1 : 0;
    } else {
      final target = forward ? 1.0 : 0.0;
      const spring = SpringDescription(mass: 1, stiffness: 190, damping: 27);
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
      _transitionNameFromRect = null;
      _transitionNameToRect = null;
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

  /// 名字飞行矩形：起点为卡片名，终点为详情名；缺起点时以详情名位置、
  /// 头像宽度合成，缺终点时以起点位置合成，保证任一侧缺失也能飞行。
  (Rect?, Rect?) _nameFlightRects(ServerProfile server) {
    final pickerName = _rectFor(_pickerNameKeys[server.id]);
    final detailName = _rectFor(_detailNameKey);
    if (pickerName != null && detailName != null) {
      return (pickerName, detailName);
    }
    if (detailName != null) {
      final avatarFrom = _transitionFromRect;
      final width = avatarFrom?.width ?? detailName.width;
      return (
        Rect.fromCenter(
          center: detailName.center,
          width: width,
          height: detailName.height,
        ),
        detailName,
      );
    }
    if (pickerName != null) {
      final avatarTo = _transitionToRect;
      final width = avatarTo?.width ?? pickerName.width;
      return (
        pickerName,
        Rect.fromCenter(
          center: pickerName.center,
          width: width,
          height: pickerName.height,
        ),
      );
    }
    return (null, null);
  }

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
  }

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }

  bool _requiresServerLogin(AuthState state) {
    final status = state.status;
    return status?.enabled == true &&
        status?.configured == true &&
        (state.phase == AuthPhase.needsLogin ||
            state.phase == AuthPhase.totpRequired);
  }

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final cached = _cachedProfileFor(server);
    final line = server.activeLine;
    if (line == null) {
      _profiles[server.id] = cached;
      return cached;
    }
    try {
      final profile = await ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
          servers: [server],
          activeServerId: server.id,
        ),
      ).systemExtended.serverProfile();
      await ref.read(serverProfileCacheRepoProvider).save(server.id, profile);
      _profiles[server.id] = profile;
      return profile;
    } catch (_) {
      // 兼容尚未提供服务器资料接口的旧后端，继续使用本地名称和首字母头像。
      _profiles[server.id] = cached;
      return cached;
    }
  }

  String _displayNameFor(ServerProfile server) {
    final profile = _profiles[server.id] ?? _cachedProfileFor(server);
    final name = profile?.name.trim();
    return name?.isNotEmpty == true ? name! : server.name;
  }

  String? _avatarUrlFor(ServerProfile server) {
    return (_profiles[server.id] ?? _cachedProfileFor(server))?.avatarUrl ??
        server.avatarUrl;
  }

  Widget _loginField(
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
}

class _ServerAvatarCard extends StatelessWidget {
  const _ServerAvatarCard({
    super.key,
    required this.avatarKey,
    required this.nameKey,
    required this.server,
    required this.profileFuture,
    required this.cachedProfile,
    required this.busy,
    required this.hideAvatar,
    required this.hideName,
    required this.onTap,
  });

  final GlobalKey avatarKey;
  final GlobalKey nameKey;
  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
  final bool busy;
  final bool hideAvatar;
  final bool hideName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return FutureBuilder<ServerProfileData?>(
      future: profileFuture,
      initialData: cachedProfile,
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
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Column(
                  children: [
                    Opacity(
                      opacity: hideAvatar ? 0 : 1,
                      child: ServerAvatar(
                        key: avatarKey,
                        displayName: displayName,
                        avatarUrl: avatarUrl,
                        size: 116,
                        busy: busy,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 名字飞行期间隐藏卡片名，避免与飞行层重影；保留占位。
                    Opacity(
                      opacity: hideName ? 0 : 1,
                      child: Text(
                        key: nameKey,
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.cardTitle(
                          context,
                        ).copyWith(fontSize: 15),
                      ),
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
