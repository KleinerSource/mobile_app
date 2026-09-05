import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session_provider.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/api/dio_factory.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/files/file_source_config.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/reorder_slot_feedback.dart';
import '../../shared/server_avatar.dart';
import '../../shared/swipe_actions.dart';
import 'server_lines_page.dart';
import 'server_setup_page.dart';
import 'settings_common.dart';

class ServerListPage extends ConsumerStatefulWidget {
  const ServerListPage({super.key});

  @override
  ConsumerState<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends ConsumerState<ServerListPage> {
  /// 当前左滑展开的服务器行，同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  final _scrollController = ScrollController();

  /// 拖拽跨行换位时的槽位触感，见 [ReorderSlotFeedback]。
  final _slotFeedback = ReorderSlotFeedback();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_closeSwipeOnScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(serverConfigProvider.notifier).refreshOpenListVersions(),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _scrollController.dispose();
    _slotFeedback.endDrag();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: l.settingsGroupServer,
              title: l.settingsServerList,
              subtitle: l.serverListSubtitle,
              trailing: SettingsAddButton(onPressed: () => _showServerEditor()),
            ),
            // 服务器数量少且有界：设置页式分组卡，行间细分隔线；与收藏
            // 列表一致，整行长按可拖动调序，顺序对所有服务器选择入口生效。
            body: servers.isEmpty
                ? ListView(controller: _scrollController)
                : ReorderableListView.builder(
                    itemCount: servers.length,
                    scrollController: _scrollController,
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                    proxyDecorator: _dragProxyDecorator,
                    onReorderStart: (index) {
                      AppHaptics.light();
                      _slotFeedback.startDrag(servers[index].id, index);
                    },
                    onReorderEnd: (_) => _slotFeedback.endDrag(),
                    onReorderItem: (oldIndex, newIndex) {
                      AppHaptics.medium();
                      ref
                          .read(serverConfigProvider.notifier)
                          .reorderServers(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final server = servers[index];
                      final isFirst = index == 0;
                      final isLast = index == servers.length - 1;
                      // 分组卡按行拆分：首行圆上角、末行圆下角，行间靠行顶
                      // 分隔线衔接，拼起来与整卡视觉一致。
                      final radius = BorderRadius.vertical(
                        top: isFirst ? const Radius.circular(16) : Radius.zero,
                        bottom: isLast
                            ? const Radius.circular(16)
                            : Radius.zero,
                      );
                      return ReorderableRowGeometry(
                        key: ValueKey<String>(server.id),
                        rowId: server.id,
                        onRegister: _slotFeedback.registerRow,
                        onUnregister: _slotFeedback.unregisterRow,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: radius,
                            border: Border(
                              top: isFirst
                                  ? BorderSide(color: colors.cardBorder)
                                  : BorderSide.none,
                              bottom: isLast
                                  ? BorderSide(color: colors.cardBorder)
                                  : BorderSide.none,
                              left: BorderSide(color: colors.cardBorder),
                              right: BorderSide(color: colors.cardBorder),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: radius,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isFirst)
                                  Divider(height: 1, color: colors.divider),
                                SwipeActionCell(
                                  group: _openSwipe,
                                  cellKey: server.id,
                                  enabled: true,
                                  actions: _serverSwipeActions(
                                    colors,
                                    server,
                                    servers.length,
                                  ),
                                  child: _ServerListCard(
                                    server: server,
                                    active: server.id == config?.activeServerId,
                                    onTap: () => _openServer(server),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// 拖拽跟随卡片：按拖拽起落进度浮起投影，与分组卡的圆角保持一致。
  Widget _dragProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final elevation = Curves.easeOut.transform(animation.value) * 6;
        return Material(
          color: Colors.transparent,
          shadowColor: Colors.black,
          elevation: elevation,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
    );
  }

  /// 单个服务器的左滑操作集：仅剩一台服务器时不可删除。
  List<SwipeActionData> _serverSwipeActions(
    AppColors colors,
    ServerProfile server,
    int count,
  ) {
    final l = AppL10n.of(context);
    return [
      SwipeActionData(
        icon: Icons.edit_outlined,
        label: l.serverEditAction,
        color: colors.accent,
        onPressed: () => _showServerEditor(existing: server),
      ),
      if (server.project?.isFileSource != true)
        SwipeActionData(
          icon: Icons.alt_route_outlined,
          label: l.serverManageLines,
          color: AppHues.top(AppHues.sky),
          onPressed: () => _openLines(server),
        ),
      if (count > 1)
        SwipeActionData(
          icon: Icons.delete_outline,
          label: l.delete,
          color: colors.danger,
          onPressed: () => _deleteServer(server),
        ),
    ];
  }

  void _openLines(ServerProfile server) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServerLinesPage(serverId: server.id)),
    );
  }

  void _openServer(ServerProfile server) {
    if (server.project?.isFileSource == true) {
      _showServerEditor(existing: server);
      return;
    }
    _openLines(server);
  }

  Future<void> _showServerEditor({ServerProfile? existing}) async {
    final l = AppL10n.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServerSetupPage(
          editing: existing != null,
          serverId: existing?.id,
          title: existing == null ? l.serverAddTitle : l.serverEditAction,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    AppHaptics.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? AppL10n.of(context).serverAdded
              : AppL10n.of(context).serverUpdated,
        ),
      ),
    );
  }

  FileSourceConfig? _findFileSourceConfig(String serverId) {
    for (final config
        in ref.read(fileSourceConfigRepositoryProvider).loadAll()) {
      if (config.serverId == serverId) return config;
    }
    return null;
  }

  Future<void> _deleteServer(ServerProfile server) async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.serverDeleteTitle),
        content: Text(l.serverDeleteBody(server.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(serverConfigProvider.notifier).deleteServer(server.id);
      await ref.read(stashApiKeyRepositoryProvider).delete(server.id);
      final fileSource = _findFileSourceConfig(server.id);
      if (fileSource != null) {
        await ref
            .read(fileSourceConfigRepositoryProvider)
            .delete(fileSource.id);
        final reference = fileSource.credentialRef.trim();
        await ref
            .read(fileSourceCredentialsRepositoryProvider)
            .delete(reference);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(
                context,
              ).serverDeleteFailed(toApiException(error).message),
            ),
          ),
        );
      }
    }
  }
}

class _ServerListCard extends StatelessWidget {
  const _ServerListCard({
    required this.server,
    required this.active,
    required this.onTap,
  });

  final ServerProfile server;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    // 分组连排行：透明背景，由外层分组容器提供表面，沿用设置页行布局。
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        splashColor: colors.accent.withValues(alpha: 0.14),
        highlightColor: colors.accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              ServerAvatar(
                displayName: server.name,
                avatarUrl: server.project == ServerProject.ohMyMedia
                    ? null
                    : server.avatarUrl,
                size: 42,
                colors: colors,
                project: server.project,
                showBackground: false,
                showBorder: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      server.name,
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        l.serverLineCount(server.lines.length),
                        if (server.project != null)
                          _serverProjectLabel(l, server.project)
                        else if (server.projectName?.isNotEmpty == true)
                          server.projectName!,
                        if (server.serverVersion?.isNotEmpty == true)
                          server.serverVersion!,
                      ].join(' · '),
                      style: AppText.meta(context),
                    ),
                  ],
                ),
              ),
              if (active)
                _ActiveChip(color: colors.accent)
              else
                Icon(Icons.chevron_right, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

String _serverProjectLabel(AppL10n l, ServerProject? project) {
  return switch (project) {
    ServerProject.ohMyMedia => 'Oh My Media',
    ServerProject.dbOnline => 'DB Online',
    ServerProject.emby => 'Emby',
    ServerProject.jellyfin => 'Jellyfin',
    ServerProject.feiniu => l.serverProjectFeiniu,
    ServerProject.stash => 'Stash',
    ServerProject.smb => 'SMB',
    ServerProject.webDav => 'WebDAV',
    ServerProject.openList => 'OpenList',
    null => l.serverProjectDefault,
  };
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          AppL10n.of(context).serverCurrent,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
