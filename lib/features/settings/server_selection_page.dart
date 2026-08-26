import 'dart:async';
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

  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;
  late final AnimationController _brandController;
  late final Animation<double> _brandEntry;
  late final Animation<Offset> _brandEntrySlide;
  late final AnimationController _transitionController;
  late final Animation<double> _pickerOpacity;
  late final Animation<double> _detailOpacity;
  // 详情表单分级入场：输入框 → 登录按钮 → 返回按钮依次自下滑入。
  late final AnimationController _formEntry;
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
    _formEntry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
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
    _formEntry.dispose();
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
                // 不做缩放退后：场景内卡片必须始终位于未缩放布局位置，
                // 飞行头像/名字的落点测量才与重现位置严格一致，落位交接
                // 不会出现跳变。过渡的层次感由模糊与淡入承担。
                child: FadeTransition(
                  opacity: _pickerOpacity,
                  child: _buildPickerScene(context, colors, servers),
                ),
              ),
              if (selected != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _transitionLocked,
                    // 只做淡入：场景内元素位置必须与共享元素飞行落点的
                    // 测量一致，任何场景级位移都会让头像/名字落位后二次移动。
                    child: FadeTransition(
                      opacity: _detailOpacity,
                      child: _buildDetailScene(context, colors, selected),
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
    // 头像+名字固定在场景纵向偏上位置（Stack 绝对定位），表单挂在下方；
    // 表单出现、切换或报错都不会改变头像落点。
    //
    // 纵向位置与首页服务器切换浮层的登录界面（内容整块垂直居中的布局）
    // 对齐：浮层头像中心 ≈ 高度中点上方 136px，此处用相同的居中公式
    // 反推 headerTop（136 头像 + 20 间距 + 名字行 ≈ 182 的内容高度）。
    const headerHeight = 182.0;
    const avatarCenterOffset = 204.0;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final headerTop = math.max(24.0, height / 2 - avatarCenterOffset);
          final stackHeight = math.max(
            height,
            headerTop + headerHeight + 344,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: stackHeight,
              child: _needsLogin == true
                  ? _buildInlineLogin(context, colors, selected, headerTop)
                  : _buildPendingServer(
                      context,
                      colors,
                      selected,
                      headerTop,
                    ),
            ),
          );
        },
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
                        server: servers[index],
                        profileFuture: _profileFor(servers[index]),
                        cachedProfile: _cachedProfileFor(servers[index]),
                        busy: _selectingId == servers[index].id,
                        hideAvatar:
                            _transitionLocked &&
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
    double headerTop,
  ) {
    final authValue = ref.watch(authControllerProvider);
    final auth = authValue.valueOrNull;
    // 验证码界面完全由本地状态驱动：服务端返回 totp_required 时置位，
    // 「返回输入密码」时复位。provider 的 totpRequired 阶段在密码验证
    // 失败后会一直保持，不能作为界面切换依据，否则无法返回密码表单。
    final requiresTotp = _totpRequired;
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
        // 头像+名字绝对定位在 headerTop（场景纵向中心），表单固定挂在
        // 下方；表单出现、切换或报错都不会改变头像落点。
        final headerHeight = 182.0;
        final body = SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: headerTop,
                height: headerHeight,
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
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.pageTitle(
                        context,
                      ).copyWith(fontSize: 25),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: headerTop + headerHeight + 16,
                // 表单入场完全由 _formEntry 分级滑入驱动（过渡结束后播放），
                // 不再叠加场景级淡入，避免"出现→闪没→再滑入"的卡顿感。
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

  /// 详情表单分级入场包装：输入框 → 按钮 → 返回按钮依次自下滑入。
  Widget _formStagger(int index, Widget child) {
    // 每级延迟 90ms，滑入 24px。
    final start = Interval(0.18 * index, 1, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _formEntry,
      builder: (context, child) {
        final t = start.transform(_formEntry.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }

  /// 密码表单：验证通过且服务器开启 TOTP 时切换到验证码界面。
  Widget _buildPasswordForm(
    BuildContext context,
    AppColors colors,
    bool selecting,
    String? visibleError,
  ) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final totpConfigured = auth?.status?.totpConfigured == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formStagger(
          0,
          Text(
            totpConfigured ? '密码验证通过后可能需要动态验证码。' : '请输入此服务器的密码继续。',
            textAlign: TextAlign.center,
            style: AppText.body(
              context,
            ).copyWith(color: colors.muted, fontSize: 15),
          ),
        ),
        const SizedBox(height: 24),
        _formStagger(
          1,
          _loginField(
            context,
            controller: _passwordController,
            label: '密码',
            obscureText: true,
            icon: Icons.key_outlined,
            enabled: !selecting && !_loginBusy,
            onSubmitted: (_) => _login(),
          ),
        ),
        if (visibleError != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ShakeErrorText(visibleError),
          ),
        ],
        const SizedBox(height: 20),
        _formStagger(
          2,
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
        ),
        const SizedBox(height: 8),
        _formStagger(
          3,
          Center(
            child: TextButton.icon(
              onPressed: selecting || _loginBusy ? null : _showServerList,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('选择其他服务器'),
            ),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formStagger(
          0,
          Text(
            '输入动态验证码完成登录。',
            textAlign: TextAlign.center,
            style: AppText.body(
              context,
            ).copyWith(color: colors.muted, fontSize: 15),
          ),
        ),
        const SizedBox(height: 24),
        _formStagger(
          1,
          TotpInputField(
            controller: _totpController,
            enabled: !selecting && !_loginBusy,
            autofocus: true,
            onCompleted: (_) => _submitTotp(),
          ),
        ),
        if (visibleError != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ShakeErrorText(visibleError),
          ),
        ],
        const SizedBox(height: 20),
        _formStagger(
          2,
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
        ),
        const SizedBox(height: 8),
        _formStagger(
          3,
          Center(
            child: TextButton.icon(
              onPressed: selecting || _loginBusy
                  ? null
                  : () {
                      setState(() {
                        _totpRequired = false;
                        _error = null;
                        _totpController.clear();
                      });
                      _formEntry.forward(from: 0);
                    },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('返回输入密码'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingServer(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
    double headerTop,
  ) {
    final displayName = _displayNameFor(server);
    final avatarUrl = _avatarUrlFor(server);
    const headerHeight = 182.0;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: headerTop,
            height: headerHeight,
            child: Column(
              children: [
                Opacity(
                  opacity: _transitionLocked ? 0 : 1,
                  child: ServerAvatar(
                    key: _detailAvatarKey,
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    size: 136,
                    busy: false,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageTitle(context).copyWith(fontSize: 25),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: headerTop + headerHeight + 16,
            child: Text(
              '正在检查服务器鉴权状态…',
              textAlign: TextAlign.center,
              style: AppText.body(context).copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (_selectingId != null || _loginBusy || _transitionLocked) return;
    AppHaptics.medium();
    final sourceRect = _pickerRectFor(_pickerAvatarKeys[server.id]);
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
        final targetRect = _pickerRectFor(_pickerAvatarKeys[server.id]);
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
      setState(() => _totpRequired = true);
      unawaited(_formEntry.forward(from: 0));
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
    final targetRect = _pickerRectFor(_pickerAvatarKeys[server.id]);
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
    });
    if (forward) {
      // 过渡完成后表单分级滑入（输入框 → 按钮 → 返回按钮）。
      unawaited(_formEntry.forward(from: 0));
    } else {
      _formEntry.value = 0;
    }
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

  /// 选择场景内元素的测量。场景不做缩放/位移，视觉位置即布局位置，
  /// 飞行落点与卡片重现位置天然一致。
  Rect? _pickerRectFor(GlobalKey? key) => _rectFor(key);

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
    required this.server,
    required this.profileFuture,
    required this.cachedProfile,
    required this.busy,
    required this.hideAvatar,
    required this.onTap,
  });

  final GlobalKey avatarKey;
  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
  final bool busy;
  final bool hideAvatar;
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
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.cardTitle(
                        context,
                      ).copyWith(fontSize: 15),
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
