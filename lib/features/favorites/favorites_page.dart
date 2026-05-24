import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/poster.dart';
import '../lists/list_detail_page.dart';
import '../lists/list_model.dart';
import '../lists/lists_providers.dart';
import '../privacy/privacy_mask.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';
import '../settings/settings_page.dart';
import 'favorites_providers.dart';

enum FavoritesViewMode { grid, list }

enum FavoritesSort {
  recent(label: '最近添加', sortBy: 'created_at', order: 'desc'),
  rating(label: '高分优先', sortBy: 'rating', order: 'desc'),
  title(label: '标题 A→Z', sortBy: 'title', order: 'asc'),
  yearDesc(label: '年份倒序', sortBy: 'year', order: 'desc');

  const FavoritesSort({
    required this.label,
    required this.sortBy,
    required this.order,
  });

  final String label;
  final String sortBy;
  final String order;
}

/// Favorites · You Tab
/// - 顶部: 问候 + 设置入口
/// - 统计条 (Saved / Watched / Hours)
/// - 多彩本地 lists (Watchlist / All-Time Best / Weekend Picks / After Hours)
/// - 收藏网格 (分页 + Grid/List 切换 + 排序 + 长按多选 + 滑动删除 + 下拉刷新)
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  static const _pageSize = 30;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  FavoritesViewMode _viewMode = FavoritesViewMode.grid;
  FavoritesSort _sort = FavoritesSort.recent;
  int _totalCount = 0;
  final Set<int> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      final page = await repo.list(
        MovieFilter(sortBy: _sort.sortBy, sortOrder: _sort.order),
        limit: _pageSize,
        offset: offset,
      );
      _totalCount = page.totalCount;
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      if (mounted) setState(() {});
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  Future<void> _refresh() async {
    _controller.refresh();
    // 等首页就绪
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _changeSort(FavoritesSort v) {
    if (v == _sort) return;
    setState(() => _sort = v);
    _controller.refresh();
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _removeOne(MovieListItem m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(favoritesRepositoryProvider).removeBatch([m.id]);
      ref.read(favoriteStatusProvider.notifier).seed(m.id, false);
      // 直接从当前 list 移除,避免整页 refresh
      final list = _controller.itemList?.toList() ?? [];
      list.removeWhere((it) => it.id == m.id);
      _controller.itemList = list;
      _totalCount = (_totalCount - 1).clamp(0, 1 << 30);
      if (mounted) setState(() {});
      messenger.showSnackBar(SnackBar(
        content: Text('已移除「${m.title}」'),
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('移除失败: $e')));
    }
  }

  Future<void> _removeSelection() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ids = _selected.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除收藏'),
        content: Text('从收藏夹移除 ${ids.length} 部影片?\n影片本身不会被删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('移除')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(favoritesRepositoryProvider).removeBatch(ids);
      for (final id in ids) {
        ref.read(favoriteStatusProvider.notifier).seed(id, false);
      }
      final list = _controller.itemList?.toList() ?? [];
      list.removeWhere((it) => ids.contains(it.id));
      _controller.itemList = list;
      _totalCount = (_totalCount - ids.length).clamp(0, 1 << 30);
      _selected.clear();
      if (mounted) setState(() {});
      messenger.showSnackBar(SnackBar(
        content: Text('已移除 ${ids.length} 部'),
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('批量移除失败: $e')));
    }
  }

  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<FavoritesSort>(
      context: context,
      backgroundColor: appColors(context).bg,
      showDragHandle: true,
      builder: (ctx) {
        final c = appColors(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Row(
                  children: [
                    Text('排序方式', style: AppText.sectionTitle(ctx)),
                  ],
                ),
              ),
              for (final s in FavoritesSort.values)
                ListTile(
                  title: Text(
                    s.label,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  trailing: s == _sort
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (picked != null) _changeSort(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.accent,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // ===== 顶部 =====
              SliverToBoxAdapter(
                child: _selecting
                    ? _SelectionBar(
                        count: _selected.length,
                        onCancel: _clearSelection,
                        onRemove: _removeSelection,
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppL10n.of(context).tabYou.toUpperCase(),
                                      style: AppText.eyebrow(context)),
                                  const SizedBox(height: 3),
                                  Text(AppL10n.of(context).favoritesTitle,
                                      style: AppText.pageTitle(context)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.surface,
                                  border: Border.all(color: c.cardBorder),
                                ),
                                child:
                                    Icon(Icons.settings, size: 18, color: c.text),
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsPage()),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // ===== 统计条 =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: _StatsCard(
                    totalCount: _totalCount,
                    items: _controller.itemList ?? const [],
                  ),
                ),
              ),

              // ===== Lists 多彩卡片 =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Text(AppL10n.of(context).yourLists, style: AppText.sectionTitle(context)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                  child: _ListsGrid(),
                ),
              ),

              // ===== All favorites · header + 排序 + 视图切换 =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('全部收藏',
                                style: AppText.eyebrow(context)),
                            const SizedBox(height: 3),
                            Text('$_totalCount 部影片',
                                style: AppText.sectionTitle(context)),
                          ],
                        ),
                      ),
                      _SortPill(label: _sort.label, onTap: _showSortSheet),
                      const SizedBox(width: 6),
                      _ViewToggle(
                        mode: _viewMode,
                        onChange: (m) => setState(() => _viewMode = m),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== 收藏网格 / 列表 =====
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: _viewMode == FavoritesViewMode.grid
                    ? PagedSliverGrid<int, MovieListItem>(
                        pagingController: _controller,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                        ),
                        builderDelegate: _buildGridDelegate(urlBuilder),
                      )
                    : PagedSliverList<int, MovieListItem>(
                        pagingController: _controller,
                        builderDelegate: _buildListDelegate(urlBuilder),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildGridDelegate(
    String Function(String) urlBuilder,
  ) {
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, m, idx) => _GridCell(
        movie: m,
        urlBuilder: urlBuilder,
        selected: _selected.contains(m.id),
        selecting: _selecting,
        onTap: () {
          if (_selecting) {
            _toggleSelect(m.id);
          } else {
            Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: m.id)),
            );
          }
        },
        onLongPress: () => _toggleSelect(m.id),
      ),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? '加载失败',
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) => _EmptyState(),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildListDelegate(
    String Function(String) urlBuilder,
  ) {
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, m, idx) => _ListRow(
        movie: m,
        urlBuilder: urlBuilder,
        selected: _selected.contains(m.id),
        selecting: _selecting,
        onTap: () {
          if (_selecting) {
            _toggleSelect(m.id);
          } else {
            Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: m.id)),
            );
          }
        },
        onLongPress: () => _toggleSelect(m.id),
        onRemove: () => _removeOne(m),
      ),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? '加载失败',
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) => _EmptyState(),
    );
  }
}

// ============ Empty ============
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.favorite_border, size: 36, color: appColors(context).muted),
            const SizedBox(height: 10),
            Text('还没有收藏的影片',
                style: AppText.body(context)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('在影片详情页点击 ♡ 加入收藏',
                style: AppText.meta(context)),
          ],
        ),
      ),
    );
  }
}

// ============ Selection bar ============
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onRemove,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onCancel,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '已选 $count',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
              label: const Text(
                '移除',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Sort pill + view toggle ============
class _SortPill extends StatelessWidget {
  const _SortPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 14, color: c.text),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChange});
  final FavoritesViewMode mode;
  final ValueChanged<FavoritesViewMode> onChange;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    Widget btn(IconData icon, FavoritesViewMode m) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChange(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: active ? c.text : c.muted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.grid_view_rounded, FavoritesViewMode.grid),
          btn(Icons.view_list_rounded, FavoritesViewMode.list),
        ],
      ),
    );
  }
}

// ============ Grid cell ============
class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.movie,
    required this.urlBuilder,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final MovieListItem movie;
  final String Function(String) urlBuilder;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Stack(
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: selecting && !selected ? 0.55 : 1.0,
          child: MovieCard(
            movie: movie,
            posterUrlBuilder: urlBuilder,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
        if (selecting)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accent : Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

// ============ List row (滑动可移除) ============
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.movie,
    required this.urlBuilder,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
  });

  final MovieListItem movie;
  final String Function(String) urlBuilder;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    // 多选模式下走原 InkWell (点击切换勾选), 其他情况下走 PrivacyAwareInkWell
    final inner = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (selecting) ...[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.accent : Colors.transparent,
                  border: Border.all(
                      color: selected ? c.accent : c.muted2, width: 1.5),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 14),
            ],
            SizedBox(
              width: 52,
              child: PrivacyMask(
                movieId: movie.id,
                radius: 8,
                child: Poster(
                  url: movie.posterUuid != null
                      ? urlBuilder(movie.posterUuid!)
                      : null,
                  title: movie.title,
                  year: movie.year,
                  radius: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrivacyText(
                    movieId: movie.id,
                    text: movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (movie.year != null) '${movie.year}',
                      if (movie.runtime != null && movie.runtime! > 0)
                        '${movie.runtime}m',
                      if (movie.rating != null && movie.rating! > 0)
                        '★ ${movie.rating!.toStringAsFixed(1)}',
                    ].join(' · '),
                    style: AppText.meta(context),
                  ),
                ],
              ),
            ),
            if (!selecting)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B9D), Color(0xFF9F6BFF)],
                  ),
                ),
                child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
              ),
          ],
        ),
      );

    final row = selecting
        ? InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: inner,
          )
        : PrivacyAwareInkWell(
            movieId: movie.id,
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: 12,
            child: inner,
          );

    if (selecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: row,
      );
    }

    return Dismissible(
      key: ValueKey('fav-${movie.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: c.danger.withValues(alpha: 0.85),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('移除',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: row,
      ),
    );
  }
}

// ============ Stats + Lists 复用 ============
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.totalCount, required this.items});
  final int totalCount;
  final List<MovieListItem> items;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final watched = items.where((m) => m.watchRecord?.completed == true).length;
    final hours = items.fold<int>(0, (acc, m) {
          final r = m.watchRecord;
          if (r == null) return acc;
          final fraction = r.completed ? 1.0 : r.progressRatio;
          final mins = m.runtime != null ? (m.runtime! * fraction).round() : 0;
          return acc + mins;
        }) ~/
        60;

    Widget cell(String k, String v, {bool first = false}) {
      return Expanded(
        child: Container(
          decoration: first
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: c.divider)),
                ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                v,
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                k.toUpperCase(),
                style: TextStyle(
                  color: c.muted,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          cell('已收藏', totalCount > 0 ? '$totalCount' : '${items.length}',
              first: true),
          cell('已看', '$watched'),
          cell('小时', '$hours'),
        ],
      ),
    );
  }
}

class _ListsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider);
    return LayoutBuilder(builder: (ctx, cons) {
      const gap = 10.0;
      final w = (cons.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final l in lists)
            SizedBox(
              width: w,
              child: _ListCard(list: l),
            ),
          // "+ 新建集合" 卡片
          SizedBox(
            width: w,
            child: _NewListCard(),
          ),
        ],
      );
    });
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list});

  final FavoriteList list;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListDetailPage(listId: list.id)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 5 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppHues.top(list.hue), AppHues.bottom(list.hue)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -30,
                  width: 100,
                  height: 100,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppHues.highlight(list.hue),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '◇',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (list.locked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'PIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            list.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.3,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${list.count} titles',
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewListCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    return InkWell(
      onTap: () => _showCreate(context, ref),
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 5 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: c.chipBg,
            border: Border.all(
              color: c.muted2.withValues(alpha: 0.4),
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: c.accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                '新建集合',
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    int selectedHue = AppHues.lavender;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('新建集合'),
          content: StatefulBuilder(
            builder: (sctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '集合名称'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: AppHues.all.map((hue) {
                    final on = hue == selectedHue;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedHue = hue),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppHues.top(hue), AppHues.bottom(hue)],
                          ),
                          border: Border.all(
                            color: on ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: on
                              ? [
                                  BoxShadow(
                                    color:
                                        AppHues.top(hue).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('创建')),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      await ref
          .read(listsProvider.notifier)
          .create(name: name, hue: selectedHue);
    }
  }
}
