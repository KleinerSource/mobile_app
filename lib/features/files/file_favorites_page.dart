import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/common/source_id.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/floating_tab_bar.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'file_entry_icons.dart';
import 'file_favorites.dart';

/// 收藏列表页 · 文件管理器「收藏」Tab。
///
/// 展示当前文件服务器收藏的文件与目录（按服务器分别存储）。点击条目由
/// Shell 在文件 Tab 中打开：目录逐级进入，文件定位到所在目录并自动打开；
/// 条目右侧的星标按钮可快速取消收藏。
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

  @override
  void dispose() {
    _scrollController.dispose();
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
    final visible = _sorted(favorites)
        .where(
          (favorite) =>
              (!widget.directoriesOnly || favorite.isDirectory) &&
              (widget.sourceId == null || favorite.sourceId == widget.sourceId),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: l.fileEyebrow,
              title: l.fileFavoritesSection,
              showBackButton: false,
            ),
            body: visible.isEmpty
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
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: floatingTabBarContentBottomInset(context),
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) =>
                        _favoriteTile(visible[index], serverId!),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 目录在前，其余按收藏时间倒序，同时间按名称排序。
  List<FileFavorite> _sorted(List<FileFavorite> favorites) {
    return [...favorites]..sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final byAddedAt = b.addedAtMilliseconds.compareTo(a.addedAtMilliseconds);
      if (byAddedAt != 0) return byAddedAt;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
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
      leading: FileEntryIconBadge(entry: entry, isFavorite: true),
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
