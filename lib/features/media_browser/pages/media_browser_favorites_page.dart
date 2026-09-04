import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/media_models.dart' as media_models;
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/media_browser/widgets/media_browser_selection.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';
import 'package:omm/shared/swipe_actions.dart';

enum _FavoritesViewMode { grid, list }

const _viewModeKey = 'media_browser.favorites.view_mode.v1';

/// MediaBrowser 收藏夹 · You Tab（与 OMM FavoritesPage 同构）。
///
/// - 顶部: 品牌 + 标题 + 设置入口
/// - 筛选行: 类型 chips + 排序 + Grid/List 切换
/// - 收藏网格/列表（分页 + 长按拖选多选 + 批量移除 + 列表左滑移除 + 下拉刷新）
///
/// 数据走 `Filters=IsFavorite` 全库递归查询；取消收藏走乐观移除，
/// 详情页内的收藏变更在返回时后台刷新同步。
class MediaBrowserFavoritesPage extends ConsumerStatefulWidget {
  const MediaBrowserFavoritesPage({super.key});

  @override
  ConsumerState<MediaBrowserFavoritesPage> createState() =>
      _MediaBrowserFavoritesPageState();
}

class _MediaBrowserFavoritesPageState
    extends ConsumerState<MediaBrowserFavoritesPage> {
  static const _pageSize = 24;
  static final _typeOptions =
      <({String value, String Function(AppL10n l) label})>[
        (
          value: 'Movie,Series,Episode,MusicAlbum,Audio',
          label: (l) => l.filterAll,
        ),
        (value: 'Movie', label: (l) => l.mediaBrowserTypeMovies),
        (value: 'Series', label: (l) => l.mediaBrowserTypeTvShows),
        (value: 'MusicAlbum,Audio', label: (l) => l.mediaBrowserTypeMusic),
      ];
  static final _sortOptions =
      <({String value, String Function(AppL10n l) label, String order})>[
        (
          value: 'DateCreated',
          label: (l) => l.mediaBrowserSortRecent,
          order: 'Descending',
        ),
        (
          value: 'SortName',
          label: (l) => l.mediaBrowserSortNameAZ,
          order: 'Ascending',
        ),
        (
          value: 'CommunityRating',
          label: (l) => l.mediaBrowserSortTopRated,
          order: 'Descending',
        ),
        (
          value: 'ProductionYear',
          label: (l) => l.mediaBrowserSortYearDesc,
          order: 'Descending',
        ),
      ];

  final _controller = PagingController<int, MediaBrowserItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  _FavoritesViewMode _viewMode = _FavoritesViewMode.grid;
  String _includeItemTypes = _typeOptions.first.value;
  int _sortIndex = 0;
  int _totalCount = 0;
  int _requestSerial = 0;
  Completer<void>? _refreshCompleter;
  late final PagedSelectionController<MediaBrowserItem> _selection;
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  bool _removing = false;
  bool get _selecting => _selection.isActive;
  Set<Object> get _selected => _selection.selectedIds;

  ({String value, String Function(AppL10n l) label, String order}) get _sort =>
      _sortOptions[_sortIndex];

  bool get _isMusicGrid => _includeItemTypes == _typeOptions.last.value;

  @override
  void initState() {
    super.initState();
    _selection = createMediaBrowserItemSelection();
    _selection.addModeListener(_onSelectionModeChanged);
    _viewMode = _loadViewMode();
    _controller.addPageRequestListener(_fetchPage);
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  _FavoritesViewMode _loadViewMode() {
    return ref.read(sharedPrefsProvider).getString(_viewModeKey) ==
            _FavoritesViewMode.list.name
        ? _FavoritesViewMode.list
        : _FavoritesViewMode.grid;
  }

  Future<void> _setViewMode(_FavoritesViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  Future<void> _fetchPage(int startIndex) async {
    final requestSerial = _requestSerial;
    try {
      final result = await readMediaBrowserItemPage(
        ref,
        MediaBrowserItemPageRequest(
          serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
          query: media_models.MediaQuery(
            offset: startIndex,
            limit: _pageSize,
            sortBy: _sort.value,
            orderBy: _sort.order == 'Ascending' ? 'asc' : 'desc',
            filters: {
              'includeItemTypes': _includeItemTypes,
              'recursive': true,
              'isFavorite': true,
            },
          ),
        ),
      );
      if (!mounted || requestSerial != _requestSerial) return;

      _totalCount = result.total;
      final current = _controller.itemList ?? const <MediaBrowserItem>[];
      final seen = <String>{for (final item in current) item.id};
      final items = result.items
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      applyPagedListPage(
        controller: _controller,
        offset: startIndex,
        items: items,
        totalCount: result.total,
      );
      if (startIndex == 0) _completeRefresh();
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
      if (startIndex == 0) _completeRefresh();
    }
  }

  Future<void> _refresh() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _requestSerial++;
    _controller.refresh();
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _reloadWith({String? includeItemTypes, int? sortIndex}) {
    final nextTypes = includeItemTypes ?? _includeItemTypes;
    final nextSortIndex = sortIndex ?? _sortIndex;
    if (nextTypes == _includeItemTypes && nextSortIndex == _sortIndex) return;
    setState(() {
      _includeItemTypes = nextTypes;
      _sortIndex = nextSortIndex;
    });
    _selection.exit();
    _requestSerial++;
    _controller.refresh();
  }

  Future<void> _openItem(MediaBrowserItem item) async {
    await openMediaBrowserItem(context, ref, item);
    if (!mounted) return;
    await _refreshAfterDetail();
  }

  /// 详情页内可能切换了收藏/已看，返回时后台刷新已加载条目并保持滚动位置。
  Future<void> _refreshAfterDetail() async {
    final includeItemTypes = _includeItemTypes;
    final sort = _sort;
    final refreshed = await refreshPagedListInBackground<MediaBrowserItem>(
      controller: _controller,
      loadFirstPage: (limit) async {
        final result = await readMediaBrowserItemPage(
          ref,
          MediaBrowserItemPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            query: media_models.MediaQuery(
              limit: limit,
              sortBy: sort.value,
              orderBy: sort.order == 'Ascending' ? 'asc' : 'desc',
              filters: {
                'includeItemTypes': includeItemTypes,
                'recursive': true,
                'isFavorite': true,
              },
            ),
          ),
        );
        _totalCount = result.total;
        return PagedResult(
          items: result.items,
          totalCount: result.total,
          limit: limit,
          offset: 0,
        );
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  void _applyLocalRemoval(Set<String> removedIds) {
    final list = _controller.itemList?.toList() ?? [];
    list.removeWhere((it) => removedIds.contains(it.id));
    _controller.itemList = list;
    _totalCount = (_totalCount - removedIds.length).clamp(0, 1 << 31);
    _selection.retainWhere((id) => !removedIds.contains(id));
    if (mounted) setState(() {});
  }

  Future<void> _removeOne(MediaBrowserItem item) async {
    if (_removing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removing = true);
    try {
      await ref
          .read(mediaBrowserMediaRepositoryProvider)
          .markFavorite(item.id, false);
      if (!mounted) return;
      setState(() => _removing = false);
      _applyLocalRemoval({item.id});
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).mediaBrowserRemovedItem(item.name)),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _removing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).mediaBrowserRemoveFavoriteFailed(toApiException(error).message),
          ),
        ),
      );
    }
  }

  Future<void> _removeSelection() async {
    if (_selected.isEmpty || _removing) return;
    final ids = _selected.whereType<String>().toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppL10n.of(ctx).mediaBrowserRemoveFavoritesTitle),
        content: Text(
          AppL10n.of(ctx).mediaBrowserRemoveFavoritesBody(ids.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppL10n.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppL10n.of(ctx).remove),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removing = true);
    final failedIds = <String>{};
    try {
      final repo = ref.read(mediaBrowserMediaRepositoryProvider);
      for (final id in ids) {
        try {
          await repo.markFavorite(id, false);
        } catch (_) {
          failedIds.add(id);
        }
      }
      if (!mounted) return;
      setState(() => _removing = false);
      final removed = ids.where((id) => !failedIds.contains(id)).toSet();
      if (removed.isNotEmpty) _applyLocalRemoval(removed);
      if (failedIds.isEmpty && mounted) _selection.exit();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failedIds.isEmpty
                ? AppL10n.of(context).mediaBrowserRemovedNItems(removed.length)
                : AppL10n.of(context).mediaBrowserRemovedNItemsWithFailed(
                    removed.length,
                    failedIds.length,
                  ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _removing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).mediaBrowserBatchRemoveFailed(toApiException(error).message),
          ),
        ),
      );
    }
  }

  Future<void> _showSortSheet() async {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final picked = await showGlassSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.sort_rounded,
                title: l.mediaBrowserSortBy,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              for (var i = 0; i < _sortOptions.length; i++)
                ListTile(
                  dense: true,
                  title: Text(_sortOptions[i].label(l)),
                  trailing: i == _sortIndex
                      ? Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _reloadWith(sortIndex: picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    final l = AppL10n.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 6
        : width >= 820
        ? 5
        : width >= 600
        ? 4
        : 3;
    const horizontalPadding = 44.0;
    const spacing = 10.0;
    final itemWidth =
        ((width - horizontalPadding) - spacing * (crossAxisCount - 1)) /
        crossAxisCount;
    // 影视海报 2:3 + 双行文字；音乐方形封面按实际卡片高度反推比例（同库页）。
    final cardAspectRatio = _isMusicGrid
        ? itemWidth / (itemWidth + 62)
        : MediaCardTemplate.gridChildAspectRatio;

    return Scaffold(
      // 独立路由进入时页面自身就是 Material 根；底色由 GlowBackground 自绘。
      backgroundColor: Colors.transparent,
      body: PagedSelectionPopScope<MediaBrowserItem>(
        selection: _selection,
        child: GlowBackground(
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // ===== 固定 header：品牌 + 标题 + 设置入口 =====
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ref
                                          .watch(mediaBrowserConfigProvider)
                                          ?.brandLabel ??
                                      '',
                                  style: AppText.eyebrow(context),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppL10n.of(context).favoritesTitle,
                                  style: AppText.pageTitle(context),
                                ),
                              ],
                            ),
                          ),
                          _HeaderIconButton(
                            icon: Icons.settings_outlined,
                            tooltip: AppL10n.of(context).settingsTitle,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StatusBarScrollToTop(
                        scrollController: _scrollController,
                        child: RefreshIndicator(
                          color: colors.accent,
                          onRefresh: _refresh,
                          child: PagedSelectionScope<MediaBrowserItem>(
                            selection: _selection,
                            scrollController: _scrollController,
                            layout: _viewMode == _FavoritesViewMode.grid
                                ? DragSelectionLayout.grid
                                : DragSelectionLayout.list,
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // ===== 全部收藏 + 计数 =====
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      0,
                                      22,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.allFavorites,
                                          style: AppText.eyebrow(context),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _totalCount > 0
                                              ? l.mediaBrowserItemCount(
                                                  _totalCount,
                                                )
                                              : l.mediaBrowserNoFavorites,
                                          style: AppText.sectionTitle(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // ===== 筛选行：类型 chips + 排序 + 视图切换 =====
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: SizedBox(
                                      height: 32,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                        ),
                                        children: [
                                          for (
                                            var i = 0;
                                            i < _typeOptions.length;
                                            i++
                                          ) ...[
                                            if (i > 0) const SizedBox(width: 6),
                                            _TypeChip(
                                              label: _typeOptions[i].label(l),
                                              selected:
                                                  _includeItemTypes ==
                                                  _typeOptions[i].value,
                                              onTap: () => _reloadWith(
                                                includeItemTypes:
                                                    _typeOptions[i].value,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 6),
                                          _SortPill(
                                            label: _sort.label(l),
                                            onTap: () =>
                                                unawaited(_showSortSheet()),
                                          ),
                                          const SizedBox(width: 6),
                                          _ViewToggle(
                                            mode: _viewMode,
                                            onChange: (mode) =>
                                                unawaited(_setViewMode(mode)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // ===== 收藏网格 / 列表 =====
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  sliver: urls.maybeWhen(
                                    data: (value) =>
                                        _viewMode == _FavoritesViewMode.grid
                                        ? PagedSliverGrid<
                                            int,
                                            MediaBrowserItem
                                          >(
                                            pagingController: _controller,
                                            showNoMoreItemsIndicatorAsGridChild:
                                                false,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount:
                                                      crossAxisCount,
                                                  childAspectRatio:
                                                      cardAspectRatio,
                                                  mainAxisSpacing: 14,
                                                  crossAxisSpacing: spacing,
                                                ),
                                            builderDelegate: PagedChildBuilderDelegate<MediaBrowserItem>(
                                              itemBuilder: (context, item, index) =>
                                                  mediaBrowserSelectableGridItem(
                                                    selection: _selection,
                                                    item: item,
                                                    urls: value,
                                                    width: itemWidth,
                                                    index: index,
                                                    square: _isMusicGrid,
                                                    onOpen: _openItem,
                                                  ),
                                              firstPageProgressIndicatorBuilder:
                                                  (_) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 56,
                                                        ),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color:
                                                                colors.accent,
                                                          ),
                                                    ),
                                                  ),
                                              newPageProgressIndicatorBuilder:
                                                  (_) => const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 18,
                                                        ),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                              firstPageErrorIndicatorBuilder:
                                                  (_) => _FavoritesError(
                                                    message:
                                                        _controller.error
                                                            ?.toString() ??
                                                        AppL10n.of(
                                                          context,
                                                        ).loadFailed,
                                                    onRetry: _controller
                                                        .retryLastFailedRequest,
                                                  ),
                                              newPageErrorIndicatorBuilder:
                                                  (_) => PaginationRetry(
                                                    onRetry: _controller
                                                        .retryLastFailedRequest,
                                                  ),
                                              noItemsFoundIndicatorBuilder:
                                                  (_) => const _EmptyState(),
                                              noMoreItemsIndicatorBuilder:
                                                  (_) => const NoMoreContent(),
                                            ),
                                          )
                                        : PagedSliverList<
                                            int,
                                            MediaBrowserItem
                                          >(
                                            pagingController: _controller,
                                            builderDelegate: PagedChildBuilderDelegate<MediaBrowserItem>(
                                              itemBuilder:
                                                  (context, item, index) =>
                                                      PagedSelectionItem<
                                                        MediaBrowserItem
                                                      >(
                                                        selection: _selection,
                                                        item: item,
                                                        selectionHandleAlignment:
                                                            Alignment
                                                                .centerLeft,
                                                        cardBuilder:
                                                            (
                                                              context,
                                                              item,
                                                              selected,
                                                            ) => _ListRow(
                                                              item: item,
                                                              urls: value,
                                                              swipeGroup:
                                                                  _openSwipe,
                                                              selected:
                                                                  selected,
                                                              selecting:
                                                                  _selecting,
                                                              onTap: () {
                                                                if (_selecting) {
                                                                  _selection
                                                                      .toggle(
                                                                        item.id,
                                                                      );
                                                                } else {
                                                                  unawaited(
                                                                    _openItem(
                                                                      item,
                                                                    ),
                                                                  );
                                                                }
                                                              },
                                                              onRemove: () =>
                                                                  unawaited(
                                                                    _removeOne(
                                                                      item,
                                                                    ),
                                                                  ),
                                                            ),
                                                      ),
                                              firstPageProgressIndicatorBuilder:
                                                  (_) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 56,
                                                        ),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color:
                                                                colors.accent,
                                                          ),
                                                    ),
                                                  ),
                                              newPageProgressIndicatorBuilder:
                                                  (_) => const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 18,
                                                        ),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                              firstPageErrorIndicatorBuilder:
                                                  (_) => _FavoritesError(
                                                    message:
                                                        _controller.error
                                                            ?.toString() ??
                                                        AppL10n.of(
                                                          context,
                                                        ).loadFailed,
                                                    onRetry: _controller
                                                        .retryLastFailedRequest,
                                                  ),
                                              newPageErrorIndicatorBuilder:
                                                  (_) => PaginationRetry(
                                                    onRetry: _controller
                                                        .retryLastFailedRequest,
                                                  ),
                                              noItemsFoundIndicatorBuilder:
                                                  (_) => const _EmptyState(),
                                              noMoreItemsIndicatorBuilder:
                                                  (_) => const NoMoreContent(),
                                            ),
                                          ),
                                    orElse: () => const SliverToBoxAdapter(
                                      child: SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 120),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                PagedSelectionToolbar<MediaBrowserItem>(
                  selection: _selection,
                  onSelectAll: () => _selection.selectAll(
                    _controller.itemList ?? const <MediaBrowserItem>[],
                  ),
                  actionsBuilder: (selected) => [
                    EntityBatchAction(
                      icon: Icons.delete_outline,
                      label: AppL10n.of(
                        context,
                      ).mediaBrowserRemoveFavoritesTitle,
                      color: colors.danger,
                      onTap: selected.isEmpty || _removing
                          ? null
                          : () => unawaited(_removeSelection()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ 列表行（左滑可移除） ============
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.item,
    required this.urls,
    required this.swipeGroup,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onRemove,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final SwipeActionGroup swipeGroup;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
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
                color: selected ? colors.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? colors.accent : colors.muted2,
                  width: 1.5,
                ),
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
              movieId: item.id,
              radius: 8,
              child: Poster(
                url: item.primaryImageTag == null
                    ? null
                    : urls.poster(item.id, tag: item.primaryImageTag),
                title: item.name,
                year: item.productionYear,
                radius: 8,
                httpHeaders: urls.imageHeaders,
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
                  movieId: item.id,
                  text: item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mediaBrowserItemMetaText(context, item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final row = selecting
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: inner,
          )
        : PrivacyAwareInkWell(
            movieId: item.id,
            onTap: onTap,
            borderRadius: 12,
            child: inner,
          );

    if (selecting) {
      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: row,
      );
    }

    // 左滑双逻辑：展开点击移除，或滑到头/快速左甩直接执行。
    return SwipeActionCell(
      group: swipeGroup,
      cellKey: item.id,
      enabled: true,
      actions: [
        SwipeActionData(
          icon: Icons.delete_outline,
          label: AppL10n.of(context).remove,
          color: colors.danger,
          onPressed: onRemove,
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: row,
      ),
    );
  }
}

// ============ 空态 ============
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.favorite_border, size: 36, color: colors.muted),
            const SizedBox(height: 10),
            Text(
              AppL10n.of(context).mediaBrowserNoFavoritesYet,
              style: AppText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.of(context).mediaBrowserNoFavoritesHint,
              style: AppText.meta(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ 首屏错误 ============
class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.muted, size: 38),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(AppL10n.of(context).mediaBrowserRetry),
          ),
        ],
      ),
    );
  }
}

// ============ header 圆形按钮 ============
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return IconButton(
      tooltip: tooltip,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: colors.cardBorder),
        ),
        child: Icon(icon, size: 18, color: colors.text),
      ),
      onPressed: onTap,
    );
  }
}

// ============ 类型 chip ============
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : colors.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colors.accent.withValues(alpha: 0.5)
                : colors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.accent : colors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ============ 排序 pill + 视图切换 ============
class _SortPill extends StatelessWidget {
  const _SortPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 14, color: colors.text),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colors.text,
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

  final _FavoritesViewMode mode;
  final ValueChanged<_FavoritesViewMode> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    Widget btn(IconData icon, _FavoritesViewMode m) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChange(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 15,
            color: active ? colors.text : colors.muted,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.grid_view_rounded, _FavoritesViewMode.grid),
          btn(Icons.view_list_rounded, _FavoritesViewMode.list),
        ],
      ),
    );
  }
}
