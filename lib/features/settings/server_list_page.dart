import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/files/file_source_config.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../shared/glow_background.dart';
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

  /// 行几何注册表（serverId → 行 context），拖拽期间按帧读取各行的
  /// RenderBox 位置，用于估算拖拽落点槽位。
  final Map<String, BuildContext> _rowContexts = {};
  String? _draggingServerId;
  BuildContext? _dragProxyContext;
  int _lastDragSlot = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  void _registerRow(String serverId, BuildContext context) {
    _rowContexts[serverId] = context;
  }

  /// 守卫式注销：同名行可能正在 overlay 代理与列表间迁移，只移除自己的注册。
  void _unregisterRow(String serverId, BuildContext context) {
    if (_rowContexts[serverId] == context) _rowContexts.remove(serverId);
  }

  /// 拖拽期间每帧估算落点槽位：拖拽行（overlay 中的代理）中心越过哪台
  /// 服务器，就落在哪个位置；槽位变化时给一次与左滑阈值一致的轻反馈。
  void _scheduleReorderSlotTick() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _tickReorderSlot());
  }

  void _tickReorderSlot() {
    final serverId = _draggingServerId;
    if (serverId == null || !mounted) return;
    // 首帧注册的一定是 overlay 中的拖拽代理；代理卸载说明拖拽已被取消
    // 或落定（取消路径不触发 onReorderEnd，靠 mounted 自愈停止轮询）。
    final proxyContext = _dragProxyContext ??= _rowContexts[serverId];
    final proxyBox = proxyContext?.findRenderObject();
    if (proxyContext == null ||
        !proxyContext.mounted ||
        proxyBox is! RenderBox ||
        !proxyBox.attached) {
      _draggingServerId = null;
      _dragProxyContext = null;
      return;
    }
    final proxyCenter =
        proxyBox.localToGlobal(Offset.zero).dy + proxyBox.size.height / 2;
    var slot = 0;
    for (final entry in _rowContexts.entries) {
      if (entry.key == serverId) continue;
      final box = entry.value.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final center = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
      if (proxyCenter > center) slot++;
    }
    if (slot != _lastDragSlot) {
      _lastDragSlot = slot;
      AppHaptics.selection();
    }
    _scheduleReorderSlotTick();
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
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: '服务器',
              title: '服务器列表',
              subtitle: '每台服务器可单独配置线路，启动时选择服务器。',
              trailing: SettingsAddButton(onPressed: () => _showServerEditor()),
            ),
            // 服务器数量少且有界：设置页式分组卡，行间细分隔线；拖动行尾
            // 手柄可调整顺序，顺序对所有服务器选择入口生效。
            body: servers.isEmpty
                ? ListView(controller: _scrollController)
                : ReorderableListView.builder(
                    itemCount: servers.length,
                    buildDefaultDragHandles: false,
                    scrollController: _scrollController,
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                    proxyDecorator: _dragProxyDecorator,
                    onReorderStart: (index) {
                      AppHaptics.light();
                      _draggingServerId = servers[index].id;
                      _dragProxyContext = null;
                      _lastDragSlot = index;
                      _scheduleReorderSlotTick();
                    },
                    onReorderEnd: (_) {
                      _draggingServerId = null;
                      _dragProxyContext = null;
                    },
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
                        top: isFirst
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottom: isLast ? const Radius.circular(16) : Radius.zero,
                      );
                      return _ReorderRowGeometry(
                        key: ValueKey<String>(server.id),
                        serverId: server.id,
                        onRegister: _registerRow,
                        onUnregister: _unregisterRow,
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
                                    handle: ReorderableDragStartListener(
                                      index: index,
                                      child: GestureDetector(
                                        // 手柄只用于拖动，吞掉点按避免误触发行点击。
                                        onTap: () {},
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 10,
                                          ),
                                          child: Icon(
                                            Icons.drag_indicator,
                                            color: colors.muted,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
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
    return [
      SwipeActionData(
        icon: Icons.edit_outlined,
        label: '编辑服务器',
        color: colors.accent,
        onPressed: () => _showServerEditor(existing: server),
      ),
      if (server.project?.isFileSource != true)
        SwipeActionData(
          icon: Icons.alt_route_outlined,
          label: '管理线路',
          color: AppHues.top(AppHues.sky),
          onPressed: () => _openLines(server),
        ),
      if (count > 1)
        SwipeActionData(
          icon: Icons.delete_outline,
          label: '删除',
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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServerSetupPage(
          editing: existing != null,
          serverId: existing?.id,
          title: existing == null ? '添加服务器' : '编辑服务器',
        ),
      ),
    );
    if (saved != true || !mounted) return;
    AppHaptics.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '服务器已添加' : '服务器已更新')),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除“${server.name}”及其线路吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(serverConfigProvider.notifier).deleteServer(server.id);
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
          SnackBar(content: Text('删除失败：${toApiException(error).message}')),
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
    this.handle,
  });

  final ServerProfile server;
  final bool active;
  final VoidCallback onTap;
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
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
                avatarUrl: server.avatarUrl,
                size: 42,
                colors: colors,
                project: server.project,
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
                        '${server.lines.length} 条线路',
                        if (server.project != null)
                          server.project!.displayName
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
              if (handle != null) ...[const SizedBox(width: 8), handle!],
            ],
          ),
        ),
      ),
    );
  }
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
          '当前',
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

/// 向宿主页面注册行 context 的透明包装：拖拽换位反馈按帧读取各行的
/// RenderBox 位置来估算落点槽位。拖起时行 widget 会被移入 overlay 代理，
/// 注册随之迁移，落定后由列表原位重新注册。
class _ReorderRowGeometry extends StatefulWidget {
  const _ReorderRowGeometry({
    super.key,
    required this.serverId,
    required this.onRegister,
    required this.onUnregister,
    required this.child,
  });

  final String serverId;
  final void Function(String serverId, BuildContext context) onRegister;
  final void Function(String serverId, BuildContext context) onUnregister;
  final Widget child;

  @override
  State<_ReorderRowGeometry> createState() => _ReorderRowGeometryState();
}

class _ReorderRowGeometryState extends State<_ReorderRowGeometry> {
  @override
  void initState() {
    super.initState();
    widget.onRegister(widget.serverId, context);
  }

  @override
  void dispose() {
    widget.onUnregister(widget.serverId, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
