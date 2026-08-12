import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';

/// 多服务器启动选择页，采用类似 macOS 登录界面的居中头像选择布局。
class ServerSelectionPage extends ConsumerStatefulWidget {
  const ServerSelectionPage({super.key});

  @override
  ConsumerState<ServerSelectionPage> createState() =>
      _ServerSelectionPageState();
}

class _ServerSelectionPageState extends ConsumerState<ServerSelectionPage>
    with SingleTickerProviderStateMixin {
  String? _selectingId;
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
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];

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
                    const SizedBox(height: 48),
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
                    _buildServerGrid(context, colors, servers),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildServerGrid(
    BuildContext context,
    AppColors colors,
    List<ServerProfile> servers,
  ) {
    if (servers.isEmpty) {
      return Text('暂无可用服务器', style: AppText.body(context));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 20,
          children: [
            for (final server in servers)
              SizedBox(
                width: width,
                child: FadeTransition(
                  opacity: _entryOpacity,
                  child: SlideTransition(
                    position: _entrySlide,
                    child: _ServerAvatarCard(
                      key: ValueKey(server.id),
                      server: server,
                      busy: _selectingId == server.id,
                      onTap: () => _selectServer(server),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (_selectingId != null) return;
    setState(() => _selectingId = server.id);
    AppHaptics.medium();
    try {
      await ref.read(serverConfigProvider.notifier).selectServer(server.id);
      ref.invalidate(authControllerProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择服务器失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _selectingId = null);
    }
  }
}

class _ServerAvatarCard extends StatefulWidget {
  const _ServerAvatarCard({
    super.key,
    required this.server,
    required this.busy,
    required this.onTap,
  });

  final ServerProfile server;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_ServerAvatarCard> createState() => _ServerAvatarCardState();
}

class _ServerAvatarCardState extends State<_ServerAvatarCard> {
  late Future<ServerProfileData?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<ServerProfileData?> _loadProfile() async {
    final line = widget.server.activeLine;
    if (line == null) return null;
    try {
      return await ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
        ),
      ).systemExtended.serverProfile();
    } catch (_) {
      // 兼容尚未提供服务器资料接口的旧后端，继续使用本地名称。
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return FutureBuilder<ServerProfileData?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : widget.server.name;
        final avatarUrl = profile?.avatarUrl ?? widget.server.avatarUrl;
        return Semantics(
          button: true,
          label: '选择$displayName',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.busy ? null : widget.onTap,
              borderRadius: BorderRadius.circular(22),
              splashColor: colors.accent.withValues(alpha: 0.12),
              highlightColor: colors.accent.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: widget.busy ? 0.96 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
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
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accent.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildAvatar(
                              colors,
                              displayName,
                              avatarUrl,
                            ),
                            if (widget.busy)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: colors.surface,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildAvatar(
    AppColors colors,
    String displayName,
    String? avatarUrl,
  ) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Center(
        child: Text(
          _initials(displayName),
          style: TextStyle(
            color: colors.surface,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return Center(
            child: Text(
              _initials(displayName),
              style: TextStyle(
                color: colors.surface,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            _initials(displayName),
            style: TextStyle(
              color: colors.surface,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'S';
    final runes = trimmed.runes.toList();
    if (runes.length == 1) return String.fromCharCode(runes.first);
    return String.fromCharCodes(runes.take(2));
  }
}
