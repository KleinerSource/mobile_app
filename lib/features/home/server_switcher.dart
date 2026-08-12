import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';

/// 首页右上角的服务器切换入口，只显示服务器头像和名称，不暴露线路地址。
class HomeServerSwitcher extends ConsumerWidget {
  const HomeServerSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final active = config?.activeServer;
    if (active == null) return const SizedBox.shrink();
    return _HomeServerSwitcherMenu(
      key: ValueKey(active.id),
      activeServer: active,
      servers: config!.servers,
    );
  }
}

class _HomeServerSwitcherMenu extends ConsumerStatefulWidget {
  const _HomeServerSwitcherMenu({
    super.key,
    required this.activeServer,
    required this.servers,
  });

  final ServerProfile activeServer;
  final List<ServerProfile> servers;

  @override
  ConsumerState<_HomeServerSwitcherMenu> createState() =>
      _HomeServerSwitcherMenuState();
}

class _HomeServerSwitcherMenuState
    extends ConsumerState<_HomeServerSwitcherMenu> {
  late Future<ServerProfileData?> _profileFuture;
  String? _selectingId;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile(widget.activeServer);
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
      return null;
    }
  }

  Future<void> _selectServer(String serverId) async {
    if (_selectingId != null || serverId == widget.activeServer.id) return;
    setState(() => _selectingId = serverId);
    AppHaptics.selection();
    try {
      await ref.read(serverConfigProvider.notifier).selectServer(serverId);
      ref.invalidate(authControllerProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换服务器失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _selectingId = null);
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
            : widget.activeServer.name;
        final avatarUrl = profile?.avatarUrl ?? widget.activeServer.avatarUrl;
        return PopupMenuButton<String>(
          enabled: _selectingId == null,
          tooltip: '切换服务器',
          offset: const Offset(0, 46),
          position: PopupMenuPosition.under,
          color: colors.surface,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder),
          ),
          onSelected: (serverId) => unawaited(_selectServer(serverId)),
          itemBuilder: (context) => [
            for (final server in widget.servers)
              PopupMenuItem<String>(
                value: server.id,
                child: _ServerMenuItem(
                  server: server,
                  active: server.id == widget.activeServer.id,
                  busy: server.id == _selectingId,
                ),
              ),
          ],
          child: AnimatedScale(
            scale: _selectingId == null ? 1 : 0.94,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ServerAvatar(
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  size: 36,
                  colors: colors,
                ),
                const SizedBox(width: 7),
                Icon(Icons.expand_more_rounded, color: colors.muted, size: 19),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServerMenuItem extends StatelessWidget {
  const _ServerMenuItem({
    required this.server,
    required this.active,
    required this.busy,
  });

  final ServerProfile server;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
      child: Row(
        children: [
          _ServerAvatar(
            displayName: server.name,
            avatarUrl: server.avatarUrl,
            size: 32,
            colors: colors,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              server.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(context).copyWith(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (active)
            Icon(Icons.check_rounded, color: colors.accent, size: 19),
        ],
      ),
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.size,
    required this.colors,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials(displayName),
        style: TextStyle(
          color: colors.surface,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
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
        border: Border.all(color: colors.surface.withValues(alpha: 0.85)),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? fallback
          : Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
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
