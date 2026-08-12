import 'dart:async';
import 'dart:ui' as ui;

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
  final _profileFutures = <String, Future<ServerProfileData?>>{};
  String? _selectingId;

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

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
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
      future: _profileFor(widget.activeServer),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : widget.activeServer.name;
        final avatarUrl = profile?.avatarUrl ?? widget.activeServer.avatarUrl;
        return PopupMenuButton<String>(
          enabled: _selectingId == null,
          tooltip: '切换服务器',
          offset: const Offset(0, 4),
          position: PopupMenuPosition.under,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (serverId) => unawaited(_selectServer(serverId)),
          itemBuilder: (context) => [
            _ServerMenuEntry(
              servers: widget.servers,
              activeServerId: widget.activeServer.id,
              selectingId: _selectingId,
              profileFor: _profileFor,
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

class _ServerMenuEntry extends PopupMenuEntry<String> {
  const _ServerMenuEntry({
    required this.servers,
    required this.activeServerId,
    required this.selectingId,
    required this.profileFor,
  });

  final List<ServerProfile> servers;
  final String activeServerId;
  final String? selectingId;
  final Future<ServerProfileData?> Function(ServerProfile server) profileFor;

  @override
  double get height => servers.length * 48.0 + 12;

  @override
  bool represents(String? value) => false;

  @override
  State<_ServerMenuEntry> createState() => _ServerMenuEntryState();
}

class _ServerMenuEntryState extends State<_ServerMenuEntry> {
  @override
  Widget build(BuildContext context) {
    return _ServerMenuPanel(
      servers: widget.servers,
      activeServerId: widget.activeServerId,
      selectingId: widget.selectingId,
      profileFor: widget.profileFor,
    );
  }
}

class _ServerMenuPanel extends StatelessWidget {
  const _ServerMenuPanel({
    required this.servers,
    required this.activeServerId,
    required this.selectingId,
    required this.profileFor,
  });

  final List<ServerProfile> servers;
  final String activeServerId;
  final String? selectingId;
  final Future<ServerProfileData?> Function(ServerProfile server) profileFor;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final menuWidth = _serverMenuWidth(servers);
    return SizedBox(
      width: menuWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bg.withValues(alpha: 0.38),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final server in servers)
                    _ServerMenuRow(
                      server: server,
                      profileFuture: profileFor(server),
                      active: server.id == activeServerId,
                      busy: server.id == selectingId,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _serverMenuWidth(List<ServerProfile> servers) {
  var maxNameLength = 0;
  for (final server in servers) {
    final nameLength = server.name.trim().runes.length;
    if (nameLength > maxNameLength) maxNameLength = nameLength;
  }

  // 头像、间距和状态图标占用固定空间，名称长度决定剩余宽度。
  return (maxNameLength * 15.0 + 92.0).clamp(148.0, 224.0).toDouble();
}

class _ServerMenuRow extends StatelessWidget {
  const _ServerMenuRow({
    required this.server,
    required this.profileFuture,
    required this.active,
    required this.busy,
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final bool active;
  final bool busy;

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
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy || active
                ? null
                : () => Navigator.of(context).pop(server.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  _ServerAvatar(
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    size: 34,
                    colors: colors,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(context).copyWith(
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
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
    required this.colors,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final borderWidth = size >= 36 ? 2.2 : 2.0;
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
    return SizedBox(
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
