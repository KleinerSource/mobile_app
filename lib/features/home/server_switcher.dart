import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/system.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass_menu.dart';
import '../../shared/server_avatar.dart';
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
  final _avatarKey = GlobalKey();

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    final cached = _cachedProfileFor(server);
    if (server.project != ServerProject.ohMyMedia) {
      return ServerProfileData(name: server.name, avatarUrl: server.avatarUrl);
    }
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
    final avatarContext = _avatarKey.currentContext;
    final renderObject = avatarContext?.findRenderObject();
    final avatarOrigin = renderObject is RenderBox && renderObject.hasSize
        ? Rect.fromLTWH(
            renderObject.localToGlobal(Offset.zero).dx,
            renderObject.localToGlobal(Offset.zero).dy,
            renderObject.size.width,
            renderObject.size.height,
          )
        : null;
    await ref
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(serverId, avatarOrigin: avatarOrigin);
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
          child: DecoratedBox(
            key: _avatarKey,
            decoration: BoxDecoration(
              // 首页入口位于海报/背景图上，使用中性磨砂底板承接透明头像，
              // 避免底层画面直接穿透；头像本身不恢复紫色渐变背景。
              color: colors.sheetBackground,
              shape: BoxShape.circle,
            ),
            child: ServerAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: 36,
              colors: colors,
              project: widget.activeServer.project,
              showBackground: false,
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

/// 构建可挂载到底部导航 Tab 的服务器快捷菜单。
///
/// 底部导航只需要服务器配置中的静态头像信息；首页右上角仍可继续使用
/// [HomeServerSwitcher] 的远程资料加载逻辑。
List<GlassMenuEntry<T>> buildServerQuickSwitchEntries<T>({
  required BuildContext context,
  required List<ServerProfile> servers,
  required String? activeServerId,
  required String? selectingServerId,
  required T Function(String serverId) valueFor,
}) {
  final colors = appColors(context);
  return [
    for (final server in servers)
      GlassMenuEntry<T>.action(
        value: valueFor(server.id),
        builder: (context, selected, onTap) {
          final displayName = server.name.trim().isEmpty
              ? '服务器'
              : server.name.trim();
          final active = server.id == activeServerId;
          final busy = server.id == selectingServerId;
          return GlassMenuRow(
            label: displayName,
            leading: ServerAvatar(
              displayName: displayName,
              avatarUrl: server.avatarUrl,
              size: 34,
              colors: colors,
              project: server.project,
              showBackground: false,
            ),
            selected: selected,
            onTap: active || busy ? null : onTap,
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
      ),
  ];
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
          leading: ServerAvatar(
            displayName: displayName,
            avatarUrl: avatarUrl,
            size: 34,
            colors: colors,
            project: server.project,
            showBackground: false,
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
