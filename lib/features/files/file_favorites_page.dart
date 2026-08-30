import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/common/source_id.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/floating_tab_bar.dart';
import '../../shared/glow_background.dart';
import '../../shared/reorder_slot_feedback.dart';
import '../settings/settings_common.dart';
import 'file_entry_icons.dart';
import 'file_favorites.dart';

/// 收藏列表页 · 文件管理器「收藏」Tab。
///
/// 展示当前文件服务器收藏的文件与目录（按服务器分别存储）。点击条目由
/// Shell 在文件 Tab 中打开：目录逐级进入，文件定位到所在目录并自动打开；
/// 条目右侧的星标按钮可快速取消收藏。长按条目可拖拽调整顺序，顺序按
/// 服务器持久化，拖拽过一次后列表即固定为手动顺序（新收藏置顶）。
class FileFavoritesPage extends ConsumerStatefulWidget {
  const FileFavoritesPage({
    super.key,
    required this.onOpenFavorite,
    this.directoriesOnly = false,
    this.sourceId,
  });

  final ValueChanged<FileFavorite> onOpenFavorite;
  final bool directoriesOnly;
  final String? sourceId;

  @override
  ConsumerState<FileFavoritesPage> createState() => _FileFavoritesPageState();
}

class _FileFavoritesPageState extends ConsumerState<FileFavoritesPage> {
  final ScrollController _scrollController = ScrollController();

  /// 拖拽跨行换位时的槽位触感，与服务器列表一致。
  final _slotFeedback = ReorderSlotFeedback();

  @override
  void dispose() {
    _scrollController.dispose();
    _slotFeedback.endDrag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final serverId = ref.watch(
      serverConfigProvider.select((config) => config?.activeServerId),
    );
    final favorites = serverId == null
        ? const <FileFavorite>[]
        : ref.watch(fileFavoritesProvider(serverId));
    final manualOrder = serverId != null &&
        ref.watch(fileFavoritesManualOrderProvider(serverId));
    final visible = _sorted(favorites, manualOrder: manualOrder)
        .where(
          (favorite) =>
              (!widget.directoriesOnly || favorite.isDirectory) &&
              (widget.sourceId == null || favorite.sourceId == widget.sourceId),
        )
        .toList(growable: false);
    // 拖拽重排只对完整收藏列表开放；目录选择器（directoriesOnly）或按
    // 来源过滤的子集视图里，可见下标与存储数组不再一一对应。
    final reorderable = !widget.directoriesOnly && widget.sourceId == null;

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SizedBox(
              height: kToolbarHeight,
              child: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                centerTitle: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  l.fileFavoritesSection,
                  style: AppText.cardTitle(
                    context,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            body: visible.isEmpty || serverId == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_border_rounded,
                            size: 48,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l.fileFavoritesEmpty,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : reorderable
                ? _reorderableList(visible, serverId)
                : _staticList(visible, serverId),
          ),
        ),
      ),
    );
  }

  /// 手动排序模式下顺序完全由存储数组决定；否则目录在前、其余按收藏
  /// 时间倒序，同时间按名称排序。
  List<FileFavorite> _sorted(
    List<FileFavorite> favorites, {
    required bool manualOrder,
  }) {
    if (manualOrder) return favorites;
    return [...favorites]..sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final byAddedAt = b.addedAtMilliseconds.compareTo(a.addedAtMilliseconds);
      if (byAddedAt != 0) return byAddedAt;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Widget _reorderableList(List<FileFavorite> visible, String serverId) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: floatingTabBarContentBottomInset(context),
      ),
      itemCount: visible.length,
      // 移动端默认手势为整行长按拖拽，条目无需显示拖拽把手。
      buildDefaultDragHandles: true,
      proxyDecorator: _dragProxyDecorator,
      onReorderStart: (index) {
        AppHaptics.light();
        _slotFeedback.startDrag(visible[index].stableKey, index);
      },
      onReorderEnd: (_) => _slotFeedback.endDrag(),
      onReorderItem: (oldIndex, newIndex) {
        AppHaptics.medium();
        // onReorderItem 的 newIndex 已按移除旧项校正，可直接插入。
        final ordered = [...visible];
        final moved = ordered.removeAt(oldIndex);
        ordered.insert(newIndex, moved);
        ref
            .read(fileFavoritesProvider(serverId).notifier)
            .reorder(ordered);
      },
      itemBuilder: (context, index) => ReorderableRowGeometry(
        key: ValueKey<String>(visible[index].stableKey),
        rowId: visible[index].stableKey,
        onRegister: _slotFeedback.registerRow,
        onUnregister: _slotFeedback.unregisterRow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              Divider(height: 1, color: Theme.of(context).dividerColor),
            _favoriteTile(visible[index], serverId),
          ],
        ),
      ),
    );
  }

  Widget _staticList(List<FileFavorite> visible, String serverId) {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: floatingTabBarContentBottomInset(context),
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) =>
          _favoriteTile(visible[index], serverId),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }

  /// 拖拽代理浮起：行本身透明，浮起时补实底并加投影，浮起曲线与圆角
  /// 与服务器列表的拖拽卡片保持一致。
  Widget _dragProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    final colors = appColors(context);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final elevation = Curves.easeOut.transform(animation.value) * 6;
        return Material(
          color: colors.surface,
          shadowColor: Colors.black,
          elevation: elevation,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
    );
  }

  Widget _favoriteTile(FileFavorite favorite, String serverId) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final entry = favorite.toEntry(SourceId(favorite.sourceId));
    final location = favorite.path.replaceFirst(RegExp(r'^/+'), '');
    // 根级收藏没有上级位置可展示，副标题退回「根目录」避免与名称重复。
    final locationLabel = location.contains('/')
        ? location
        : l.fileRootDirectory;
    final starColor = AppHues.chipText(AppHues.solar, theme.brightness);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      leading: FileEntryIconBadge(
        entry: entry,
        isFavorite: true,
        child: FileEntryIconAsset(
          assetPath: fileIconAssetWhenPreviewDisabledFor(entry),
        ),
      ),
      title: Text(favorite.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        locationLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: starColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: starColor.withValues(alpha: 0.18)),
        ),
        child: IconButton(
          tooltip: l.fileUnfavorite,
          padding: EdgeInsets.zero,
          onPressed: () {
            ref
                .read(fileFavoritesProvider(serverId).notifier)
                .remove(favorite.stableKey);
          },
          icon: Icon(Icons.star_rounded, color: starColor, size: 20),
        ),
      ),
      onTap: () => widget.onOpenFavorite(favorite),
    );
  }
}
