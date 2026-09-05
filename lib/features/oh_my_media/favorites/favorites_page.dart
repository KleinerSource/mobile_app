import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/selection_controller.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/collection_card_layout.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/features/oh_my_media/lists/list_detail_page.dart';
import 'package:omm/features/oh_my_media/lists/list_labels.dart';
import 'package:omm/features/oh_my_media/lists/list_model.dart';
import 'package:omm/features/oh_my_media/lists/lists_providers.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/movies/omm_movie_preview_card.dart';
import 'package:omm/features/oh_my_media/movies/resource_scan_progress_sheet.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'favorites_providers.dart';
import 'media_favorites_repository.dart';

const _favoritesViewModeKey = 'favorites.view_mode.v1';

enum FavoritesSort {
  recent(sortBy: 'created_at', order: 'desc'),
  rating(sortBy: 'rating', order: 'desc'),
  title(sortBy: 'title', order: 'asc'),
  yearDesc(sortBy: 'year', order: 'desc');

  const FavoritesSort({required this.sortBy, required this.order});

  final String sortBy;
  final String order;
}

String _favoritesSortLabel(AppL10n l, FavoritesSort sort) => switch (sort) {
  FavoritesSort.recent => l.favoritesSortRecent,
  FavoritesSort.rating => l.favoritesSortRating,
  FavoritesSort.title => l.favoritesSortTitle,
  FavoritesSort.yearDesc => l.favoritesSortYearDesc,
};

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
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  MediaViewMode _viewMode = MediaViewMode.portrait;
  FavoritesSort _sort = FavoritesSort.recent;
  int _totalCount = 0;
  late final SelectionController<int> _selection;
  bool _newResourcesOnly = false;
  bool _resourceScanStarting = false;
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  int? _autoPreviewId;
  Timer? _autoPreviewDebounce;
  final _previewViewportKey = GlobalKey();
  final _previewItemKeys = <int, GlobalKey>{};
  final _previewCoordinator = StashPreviewCoordinator();
  bool get _selecting => _selection.isActive;
  Set<int> get _selected => _selection.selected;

  @override
  void initState() {
    super.initState();
    _selection = SelectionController<int>();
    _selection.activeListenable.addListener(_onSelectionModeChanged);
    _viewMode = _loadViewMode();
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_closeSwipeOnScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAutoPreviewUpdate();
    });
  }

  MediaViewMode _loadViewMode() {
    return mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_favoritesViewModeKey),
    );
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    _scheduleAutoPreviewUpdate();
    await ref
        .read(sharedPrefsProvider)
        .setString(
          _favoritesViewModeKey,
          mode == MediaViewMode.portrait ? 'grid' : mode.name,
        );
  }

  @override
  void dispose() {
    _autoPreviewDebounce?.cancel();
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _selection.dispose();
    _previewCoordinator.dispose();
    super.dispose();
  }

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
    _scheduleAutoPreviewUpdate();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
    _scheduleAutoPreviewUpdate();
  }

  void _scheduleAutoPreviewUpdate() {
    _autoPreviewDebounce?.cancel();
    _autoPreviewDebounce = Timer(const Duration(milliseconds: 180), () {
      _autoPreviewDebounce = null;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final next = _nextAutoPreviewId();
        if (next != _autoPreviewId) setState(() => _autoPreviewId = next);
      });
    });
  }

  int? _nextAutoPreviewId() {
    if (_viewMode != MediaViewMode.landscape || _selecting) return null;
    final items = _controller.itemList ?? const <MovieListItem>[];
    if (items.isEmpty) return null;
    final width = (MediaQuery.sizeOf(context).width - 44).clamp(
      1.0,
      double.infinity,
    );
    final coverHeight = width * 9 / 16;
    final index = previewItemIndexForViewportKeys(
      itemKeys: items.map((item) => _previewItemKeys[item.id]),
      viewportKey: _previewViewportKey,
      coverHeight: coverHeight,
    );
    return index == null ? null : items[index].id;
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      final result = await repo.list(
        MovieFilter(
          sortBy: _sort.sortBy,
          sortOrder: _sort.order,
          hasNewResources: _newResourcesOnly ? true : null,
        ),
        limit: _pageSize,
        offset: offset,
      );
      final page = result.page;
      _totalCount = page.totalCount;
      applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: page.items,
        totalCount: page.totalCount,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
      if (mounted) setState(() {});
      _scheduleAutoPreviewUpdate();
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  Future<void> _refresh() async {
    refreshImageCache(ref);
    _reload();
    // 等首页就绪
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _reload({bool preserveScroll = false}) {
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  Future<void> _openMovie(MovieListItem movie) async {
    final changesBeforeVisit = MovieDataChanges.snapshot(movieId: movie.id);
    final acknowledge = movie.hasNewResources
        ? ref.read(mediaRepositoryProvider).acknowledgeResources(movie.id)
        : null;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailPage(
          movieId: movie.id,
          acknowledgeNewResources: acknowledge == null,
        ),
      ),
    );

    if (mounted && acknowledge != null) {
      try {
        await acknowledge;
        // 只有确知存在新资源标记的确认才是真实变更(徽标需要消失)。
        MovieDataChanges.bumpMetadata(movieId: movie.id);
      } catch (_) {
        if (!mounted) return;
        try {
          await ref
              .read(mediaRepositoryProvider)
              .acknowledgeResources(movie.id);
          MovieDataChanges.bumpMetadata(movieId: movie.id);
        } catch (_) {
          // 确认失败时保留当前项，下一次查看或刷新时重试。
        }
      }
    }
    if (!mounted) return;
    // 详情页内没有任何真实变更时沿用缓存,不刷新。
    final now = changesBeforeVisit.latest;
    if (now.imagesChangedSince(changesBeforeVisit)) refreshImageCache(ref);
    if (now.metadata != changesBeforeVisit.metadata ||
        now.progress != changesBeforeVisit.progress) {
      await _refreshAfterMovie();
    }
  }

  Future<void> _refreshAfterMovie() async {
    final refreshed = await refreshPagedListInBackground<MovieListItem>(
      controller: _controller,
      loadFirstPage: (limit) async {
        final result = await ref
            .read(favoritesRepositoryProvider)
            .list(
              MovieFilter(
                sortBy: _sort.sortBy,
                sortOrder: _sort.order,
                hasNewResources: _newResourcesOnly ? true : null,
              ),
              limit: limit,
              offset: 0,
            );
        _totalCount = result.page.totalCount;
        return result.page;
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  Future<void> _startResourceScan() async {
    if (_resourceScanStarting || _totalCount <= 0) return;
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.favoritesScanTitle),
        content: Text(l.favoritesScanConfirm(_totalCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.favoritesScanStart),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resourceScanStarting = true);
    try {
      final result = await ref
          .read(mediaRepositoryProvider)
          .startResourceScan(
            filter: MovieFilter(
              hasNewResources: _newResourcesOnly ? true : null,
              sortBy: _sort.sortBy,
              sortOrder: _sort.order,
            ),
            favoriteOnly: true,
          );
      if (!mounted) return;
      setState(() => _resourceScanStarting = false);
      final skippedText = result.skippedCount > 0
          ? l.favoritesScanSkippedSuffix(result.skippedCount)
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l.favoritesScanSubmitted(result.acceptedCount)}$skippedText',
          ),
        ),
      );
      await ResourceScanProgressSheet.show(
        context,
        taskId: result.taskId,
        onCompleted: () {
          if (mounted) _reload(preserveScroll: true);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resourceScanStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).favoritesScanCreateFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  void _toggleNewResourcesFilter() {
    setState(() => _newResourcesOnly = !_newResourcesOnly);
    _reload();
  }

  void _changeSort(FavoritesSort v) {
    if (v == _sort) return;
    setState(() => _sort = v);
    _reload();
  }

  void _toggleSelect(int id) => _selection.toggle(id);

  void _startSelectionSweep(int id, bool selected) {
    _selection.enter();
    _selection.setSelected(id, selected);
  }

  void _applySelectionSweep(int id, bool selected) {
    _selection.setSelected(id, selected);
  }

  void _finishSelectionSweep() {
    if (_selected.isEmpty) _clearSelection();
  }

  void _clearSelection() => _selection.exit();

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <MovieListItem>[];
    _selection.selectAll(loaded.map((movie) => movie.id));
  }

  Future<void> _removeOne(MovieListItem m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(favoritesRepositoryProvider).removeBatch([m.id]);
      if (!mounted) return;
      ref.read(favoriteStatusProvider.notifier).seed(m.id, false);
      // 直接从当前 list 移除,避免整页 refresh
      final list = _controller.itemList?.toList() ?? [];
      list.removeWhere((it) => it.id == m.id);
      _controller.itemList = list;
      _totalCount = (_totalCount - 1).clamp(0, 1 << 30);
      setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).favoritesRemovedOne(m.title)),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).favoritesRemoveFailed('$e')),
        ),
      );
    }
  }

  Future<void> _removeSelection() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ids = _selected.toList();
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.favoritesRemoveTitle),
        content: Text(l.favoritesRemoveConfirm(ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.remove),
          ),
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
      if (mounted) _selection.exit();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.favoritesRemovedN(ids.length)),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.favoritesRemoveBatchFailed('$e'))),
      );
    }
  }

  Future<void> _showSortSheet() async {
    final picked = await showGlassSheet<FavoritesSort>(
      context: context,
      builder: (ctx) {
        final c = appColors(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.sort_rounded,
                title: AppL10n.of(ctx).favoritesSortSheetTitle,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              ),
              for (final s in FavoritesSort.values)
                ListTile(
                  title: Text(
                    _favoritesSortLabel(AppL10n.of(ctx), s),
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

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          PopScope(
            canPop: !_selecting,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _selecting) _clearSelection();
            },
            child: GlowBackground(
              child: SafeArea(
                bottom: false,
                // 固定 header(标题 + 扫描/设置按钮)不随内容滚动;
                // 统计条、集合卡片与收藏网格在下方滚动区内。
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppL10n.of(context).tabYou.toUpperCase(),
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
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.surface,
                                border: Border.all(color: c.cardBorder),
                              ),
                              child: _resourceScanStarting
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: c.accent,
                                      ),
                                    )
                                  : Icon(
                                      Icons.cloud_download_outlined,
                                      size: 18,
                                      color: c.text,
                                    ),
                            ),
                            tooltip: AppL10n.of(context).favoritesScanTooltip,
                            onPressed: _resourceScanStarting || _totalCount <= 0
                                ? null
                                : _startResourceScan,
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.surface,
                                border: Border.all(color: c.cardBorder),
                              ),
                              child: Icon(
                                Icons.settings,
                                size: 18,
                                color: c.text,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).push(
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
                          color: c.accent,
                          onRefresh: _refresh,
                          child: DragSelectionScope<int>(
                            scrollController: _scrollController,
                            selectionLayout: _viewMode == MediaViewMode.portrait
                                ? DragSelectionLayout.grid
                                : DragSelectionLayout.list,
                            isSelected: _selection.contains,
                            onSelectionStart: _startSelectionSweep,
                            onSelectionChanged: _applySelectionSweep,
                            onSelectionEnd: _finishSelectionSweep,
                            selectionMode: _selecting,
                            child: CustomScrollView(
                              key: _previewViewportKey,
                              controller: _scrollController,
                              slivers: [
                                // ===== 统计条 =====
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      0,
                                      22,
                                      22,
                                    ),
                                    child: _StatsCard(
                                      totalCount: _totalCount,
                                      items: _controller.itemList ?? const [],
                                    ),
                                  ),
                                ),

                                // ===== Lists 多彩卡片 =====
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      0,
                                      22,
                                      12,
                                    ),
                                    child: Text(
                                      AppL10n.of(context).yourLists,
                                      style: AppText.sectionTitle(context),
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 28),
                                    child: _ListsGrid(),
                                  ),
                                ),

                                // ===== All favorites · header + 排序 + 视图切换 =====
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      0,
                                      22,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppL10n.of(context).allFavorites,
                                          style: AppText.eyebrow(context),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          AppL10n.of(
                                            context,
                                          ).libraryCount(_totalCount),
                                          style: AppText.sectionTitle(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                                          _FavoriteFilterPill(
                                            active: _newResourcesOnly,
                                            onTap: _toggleNewResourcesFilter,
                                          ),
                                          const SizedBox(width: 6),
                                          _SortPill(
                                            label: _favoritesSortLabel(
                                              AppL10n.of(context),
                                              _sort,
                                            ),
                                            onTap: _showSortSheet,
                                          ),
                                          const SizedBox(width: 6),
                                          MediaViewModeToggle(
                                            mode: _viewMode,
                                            onChanged: (m) =>
                                                unawaited(_setViewMode(m)),
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
                                  sliver: _viewMode == MediaViewMode.portrait
                                      ? PagedSliverGrid<int, MovieListItem>(
                                          pagingController: _controller,
                                          showNoMoreItemsIndicatorAsGridChild:
                                              false,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                childAspectRatio:
                                                    MediaCardTemplate
                                                        .gridChildAspectRatio,
                                                crossAxisSpacing: 10,
                                                mainAxisSpacing: 14,
                                              ),
                                          builderDelegate: _buildGridDelegate(
                                            urlBuilder,
                                          ),
                                        )
                                      : _viewMode == MediaViewMode.landscape
                                      ? PagedSliverList<int, MovieListItem>(
                                          pagingController: _controller,
                                          builderDelegate: _buildGridDelegate(
                                            urlBuilder,
                                            landscape: true,
                                          ),
                                        )
                                      : PagedSliverList<int, MovieListItem>(
                                          pagingController: _controller,
                                          builderDelegate: _buildListDelegate(
                                            urlBuilder,
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
              ),
            ),
          ),
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<Set<int>>(
                valueListenable: _selection.selectedListenable,
                builder: (context, selected, _) => EntityBatchToolbar(
                  selectedCount: selected.length,
                  onSelectAll: _selectAllLoaded,
                  onClear: _clearSelection,
                  onClose: _clearSelection,
                  actions: [
                    EntityBatchAction(
                      icon: Icons.delete_outline,
                      label: AppL10n.of(context).favoritesRemoveAction,
                      color: c.danger,
                      onTap: selected.isEmpty ? null : _removeSelection,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildGridDelegate(
    String Function(String) urlBuilder, {
    bool landscape = false,
  }) {
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, m, idx) {
        final card = DragSelectionTarget<int>(
          key: ValueKey(m.id),
          id: m.id,
          selectionIndex: landscape ? null : idx,
          selectionHandleAlignment: landscape
              ? Alignment.centerLeft
              : Alignment.topLeft,
          child: ValueListenableBuilder<Set<int>>(
            valueListenable: _selection.selectedListenable,
            builder: (context, selected, _) => landscape
                ? OmmMoviePreviewCard(
                    key: _previewItemKeys.putIfAbsent(m.id, GlobalKey.new),
                    movie: m,
                    posterUrlBuilder: urlBuilder,
                    coordinator: _previewCoordinator,
                    autoPlayPreview: m.id == _autoPreviewId,
                    selecting: _selecting,
                    selected: selected.contains(m.id),
                    onTap: () {
                      if (_selecting) {
                        _toggleSelect(m.id);
                      } else {
                        unawaited(_openMovie(m));
                      }
                    },
                  )
                : SelectableMovieCard(
                    movie: m,
                    posterUrlBuilder: urlBuilder,
                    landscape: false,
                    selected: selected.contains(m.id),
                    selecting: _selecting,
                    onTap: () {
                      if (_selecting) {
                        _toggleSelect(m.id);
                      } else {
                        unawaited(_openMovie(m));
                      }
                    },
                  ),
          ),
        );
        return landscape
            ? Padding(padding: const EdgeInsets.only(bottom: 14), child: card)
            : card;
      },
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message:
            _controller.error?.toString() ?? AppL10n.of(context).loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) => _EmptyState(),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildListDelegate(
    String Function(String) urlBuilder,
  ) {
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, m, idx) => DragSelectionTarget<int>(
        key: ValueKey(m.id),
        id: m.id,
        selectionHandleAlignment: Alignment.centerLeft,
        child: ValueListenableBuilder<Set<int>>(
          valueListenable: _selection.selectedListenable,
          builder: (context, selected, _) => _ListRow(
            movie: m,
            urlBuilder: urlBuilder,
            swipeGroup: _openSwipe,
            selected: selected.contains(m.id),
            selecting: _selecting,
            onTap: () {
              if (_selecting) {
                _toggleSelect(m.id);
              } else {
                unawaited(_openMovie(m));
              }
            },
            onRemove: () => _removeOne(m),
          ),
        ),
      ),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message:
            _controller.error?.toString() ?? AppL10n.of(context).loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) => _EmptyState(),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
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
            Icon(
              Icons.favorite_border,
              size: 36,
              color: appColors(context).muted,
            ),
            const SizedBox(height: 10),
            Text(
              AppL10n.of(context).favoritesEmptyTitle,
              style: AppText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.of(context).favoritesEmptyHint,
              style: AppText.meta(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteFilterPill extends StatelessWidget {
  const _FavoriteFilterPill({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? c.accent.withValues(alpha: 0.5) : c.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fiber_new_rounded,
              size: 14,
              color: active ? c.accent : c.muted,
            ),
            const SizedBox(width: 4),
            Text(
              AppL10n.of(context).badgeNewResources,
              style: TextStyle(
                color: active ? c.accent : c.text,
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

// ============ List row (滑动可移除) ============
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.movie,
    required this.urlBuilder,
    required this.swipeGroup,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onRemove,
  });

  final MovieListItem movie;
  final String Function(String) urlBuilder;
  final SwipeActionGroup swipeGroup;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
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
                  color: selected ? c.accent : c.muted2,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PrivacyText(
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
                    ),
                    if (!selecting && movie.hasNewResources) ...[
                      const SizedBox(width: 6),
                      const NewResourcesIcon(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (movie.year != null) '${movie.year}',
                    if (movie.runtime != null && movie.runtime! > 0)
                      l.mediaDurationMinutes(movie.runtime!),
                    if (movie.rating != null && movie.rating! > 0)
                      '★ ${movie.rating!.toStringAsFixed(1)}',
                  ].join(' · '),
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
            movieId: movie.id,
            onTap: onTap,
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

    // 左滑双逻辑：展开点击移除，或滑到头/快速左甩直接执行。
    return SwipeActionCell(
      group: swipeGroup,
      cellKey: movie.id,
      enabled: true,
      actions: [
        SwipeActionData(
          icon: Icons.delete_outline,
          label: AppL10n.of(context).remove,
          color: c.danger,
          onPressed: onRemove,
        ),
      ],
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
    final localStats = FavoriteStats.fromMovies(items);

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
      child: Builder(
        builder: (context) {
          final l = AppL10n.of(context);
          return Row(
            children: [
              cell(
                l.statSaved,
                totalCount > 0 ? '$totalCount' : '${items.length}',
                first: true,
              ),
              cell(l.statWatched, '${localStats.watchedCount}'),
              cell(l.statMinutes, '${localStats.watchedMinutes}'),
            ],
          );
        },
      ),
    );
  }
}

class _ListsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider);
    return LayoutBuilder(
      builder: (ctx, cons) {
        // 卡片尺寸沿用两侧 22 留白的可用宽度，列表本身全宽可滚到屏幕边缘
        final cardWidth = collectionCardWidth(cons.maxWidth - 44);
        return SizedBox(
          height: cardWidth / (5 / 3),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: lists.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              if (index == lists.length) {
                // "+ 新建集合" 卡片
                return SizedBox(width: cardWidth, child: _NewListCard());
              }
              return SizedBox(
                width: cardWidth,
                child: _ListCard(list: lists[index]),
              );
            },
          ),
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list});

  final FavoriteList list;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final displayName = favoriteListDisplayName(l, list);
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
                                horizontal: 7,
                                vertical: 2,
                              ),
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
                            displayName,
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
                            l.listHeroCount(list.count),
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
                AppL10n.of(context).newList,
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
          title: Text(AppL10n.of(context).newList),
          content: StatefulBuilder(
            builder: (sctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: AppL10n.of(context).listNameHint,
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
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
                                    color: AppHues.top(
                                      hue,
                                    ).withValues(alpha: 0.4),
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
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppL10n.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(AppL10n.of(context).listCreate),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      await ref
          .read(listsProvider.notifier)
          .create(name: name, hue: selectedHue);
      AppHaptics.medium();
    }
  }
}
