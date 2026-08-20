import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass_menu.dart';
import 'server_switch_transition.dart';

/// 首页右上角的服务器切换入口，只显示服务器头像，不暴露线路地址。
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

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final cached = _cachedProfileFor(server);
    final line = server.activeLine;
    if (line == null) return cached;
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
      return profile;
    } catch (_) {
      return cached;
    }
  }

  ServerProfileData? _cachedProfileFor(ServerProfile server) {
    return ref.read(serverProfileCacheRepoProvider).load(server.id);
  }

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
  }

  Future<void> _selectServer(String serverId) async {
    await ref.read(serverSwitchTransitionProvider.notifier).switchTo(serverId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final transition = ref.watch(serverSwitchTransitionProvider);
    final selectingId = transition.isActive ? transition.targetServerId : null;
    return FutureBuilder<ServerProfileData?>(
      future: _profileFor(widget.activeServer),
      initialData: _cachedProfileFor(widget.activeServer),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : widget.activeServer.name;
        final avatarUrl = profile?.avatarUrl ?? widget.activeServer.avatarUrl;
        return GlassMenuAnchor<String>(
          width: _serverMenuWidth(widget.servers),
          enabled: !transition.isActive,
          tooltip: '切换服务器',
          offset: const Offset(0, 4),
          placement: GlassMenuPlacement.below,
          onSelected: (serverId) => unawaited(_selectServer(serverId)),
          initialSelection: widget.activeServer.id,
          entries: [
            for (final server in widget.servers)
              GlassMenuEntry<String>.action(
                value: server.id,
                builder: (context, selected, onTap) => _ServerMenuRow(
                  server: server,
                  profileFuture: _profileFor(server),
                  cachedProfile: _cachedProfileFor(server),
                  active: server.id == widget.activeServer.id,
                  selected: selected,
                  busy: server.id == selectingId,
                  onTap: onTap,
                ),
              ),
          ],
          child: AnimatedScale(
            scale: transition.isActive ? 0.94 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _ServerAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: 36,
              colors: colors,
            ),
          ),
        );
      },
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
    required this.cachedProfile,
    required this.active,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final ServerProfile server;
  final Future<ServerProfileData?> profileFuture;
  final ServerProfileData? cachedProfile;
  final bool active;
  final bool selected;
  final bool busy;
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
        return GlassMenuRow(
          label: displayName,
          leading: _ServerAvatar(
            displayName: displayName,
            avatarUrl: avatarUrl,
            size: 34,
            colors: colors,
          ),
          selected: selected,
          onTap: busy || active ? null : onTap,
          trailing: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : active
                  ? Icon(Icons.check_rounded, color: colors.accent, size: 19)
                  : null,
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
    final fallbackForeground = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : colors.surface;
    final fallback = Center(
      child: Text(
        _initials(displayName),
        style: TextStyle(
          color: fallbackForeground,
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
                    : CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => fallback,
                        errorWidget: (_, __, ___) => fallback,
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
