import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/dio_factory.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_session.dart';
import '../../core/auth/auth_session_provider.dart';
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
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  final _profileFutures = <String, Future<ServerProfileData?>>{};

  String? _selectedServerId;
  String? _selectingId;
  bool? _needsLogin;
  bool _loginBusy = false;
  bool _totpRequired = false;
  String? _error;

  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _totpController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    final selected = _selectedServerFor(servers);
    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
      final phase = next.valueOrNull?.phase;
      if (!mounted || _selectedServerId == null || _needsLogin == true) {
        return;
      }
      if (phase == AuthPhase.needsLogin || phase == AuthPhase.totpRequired) {
        setState(() => _needsLogin = true);
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 42),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    _buildBrand(context, colors),
                    const SizedBox(height: 44),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 460),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation);
                        final scale = Tween<double>(
                          begin: 0.92,
                          end: 1,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide,
                            child: ScaleTransition(scale: scale, child: child),
                          ),
                        );
                      },
                      child: selected == null
                          ? _buildPicker(context, colors, servers)
                          : _needsLogin == true
                              ? _buildInlineLogin(context, colors, selected)
                              : _buildConnecting(context, colors, selected),
                    ),
                  ],
                ),
              ),
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
                        server: servers[index],
                        profileFuture: _profileFor(servers[index]),
                        busy: _selectingId == servers[index].id,
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
              _ServerAvatar(
                displayName: displayName,
                avatarUrl: avatarUrl,
                size: 128,
                busy: selecting || _loginBusy,
                colors: colors,
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

  Widget _buildConnecting(
    BuildContext context,
    AppColors colors,
    ServerProfile server,
  ) {
    return FutureBuilder<ServerProfileData?>(
      key: ValueKey('server-connecting-${server.id}'),
      future: _profileFor(server),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : server.name;
        final avatarUrl = profile?.avatarUrl ?? server.avatarUrl;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              _ServerAvatar(
                displayName: displayName,
                avatarUrl: avatarUrl,
                size: 128,
                busy: true,
                colors: colors,
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
                '正在验证服务器…',
                style: AppText.body(context).copyWith(color: colors.muted),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (_selectingId != null || _loginBusy) return;
    AppHaptics.medium();
    setState(() {
      _selectedServerId = server.id;
      _selectingId = server.id;
      _needsLogin = null;
      _totpRequired = false;
      _error = null;
      _passwordController.clear();
      _totpController.clear();
    });

    try {
      final savedSession = await ref
          .read(authSessionRepositoryProvider)
          .forServer(server.id)
          .current();
      await ref.read(serverConfigProvider.notifier).selectServer(server.id);
      ref.invalidate(authControllerProvider);
      if (mounted) {
        setState(() {
          _selectingId = null;
          _needsLogin = savedSession == null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedServerId = null;
        _selectingId = null;
        _needsLogin = null;
        _error = '选择服务器失败：$error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择服务器失败：$error')),
      );
    } finally {
      // 有会话的服务器由 AuthController 继续验证；会话失效时表单会在
      // 同一页恢复可编辑状态，避免卡在连接中。
      if (mounted && _selectingId != null) {
        setState(() => _selectingId = null);
      }
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

  void _showServerList() {
    if (_selectingId != null || _loginBusy) return;
    AppHaptics.selection();
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

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
  }

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final line = server.activeLine;
    if (line == null) return null;
    try {
      return await ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
          servers: [server],
          activeServerId: server.id,
        ),
      ).systemExtended.serverProfile();
    } catch (_) {
      // 兼容尚未提供服务器资料接口的旧后端，继续使用本地名称和首字母头像。
      return null;
    }
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
    required this.server,
    required this.profileFuture,
    required this.busy,
    required this.onTap,
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final bool busy;
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
                    _ServerAvatar(
                      displayName: displayName,
                      avatarUrl: avatarUrl,
                      size: 104,
                      busy: busy,
                      colors: colors,
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
    return AnimatedScale(
      scale: busy ? 0.94 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Container(
        width: size,
        height: size,
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
          border: Border.all(
            color: colors.surface.withValues(alpha: 0.9),
            width: size > 110 ? 5 : 4,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withValues(alpha: 0.2),
              blurRadius: size > 110 ? 26 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            avatarUrl == null || avatarUrl!.isEmpty
                ? fallback
                : Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
            if (busy)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colors.surface,
                    strokeWidth: size > 110 ? 2.8 : 2.5,
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
