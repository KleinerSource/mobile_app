import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/poster.dart';
import '../movie_detail/movie_detail_page.dart';
import '../privacy/privacy_mask.dart';
import 'advanced_filter_sheet.dart';
import 'batch_download_sheet.dart';
import 'batch_duplicate_nfo_sheet.dart';
import 'batch_edit_sheet.dart';
import 'batch_merge_sheet.dart';
import 'movie_filter.dart';
import 'movies_providers.dart';
import 'resource_scan_progress_sheet.dart';

enum _ViewMode { grid, list }

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
  final _searchController = TextEditingController();
  late MovieFilter _currentFilter;
  _ViewMode _viewMode = _ViewMode.grid;
  int _totalCount = 0;

  // 选择模式状态
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  Completer<void>? _refreshCompleter;
  bool _resourceScanStarting = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _completeRefresh();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final maxItems = widget.maxItems;
      if (maxItems != null && offset >= maxItems) {
        _controller.appendLastPage(const <MovieListItem>[]);
        return;
      }
      final repo = ref.read(moviesRepositoryProvider);
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
      final nextOffset = offset + items.length;
      if (nextOffset >= _totalCount || items.isEmpty) {
        _controller.appendLastPage(items);
      } else {
        _controller.appendPage(items, nextOffset);
      }
      if (offset == 0) _completeRefresh();
      if (mounted) setState(() {});
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
    _controller.refresh();
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
    _controller.refresh();
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
            RefreshIndicator(
              onRefresh: _refreshMovies,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppL10n.of(context).libraryTitle.toUpperCase(),
                        style: AppText.eyebrow(context)),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: _SearchBar(
                  controller: _searchController,
                  onSubmitted: (v) => _applyFilter(_currentFilter.copyWith(search: v)),
                ),
              ),
            ),
            SliverToBoxAdapter(
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
                    _QuickChip(
                      label: '新资源',
                      icon: Icons.fiber_new_rounded,
                      active: _currentFilter.hasNewResources == true,
                      onTap: () {
                        final enabled = _currentFilter.hasNewResources == true;
                        _applyFilter(
                          _currentFilter.copyWith(
                            hasNewResources: enabled ? null : true,
                            clearHasNewResources: enabled,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 7),
                    _QuickChip(
                      label: '重复番号',
                      icon: Icons.copy_all_outlined,
                      active: _currentFilter.duplicateNum,
                      onTap: () => _applyFilter(
                        _currentFilter.copyWith(
                          duplicateNum: !_currentFilter.duplicateNum,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _QuickChip(
                      label: _resourceScanStarting ? '扫描中' : '扫描资源',
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppL10n.of(context).sortedByOnly(
                          _sortLabel(context, _currentFilter.sortBy),
                        ),
                        style: TextStyle(
                          color: c.muted,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
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
                    _ViewModeToggle(
                      mode: _viewMode,
                      onChanged: (m) => setState(() => _viewMode = m),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              sliver: _viewMode == _ViewMode.grid
                  ? PagedSliverGrid<int, MovieListItem>(
                      pagingController: _controller,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.5,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 10,
                      ),
                      builderDelegate: _buildDelegate(urlBuilder),
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
        if (_selectionMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BatchActionBar(
              selectedCount: _selectedIds.length,
              canMergeOrCompare: _canMergeOrCompare,
              onSelectAll: _selectAllLoaded,
              onClear: () => setState(() => _selectedIds.clear()),
              onClose: _exitSelection,
              onEdit: _onBatchEdit,
              onDownload: _onBatchDownload,
              onResourceScan: _onBatchResourceScan,
              onCompare: _onBatchCompareNfo,
              onMerge: _onBatchMerge,
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
    String Function(String) urlBuilder,
  ) {
    final l = AppL10n.of(context);
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => MovieCard(
        movie: item,
        posterUrlBuilder: urlBuilder,
        selectionMode: _selectionMode,
        selected: _selectedIds.contains(item.id),
        onTap: () {
          if (_selectionMode) {
            _toggleSelect(item.id);
          } else {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                  builder: (_) => MovieDetailPage(movieId: item.id)),
            );
          }
        },
        onLongPress: () => _enterSelectionWith(item.id),
      ),
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
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildListDelegate(
    String Function(String) urlBuilder,
  ) {
    final l = AppL10n.of(context);
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => _ListRow(
        movie: item,
        urlBuilder: urlBuilder,
        selectionMode: _selectionMode,
        selected: _selectedIds.contains(item.id),
        onSelectionTap: () => _toggleSelect(item.id),
        onLongPress: () => _enterSelectionWith(item.id),
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? l.loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) => EmptyView(message: l.noResultFound),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }

  // ===== 选择模式 =====

  void _enterSelectionWith(int id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllLoaded() {
    final loaded = _controller.itemList ?? const <MovieListItem>[];
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(loaded.map((m) => m.id));
    });
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
      _controller.refresh();
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
        const SnackBar(content: Text('当前没有可扫描的影片')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(selected ? '扫描已选影片' : '扫描筛选结果'),
        content: Text(
          selected
              ? '将扫描已选的 $count 部影片，确定继续吗？'
              : '将扫描当前筛选结果中的 $count 部影片（包含全部分页），确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('开始扫描'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resourceScanStarting = true);
    try {
      final result = await ref.read(moviesRepositoryProvider).startResourceScan(
            movieIds: selected ? movieIds : null,
            filter: _currentFilter,
          );
      if (!mounted) return;
      if (selected) _exitSelection();
      setState(() => _resourceScanStarting = false);
      final skippedText = result.skippedCount > 0
          ? '，跳过 ${result.skippedCount} 部无效影片'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已提交 ${result.acceptedCount} 部影片$skippedText')),
      );
      await ResourceScanProgressSheet.show(
        context,
        taskId: result.taskId,
        onCompleted: () {
          if (mounted) _controller.refresh();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resourceScanStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建资源扫描任务失败: ${toApiException(e).message}')),
      );
    }
  }

  Future<void> _onBatchMerge() async {
    if (!_canMergeOrCompare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需选择 2 部以上相同番号影片')),
      );
      return;
    }
    final ok = await BatchMergeSheet.show(context, _selectedIds.toList());
    if (ok == true) {
      _exitSelection();
      _controller.refresh();
    }
  }

  Future<void> _onBatchCompareNfo() async {
    if (!_canMergeOrCompare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需选择 2 部以上相同番号影片')),
      );
      return;
    }
    final ok = await BatchDuplicateNfoCompareSheet.show(
        context, _selectedIds.toList());
    if (ok == true) {
      _exitSelection();
      _controller.refresh();
    }
  }
}

String _sortLabel(BuildContext context, String key) {
  switch (key) {
    case 'rating':
      return '评分';
    case 'title':
      return '标题';
    case 'year':
      return '年份';
    case 'release_date':
      return '上映日期';
    case 'updated_at':
      return '更新';
    case 'last_downloaded_at':
      return '下载日期';
    case 'file_size':
      return '文件大小';
    case 'created_at':
    default:
      return '创建';
  }
}

const _kSortOptions = <({String value, String label})>[
  (value: 'title', label: '标题'),
  (value: 'year', label: '年份'),
  (value: 'rating', label: '评分'),
  (value: 'file_size', label: '文件大小'),
  (value: 'created_at', label: '创建'),
  (value: 'updated_at', label: '更新'),
  (value: 'last_downloaded_at', label: '下载日期'),
];

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: AppL10n.of(context).searchHintAll,
                hintStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
              ),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    Widget btn(IconData icon, _ViewMode m) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
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
          btn(Icons.grid_view_rounded, _ViewMode.grid),
          btn(Icons.view_list_rounded, _ViewMode.list),
        ],
      ),
    );
  }
}

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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('排序', style: AppText.sectionTitle(ctx)),
                  ),
                  // 升降序 toggle
                  GestureDetector(
                    onTap: () {
                      final next = sortOrder == 'asc' ? 'desc' : 'asc';
                      Navigator.pop(ctx);
                      onChanged(sortBy, next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                            sortOrder == 'asc' ? '升序' : '降序',
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
                ],
              ),
            ),
            const Divider(height: 1),
            for (final opt in _kSortOptions)
              ListTile(
                dense: true,
                title: Text(opt.label),
                trailing: opt.value == sortBy
                    ? Icon(Icons.check_rounded, color: c.accent, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onChanged(opt.value, sortOrder);
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final fg = active ? c.accent : c.text;
    final iconColor = active ? c.accent : c.muted;
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
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

  String get _label => switch (value) {
        true => '已更新',
        false => '未更新',
        _ => '更新状态',
      };

  Future<void> _openMenu(BuildContext context) async {
    final c = appColors(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in const <({bool? v, String label})>[
              (v: null, label: '不限'),
              (v: true, label: '已更新'),
              (v: false, label: '未更新'),
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
              _label,
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

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.movie,
    required this.urlBuilder,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionTap,
    this.onLongPress,
  });
  final MovieListItem movie;
  final String Function(String) urlBuilder;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final progress = (movie.watchRecord?.progressRatio ?? 0).clamp(0.0, 1.0);
    final completed = movie.watchRecord?.completed ?? false;
    final hasRating = movie.rating != null && movie.rating! > 0;
    final meta = <String>[
      if (movie.year != null) '${movie.year}',
      if (movie.runtime != null && movie.runtime! > 0) '${movie.runtime}m',
      if (hasRating) '★ ${movie.rating!.toStringAsFixed(1)}',
    ].join(' · ');

    return PrivacyAwareInkWell(
      movieId: movie.id,
      onTap: selectionMode
          ? onSelectionTap
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MovieDetailPage(movieId: movie.id)),
              ),
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selectionMode) ...[
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? c.accent : c.muted,
                size: 22,
              ),
              const SizedBox(width: 10),
            ],
            SizedBox(
              width: 56,
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrivacyText(
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
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(meta, style: AppText.meta(context)),
                  ],
                  if (!completed && progress > 0) ...[
                    const SizedBox(height: 8),
                    Row(
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
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (completed)
              Container(
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
            else
              Icon(Icons.chevron_right, color: c.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 浮动底部批量操作工具栏 · 编辑/下载/比较/合并
class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedCount,
    required this.canMergeOrCompare,
    required this.onSelectAll,
    required this.onClear,
    required this.onClose,
    required this.onEdit,
    required this.onDownload,
    required this.onResourceScan,
    required this.onCompare,
    required this.onMerge,
  });

  final int selectedCount;
  final bool canMergeOrCompare;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback onResourceScan;
  final VoidCallback onCompare;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final toolbarBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B1A24)
        : Colors.white;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: toolbarBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '$selectedCount 已选',
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onSelectAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: c.danger,
                    ),
                    child: const Text('清空'),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close, size: 18, color: c.muted),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    Expanded(
                      child: _BatchActionButton(
                        icon: Icons.edit_outlined,
                        label: '编辑',
                        onTap: selectedCount > 0 ? onEdit : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _BatchActionButton(
                        icon: Icons.cloud_download_outlined,
                        label: '下载',
                        color: const Color(0xFF34F5A5),
                        onTap: selectedCount > 0 ? onDownload : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _BatchActionButton(
                        icon: Icons.sync_rounded,
                        label: '扫描',
                        onTap: selectedCount > 0 ? onResourceScan : null,
                      ),
                    ),
                    if (canMergeOrCompare) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: _BatchActionButton(
                          icon: Icons.compare_arrows_rounded,
                          label: '比较',
                          onTap: onCompare,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _BatchActionButton(
                          icon: Icons.merge_rounded,
                          label: '合并',
                          color: c.warning,
                          onTap: onMerge,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final enabled = onTap != null;
    final fg = enabled ? (color ?? c.accent) : c.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? fg.withValues(alpha: 0.12) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? fg.withValues(alpha: 0.4) : c.cardBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
