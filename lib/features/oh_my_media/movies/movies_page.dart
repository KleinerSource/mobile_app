import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/media_list_row.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/selection_controller.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:omm/shared/preview/preview_player.dart';
import 'package:omm/shared/preview/preview_visibility.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_providers.dart';
import 'advanced_filter_sheet.dart';
import 'batch_download_sheet.dart';
import 'batch_duplicate_nfo_sheet.dart';
import 'batch_edit_sheet.dart';
import 'batch_merge_sheet.dart';
import 'movie_data_changes.dart';
import 'movie_filter.dart';
import 'movies_providers.dart';
import 'resource_scan_progress_sheet.dart';
import 'omm_movie_preview_card.dart';

const _moviesViewModeKey = 'movies.view_mode.v1';

class MoviesPage extends ConsumerStatefulWidget {
  const MoviesPage({
    super.key,
    this.initialFilter = const MovieFilter(),
    this.maxItems,
  });

  final MovieFilter initialFilter;
  final int? maxItems;

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  static const _pageSize = 50;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  late MovieFilter _currentFilter;
  MediaViewMode _viewMode = MediaViewMode.portrait;
  int _totalCount = 0;
  int? _autoPreviewId;
  Timer? _autoPreviewDebounce;
  final _previewViewportKey = GlobalKey();
  final _previewItemKeys = <int, GlobalKey>{};
  final _previewCoordinator = PreviewCoordinator();

  late final SelectionController<int> _selection;
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  Completer<void>? _refreshCompleter;
  bool _resourceScanStarting = false;

  @override
  void initState() {
    super.initState();
    _selection = SelectionController<int>();
    _selection.activeListenable.addListener(_onSelectionModeChanged);
    _currentFilter = widget.initialFilter;
    _viewMode = _loadViewMode();
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_closeSwipeOnScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAutoPreviewUpdate();
    });
  }

  MediaViewMode _loadViewMode() {
    return mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_moviesViewModeKey),
    );
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    _scheduleAutoPreviewUpdate();
    await ref
        .read(sharedPrefsProvider)
        .setString(
          _moviesViewModeKey,
          mode == MediaViewMode.portrait ? 'grid' : mode.name,
        );
  }

  @override
  void dispose() {
    _completeRefresh();
    _autoPreviewDebounce?.cancel();
    _scrollController.removeListener(_closeSwipeOnScroll);
    _previewCoordinator.dispose();
    _openSwipe.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  bool get _selectionMode => _selection.isActive;
  Set<int> get _selectedIds => _selection.selected;

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
    if (_viewMode != MediaViewMode.landscape || _selectionMode) return null;
    final items = _controller.itemList ?? const <MovieListItem>[];
    if (items.isEmpty) return null;
    final width = (MediaQuery.sizeOf(context).width - 44).clamp(
      1.0,
      double.infinity,
    );
    final coverHeight = width * 9 / 16;
    final actualIndex = previewItemIndexForViewportKeys(
      itemKeys: items.map((item) => _previewItemKeys[item.id]),
      viewportKey: _previewViewportKey,
      coverHeight: coverHeight,
    );
    final index =
        actualIndex ??
        previewItemIndexForScroll(
          scrollOffset: _scrollController.hasClients
              ? _scrollController.offset
              : 0,
          cardHeight: coverHeight,
          itemGap: 14,
          itemCount: items.length,
        );
    return index == null ? null : items[index].id;
  }

  Future<void> _fetch(int offset) async {
    try {
      final maxItems = widget.maxItems;
      if (maxItems != null && offset >= maxItems) {
        _controller.appendLastPage(const <MovieListItem>[]);
        return;
      }
      final repo = ref.read(mediaRepositoryProvider);
      final requestLimit = maxItems == null
          ? _pageSize
          : (maxItems - offset).clamp(1, _pageSize).toInt();
      final page = await repo.list(
        _currentFilter,
        limit: requestLimit,
        offset: offset,
      );
      final items = maxItems == null
          ? page.items
          : page.items.take(maxItems - offset).toList();
      _totalCount = maxItems == null
          ? page.totalCount
          : page.totalCount.clamp(0, maxItems).toInt();
      applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: items,
        totalCount: _totalCount,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
      if (offset == 0) _completeRefresh();
      if (mounted) setState(() {});
      _scheduleAutoPreviewUpdate();
    } catch (e) {
      _controller.error = toApiException(e).message;
      if (offset == 0) _completeRefresh();
    }
  }

  Future<void> _refreshMovies() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    refreshImageCache(ref);
    final completer = Completer<void>();
    _refreshCompleter = completer;
    _reload();
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _applyFilter(MovieFilter newFilter) {
    if (newFilter == _currentFilter) return;
    setState(() => _currentFilter = newFilter);
    ref.read(movieFilterProvider.notifier).state = newFilter;
    _reload();
  }

  void _reload({bool preserveScroll = false}) {
    _scrollRestorer.prepare(_scrollController, preserve: preserveScroll);
    _controller.refresh();
  }

  void _handleMovieTap(MovieListItem item) {
    if (_selectionMode) {
      _toggleSelect(item.id);
      return;
    }
    unawaited(_openMovie(item));
  }

  Future<void> _openMovie(MovieListItem item) async {
    final changesBeforeVisit = MovieDataChanges.snapshot(movieId: item.id);
    final acknowledge = item.hasNewResources
        ? ref.read(mediaRepositoryProvider).acknowledgeResources(item.id)
        : null;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailPage(
          movieId: item.id,
          acknowledgeNewResources: acknowledge == null,
        ),
      ),
    );

    if (mounted && acknowledge != null) {
      try {
        await acknowledge;
        // 只有确知存在新资源标记的确认才是真实变更(徽标需要消失)。
        MovieDataChanges.bumpMetadata(movieId: item.id);
      } catch (_) {
        if (!mounted) return;
        try {
          await ref.read(mediaRepositoryProvider).acknowledgeResources(item.id);
          MovieDataChanges.bumpMetadata(movieId: item.id);
        } catch (_) {
          // 确认失败时保留当前项，下一次查看或刷新时重试。
        }
      }
    }
    if (!mounted) return;
    // 详情页内没有任何真实变更(编辑/播放/确认资源等)时沿用缓存,不刷新。
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
        final maxItems = widget.maxItems;
        final requestLimit = maxItems == null
            ? limit
            : limit.clamp(1, maxItems).toInt();
        final page = await ref
            .read(mediaRepositoryProvider)
            .list(_currentFilter, limit: requestLimit, offset: 0);
        final items = maxItems == null
            ? page.items
            : page.items.take(maxItems).toList();
        _totalCount = maxItems == null
            ? page.totalCount
            : page.totalCount.clamp(0, maxItems).toInt();
        return maxItems == null
            ? page
            : PagedResult<MovieListItem>(
                items: items,
                totalCount: _totalCount,
                limit: requestLimit,
                offset: 0,
              );
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  Future<void> _openAdvancedFilter() async {
    final next = await AdvancedFilterSheet.show(
      context,
      initial: _currentFilter,
    );
    if (next != null && next != _currentFilter) {
      _applyFilter(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = appColors(context);
    final l = AppL10n.of(context);
    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = w > 600 ? 4 : 3;

    return DefaultTextStyle.merge(
      // 影片库会被底部导航和首页路由复用,不要继承入口按钮的文字装饰。
      style: const TextStyle(decoration: TextDecoration.none),
      child: PopScope(
        canPop: !_selectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectionMode) _exitSelection();
        },
        child: GlowBackground(
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // 固定 header:标题行 + 筛选按钮行,不随内容滚动。
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppL10n.of(
                                    context,
                                  ).libraryTitle.toUpperCase(),
                                  style: AppText.eyebrow(context),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _totalCount > 0 ? '$_totalCount' : '—',
                                      style: AppText.pageTitle(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppL10n.of(context).libraryCountSuffix,
                                      style: TextStyle(
                                        color: c.muted,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SortButton(
                            sortBy: _currentFilter.sortBy,
                            sortOrder: _currentFilter.sortOrder,
                            onChanged: (sortBy, sortOrder) => _applyFilter(
                              _currentFilter.copyWith(
                                sortBy: sortBy,
                                sortOrder: sortOrder,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterButton(
                            activeCount: _currentFilter.activeAdvancedCount,
                            onTap: _openAdvancedFilter,
                          ),
                          const SizedBox(width: 8),
                          MediaViewModeToggle(
                            mode: _viewMode,
                            onChanged: (m) => unawaited(_setViewMode(m)),
                          ),
                        ],
                      ),
                    ),
                    // 底部边距放在固定区内,滚动内容始终与按钮行保持间距。
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          children: [
                            _UpdatedDropdownChip(
                              value: _currentFilter.isUpdated,
                              onChanged: (v) => _applyFilter(
                                _currentFilter.copyWith(
                                  isUpdated: v,
                                  clearIsUpdated: v == null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            CompactFilterButton(
                              label: l.moviesFilterDuplicateNum,
                              icon: Icons.copy_all_outlined,
                              active: _currentFilter.duplicateNum,
                              onTap: () => _applyFilter(
                                _currentFilter.copyWith(
                                  duplicateNum: !_currentFilter.duplicateNum,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            CompactFilterButton(
                              label: l.moviesFilterNewResources,
                              icon: Icons.fiber_new_rounded,
                              active: _currentFilter.hasNewResources == true,
                              onTap: () {
                                final enabled =
                                    _currentFilter.hasNewResources == true;
                                _applyFilter(
                                  _currentFilter.copyWith(
                                    hasNewResources: enabled ? null : true,
                                    clearHasNewResources: enabled,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 7),
                            CompactFilterButton(
                              label: _resourceScanStarting
                                  ? l.moviesScanning
                                  : l.moviesScanResources,
                              icon: _resourceScanStarting
                                  ? Icons.sync_rounded
                                  : Icons.cloud_download_outlined,
                              active: _resourceScanStarting,
                              onTap: _resourceScanStarting
                                  ? () {}
                                  : () => _startResourceScan(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: StatusBarScrollToTop(
                        scrollController: _scrollController,
                        child: RefreshIndicator(
                          onRefresh: _refreshMovies,
                          child: DragSelectionScope<int>(
                            scrollController: _scrollController,
                            selectionLayout: _viewMode == MediaViewMode.portrait
                                ? DragSelectionLayout.grid
                                : DragSelectionLayout.list,
                            isSelected: _selection.contains,
                            onSelectionStart: _startSelectionSweep,
                            onSelectionChanged: _applySelectionSweep,
                            onSelectionEnd: _finishSelectionSweep,
                            selectionMode: _selectionMode,
                            child: CustomScrollView(
                              key: _previewViewportKey,
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
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
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                childAspectRatio:
                                                    MediaCardTemplate
                                                        .gridChildAspectRatio,
                                                mainAxisSpacing: 14,
                                                crossAxisSpacing: 10,
                                              ),
                                          builderDelegate: _buildDelegate(
                                            urlBuilder,
                                            crossAxisCount: crossAxisCount,
                                          ),
                                        )
                                      : _viewMode == MediaViewMode.landscape
                                      ? PagedSliverList<int, MovieListItem>(
                                          pagingController: _controller,
                                          builderDelegate: _buildDelegate(
                                            urlBuilder,
                                            crossAxisCount: crossAxisCount,
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
                if (_selectionMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ValueListenableBuilder<Set<int>>(
                      valueListenable: _selection.selectedListenable,
                      builder: (context, selected, _) => EntityBatchToolbar(
                        selectedCount: selected.length,
                        onSelectAll: _selectAllLoaded,
                        onClear: _selection.clear,
                        onClose: _exitSelection,
                        actions: [
                          EntityBatchAction(
                            icon: Icons.edit_outlined,
                            label: l.moviesBatchEdit,
                            onTap: selected.isEmpty ? null : _onBatchEdit,
                          ),
                          EntityBatchAction(
                            icon: Icons.cloud_download_outlined,
                            label: l.moviesBatchDownload,
                            color: const Color(0xFF34F5A5),
                            onTap: selected.isEmpty ? null : _onBatchDownload,
                          ),
                          EntityBatchAction(
                            icon: Icons.sync_rounded,
                            label: l.moviesBatchScan,
                            onTap: selected.isEmpty
                                ? null
                                : _onBatchResourceScan,
                          ),
                          if (_canMergeOrCompare)
                            EntityBatchAction(
                              icon: Icons.compare_arrows_rounded,
                              label: l.moviesBatchCompare,
                              onTap: _onBatchCompareNfo,
                            ),
                          if (_canMergeOrCompare)
                            EntityBatchAction(
                              icon: Icons.merge_rounded,
                              label: l.moviesBatchMerge,
                              color: c.warning,
                              onTap: _onBatchMerge,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildDelegate(
    String Function(String) urlBuilder, {
    required int crossAxisCount,
    bool landscape = false,
  }) {
    final l = AppL10n.of(context);
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) {
        final card = DragSelectionTarget<int>(
          key: ValueKey(item.id),
          id: item.id,
          selectionIndex: landscape ? null : idx,
          selectionHandleAlignment: landscape
              ? Alignment.centerLeft
              : Alignment.topLeft,
          child: ValueListenableBuilder<Set<int>>(
            valueListenable: _selection.selectedListenable,
            builder: (context, selected, _) => landscape
                ? OmmMoviePreviewCard(
                    key: _previewItemKeys.putIfAbsent(item.id, GlobalKey.new),
                    movie: item,
                    posterUrlBuilder: urlBuilder,
                    coordinator: _previewCoordinator,
                    autoPlayPreview: item.id == _autoPreviewId,
                    selecting: _selectionMode,
                    selected: selected.contains(item.id),
                    onTap: () => _handleMovieTap(item),
                  )
                : SelectableMovieCard(
                    movie: item,
                    posterUrlBuilder: urlBuilder,
                    landscape: false,
                    selecting: _selectionMode,
                    selected: selected.contains(item.id),
                    onTap: () => _handleMovieTap(item),
                  ),
          ),
        );
        return landscape
            ? Padding(padding: const EdgeInsets.only(bottom: 14), child: card)
            : card;
      },
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? l.loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      newPageErrorIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () => _controller.retryLastFailedRequest(),
          child: Text(l.loadFailedRetry),
        ),
      ),
      noItemsFoundIndicatorBuilder: (_) => EmptyView(message: l.noResultFound),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildListDelegate(
    String Function(String) urlBuilder,
  ) {
    final l = AppL10n.of(context);
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => DragSelectionTarget<int>(
        key: ValueKey(item.id),
        id: item.id,
        selectionHandleAlignment: Alignment.centerLeft,
        child: ValueListenableBuilder<Set<int>>(
          valueListenable: _selection.selectedListenable,
          builder: (context, selected, _) => _ListRow(
            movie: item,
            urlBuilder: urlBuilder,
            swipeGroup: _openSwipe,
            selectionMode: _selectionMode,
            selected: selected.contains(item.id),
            onSelectionTap: () => _toggleSelect(item.id),
            onMovieTap: () => _openMovie(item),
            onFavorite: (isFavorited) =>
                unawaited(_toggleFavorite(item, isFavorited)),
          ),
        ),
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? l.loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) => EmptyView(message: l.noResultFound),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }

  // ===== 选择模式 =====

  void _startSelectionSweep(int id, bool selected) {
    _selection.enter();
    _selection.setSelected(id, selected);
  }

  void _applySelectionSweep(int id, bool selected) {
    _selection.setSelected(id, selected);
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedIds.isEmpty) {
      _exitSelection();
    }
  }

  void _toggleSelect(int id) => _selection.toggle(id);

  void _exitSelection() => _selection.exit();

  Future<void> _toggleFavorite(MovieListItem movie, bool isFavorited) async {
    final nextValue = !isFavorited;
    try {
      final repository = ref.read(favoritesRepositoryProvider);
      if (isFavorited) {
        await repository.removeBatch([movie.id]);
      } else {
        await repository.addBatch([movie.id]);
      }
      ref.read(favoriteStatusProvider.notifier).seed(movie.id, nextValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? AppL10n.of(context).moviesFavoriteAdded(movie.title)
                : AppL10n.of(context).moviesFavoriteRemoved(movie.title),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).moviesOperationFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <MovieListItem>[];
    _selection.selectAll(loaded.map((m) => m.id));
  }

  /// 选中影片的番号集合
  Set<String> _selectedNums() {
    final loaded = _controller.itemList ?? const <MovieListItem>[];
    return loaded
        .where((m) => _selectedIds.contains(m.id))
        .map((m) => (m.num ?? '').trim().toUpperCase())
        .where((n) => n.isNotEmpty)
        .toSet();
  }

  bool get _canMergeOrCompare {
    if (_selectedIds.length < 2) return false;
    final nums = _selectedNums();
    return nums.length == 1;
  }

  Future<void> _onBatchEdit() async {
    final ok = await BatchEditSheet.show(context, _selectedIds.toList());
    if (ok == true) {
      _exitSelection();
      _reload(preserveScroll: true);
    }
  }

  Future<void> _onBatchDownload() async {
    final ok = await BatchDownloadSheet.show(context, _selectedIds.toList());
    if (ok == true) _exitSelection();
  }

  Future<void> _onBatchResourceScan() async {
    if (_selectedIds.isEmpty) return;
    await _startResourceScan(movieIds: _selectedIds.toList());
  }

  Future<void> _startResourceScan({List<int>? movieIds}) async {
    if (_resourceScanStarting) return;
    final selected = movieIds != null && movieIds.isNotEmpty;
    final count = selected ? movieIds.length : _totalCount;
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).moviesNoScannable)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          selected
              ? AppL10n.of(context).moviesScanSelectedTitle
              : AppL10n.of(context).moviesScanFilteredTitle,
        ),
        content: Text(
          selected
              ? AppL10n.of(context).moviesScanSelectedMessage(count)
              : AppL10n.of(context).moviesScanFilteredMessage(count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppL10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppL10n.of(context).moviesStartScan),
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
            movieIds: selected ? movieIds : null,
            filter: _currentFilter,
          );
      if (!mounted) return;
      if (selected) _exitSelection();
      setState(() => _resourceScanStarting = false);
      final skippedText = result.skippedCount > 0
          ? AppL10n.of(context).moviesScanSkipped(result.skippedCount)
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).moviesScanSubmitted(result.acceptedCount, skippedText),
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
            ).moviesScanCreateFailed(toApiException(e).message),
          ),
        ),
      );
    }
  }

  Future<void> _onBatchMerge() async {
    if (!_canMergeOrCompare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).moviesNeedSameNumber)),
      );
      return;
    }
    final ok = await BatchMergeSheet.show(context, _selectedIds.toList());
    if (ok == true) {
      _exitSelection();
      _reload(preserveScroll: true);
    }
  }

  Future<void> _onBatchCompareNfo() async {
    if (!_canMergeOrCompare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).moviesNeedSameNumber)),
      );
      return;
    }
    final ok = await BatchDuplicateNfoCompareSheet.show(
      context,
      _selectedIds.toList(),
    );
    if (ok == true) {
      _exitSelection();
      _reload(preserveScroll: true);
    }
  }
}

const _kSortOptions = <String>[
  'title',
  'year',
  'rating',
  'file_size',
  'created_at',
  'updated_at',
  'last_downloaded_at',
];

String _sortLabel(AppL10n l, String value) => switch (value) {
  'title' => l.sortByTitle,
  'year' => l.sortByYear,
  'rating' => l.sortByRating,
  'file_size' => l.moviesSortFileSize,
  'created_at' => l.moviesSortCreatedAt,
  'updated_at' => l.moviesSortUpdatedAt,
  'last_downloaded_at' => l.moviesSortDownloadedAt,
  _ => value,
};

String _updatedLabel(AppL10n l, bool? value) => switch (value) {
  true => l.moviesUpdated,
  false => l.moviesNotUpdated,
  _ => l.moviesUpdatedStatus,
};

String _sortOrderLabel(AppL10n l, String value) =>
    value == 'asc' ? l.moviesSortAscending : l.moviesSortDescending;

String _movieRuntimeLabel(AppL10n l, int minutes) =>
    l.mediaDurationMinutes(minutes);

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final active = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.accent.withValues(alpha: 0.5) : c.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: active ? c.accent : c.muted,
            ),
            if (active) ...[
              const SizedBox(width: 5),
              Text(
                '$activeCount',
                style: TextStyle(
                  color: c.accent,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.sortBy,
    required this.sortOrder,
    required this.onChanged,
  });
  final String sortBy;
  final String sortOrder;
  final void Function(String sortBy, String sortOrder) onChanged;

  Future<void> _openMenu(BuildContext context) async {
    final c = appColors(context);
    final l = AppL10n.of(context);
    await showGlassSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.sort_rounded,
              title: l.moviesSortSheetTitle,
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              trailing: GestureDetector(
                onTap: () {
                  final next = sortOrder == 'asc' ? 'desc' : 'asc';
                  Navigator.pop(ctx);
                  onChanged(sortBy, next);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sortOrder == 'asc'
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: c.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortOrderLabel(l, sortOrder),
                        style: TextStyle(
                          color: c.accent,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final opt in _kSortOptions)
              ListTile(
                dense: true,
                title: Text(_sortLabel(l, opt)),
                trailing: opt == sortBy
                    ? Icon(Icons.check_rounded, color: c.accent, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onChanged(opt, sortOrder);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: () => _openMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 15, color: c.muted),
            const SizedBox(width: 5),
            Icon(
              sortOrder == 'asc'
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: c.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// 更新状态下拉 (不限 / 已更新 / 未更新)
class _UpdatedDropdownChip extends StatelessWidget {
  const _UpdatedDropdownChip({required this.value, required this.onChanged});
  final bool? value;
  final ValueChanged<bool?> onChanged;

  Future<void> _openMenu(BuildContext context) async {
    final c = appColors(context);
    final l = AppL10n.of(context);
    await showGlassSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.update_rounded,
              title: l.moviesUpdatedStatus,
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
            ),
            for (final opt in <({bool? v, String label})>[
              (v: null, label: l.moviesUnlimited),
              (v: true, label: l.moviesUpdated),
              (v: false, label: l.moviesNotUpdated),
            ])
              ListTile(
                dense: true,
                title: Text(opt.label),
                trailing: value == opt.v
                    ? Icon(Icons.check_rounded, color: c.accent, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onChanged(opt.v);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final active = value != null;
    final fg = active ? c.accent : c.text;
    final iconColor = active ? c.accent : c.muted;
    return GestureDetector(
      onTap: () => _openMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.accent.withValues(alpha: 0.5) : c.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.update_rounded, size: 15, color: iconColor),
            const SizedBox(width: 5),
            Text(
              _updatedLabel(l, value),
              strutStyle: const StrutStyle(
                fontSize: 11.5,
                height: 1.0,
                forceStrutHeight: true,
              ),
              style: TextStyle(
                color: fg,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.expand_more, size: 14, color: iconColor),
          ],
        ),
      ),
    );
  }
}

class _ListRow extends ConsumerWidget {
  const _ListRow({
    required this.movie,
    required this.urlBuilder,
    required this.swipeGroup,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionTap,
    required this.onMovieTap,
    required this.onFavorite,
  });
  final MovieListItem movie;
  final String Function(String) urlBuilder;
  final SwipeActionGroup swipeGroup;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectionTap;
  final VoidCallback onMovieTap;
  final ValueChanged<bool> onFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final isFavorited = ref.watch(
      favoriteStatusProvider.select(
        (statuses) => statuses[movie.id] ?? movie.isFavorited,
      ),
    );
    final progress = (movie.watchRecord?.progressRatio ?? 0).clamp(0.0, 1.0);
    final completed = movie.watchRecord?.completed ?? false;
    final hasRating = movie.rating != null && movie.rating! > 0;
    final meta = <String>[
      if (movie.year != null) '${movie.year}',
      if (movie.runtime != null && movie.runtime! > 0)
        _movieRuntimeLabel(l, movie.runtime!),
      if (hasRating) '★ ${movie.rating!.toStringAsFixed(1)}',
    ].join(' · ');

    final row = MediaListRow(
      thumbnailWidth: 56,
      thumbnailHeight: 84,
      thumbnailTextGap: 14,
      thumbnail: PrivacyMask(
        movieId: movie.id,
        radius: 8,
        child: Poster(
          url: movie.posterUuid != null ? urlBuilder(movie.posterUuid!) : null,
          title: movie.title,
          year: movie.year,
          radius: 8,
        ),
      ),
      leading: selectionMode
          ? Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? c.accent : c.muted,
              size: 22,
            )
          : null,
      leadingGap: 10,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PrivacyText(
              movieId: movie.id,
              text: movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
          if (!selectionMode && movie.hasNewResources) ...[
            const SizedBox(width: 6),
            const NewResourcesIcon(),
          ],
        ],
      ),
      meta: meta.isNotEmpty ? Text(meta, style: AppText.meta(context)) : null,
      additional: !completed && progress > 0
          ? Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: c.chipBg,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : null,
      trailing: completed
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                AppL10n.of(context).watchedDone,
                style: TextStyle(
                  color: c.accent,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            )
          : Icon(Icons.chevron_right, color: c.muted, size: 20),
      privacyId: movie.id,
      privacyAwareTap: true,
      onTap: selectionMode ? onSelectionTap : onMovieTap,
    );

    if (selectionMode) return row;

    // 左滑双逻辑：展开点击收藏，或滑到头/快速左甩直接执行。
    return SwipeActionCell(
      group: swipeGroup,
      cellKey: movie.id,
      enabled: true,
      actions: [
        SwipeActionData(
          icon: Icons.favorite_rounded,
          label: isFavorited ? l.moviesUnfavorite : l.moviesFavorite,
          color: isFavorited ? c.danger : c.accent,
          onPressed: () => onFavorite(isFavorited),
        ),
      ],
      child: row,
    );
  }
}
