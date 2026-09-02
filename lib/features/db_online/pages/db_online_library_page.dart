import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

/// DBO 影片库。
///
/// 影片库只展示支持在线播放的影片，分类通过 `filter_by` 第一段切换：
/// 0 有码、1 无码、2 欧美、3 FC2、4 动漫。
class DbOnlineLibraryPage extends ConsumerStatefulWidget {
  const DbOnlineLibraryPage({super.key});

  @override
  ConsumerState<DbOnlineLibraryPage> createState() =>
      _DbOnlineLibraryPageState();
}

class _DbOnlineLibraryPageState extends ConsumerState<DbOnlineLibraryPage> {
  static const _pageSize = 24;
  static const _categoryOptions = <({String value, String label})>[
    (value: '0', label: '有码'),
    (value: '1', label: '无码'),
    (value: '2', label: '欧美'),
    (value: '3', label: 'FC2'),
    (value: '4', label: '动漫'),
  ];
  static const _sortOptions = <({String value, String label})>[
    (value: 'update', label: '最近更新'),
    (value: 'release', label: '最新上架'),
  ];

  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();
  Completer<void>? _refreshCompleter;
  String _category = '0';
  String _sortBy = 'update';
  String _orderBy = 'desc';
  int _requestSerial = 0;

  String get _filterBy => '$_category:t:p::::';

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _completeRefresh();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    final requestSerial = _requestSerial;
    try {
      final result = await ref.read(
        dbOnlineLibraryPageProvider(
          DbOnlineLibraryPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            page: page,
            limit: _pageSize,
            filterBy: _filterBy,
            sortBy: _sortBy,
            orderBy: _orderBy,
          ),
        ).future,
      );
      if (!mounted || requestSerial != _requestSerial) return;

      final current = _controller.itemList ?? const <DbOnlineMovie>[];
      final seen = <String>{for (final movie in current) _movieKey(movie)};
      final items = result.movies
          .where((movie) => seen.add(_movieKey(movie)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.movies.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _controller.appendLastPage(items);
      } else {
        _controller.appendPage(items, page + 1);
      }
      if (page == 1) _completeRefresh();
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
      if (page == 1) _completeRefresh();
    }
  }

  String _movieKey(DbOnlineMovie movie) {
    final id = movie.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'number:${movie.number.trim()}';
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

  void _reloadWith({String? category, String? sortBy, String? orderBy}) {
    final nextCategory = category ?? _category;
    final nextSortBy = sortBy ?? _sortBy;
    final nextOrderBy = orderBy ?? _orderBy;
    if (nextCategory == _category &&
        nextSortBy == _sortBy &&
        nextOrderBy == _orderBy) {
      return;
    }
    setState(() {
      _category = nextCategory;
      _sortBy = nextSortBy;
      _orderBy = nextOrderBy;
    });
    _requestSerial++;
    _controller.refresh();
  }

  Future<void> _openCategoryMenu(BuildContext context) async {
    final colors = appColors(context);
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(
                icon: Icons.tune_rounded,
                title: '筛选影片类型',
                subtitle: '仅在线播',
                padding: EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              for (final option in _categoryOptions)
                ListTile(
                  dense: true,
                  title: Text(option.label),
                  trailing: option.value == _category
                      ? Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(category: option.value);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSortMenu(BuildContext context) async {
    final colors = appColors(context);
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.sort_rounded,
                title: '排序',
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                trailing: _LibraryOrderButton(
                  ascending: _orderBy == 'asc',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(orderBy: _orderBy == 'asc' ? 'desc' : 'asc');
                  },
                ),
              ),
              for (final option in _sortOptions)
                ListTile(
                  dense: true,
                  title: Text(option.label),
                  trailing: option.value == _sortBy
                      ? Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(sortBy: option.value);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
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

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
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
                        Text('DBONLINE', style: AppText.eyebrow(context)),
                        const SizedBox(height: 3),
                        Text('影片库', style: AppText.pageTitle(context)),
                      ],
                    ),
                  ),
                  _LibrarySortButton(
                    ascending: _orderBy == 'asc',
                    onTap: () => _openSortMenu(context),
                  ),
                  const SizedBox(width: 8),
                  _LibraryFilterButton(
                    active: _category != '0',
                    onTap: () => _openCategoryMenu(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StatusBarScrollToTop(
                scrollController: _scrollController,
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        sliver: PagedSliverGrid<int, DbOnlineMovie>(
                          pagingController: _controller,
                          // 尾部提示整行跨列渲染（与 OMM 影片库一致）。
                          showNoMoreItemsIndicatorAsGridChild: false,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.5,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: spacing,
                              ),
                          builderDelegate:
                              PagedChildBuilderDelegate<DbOnlineMovie>(
                                itemBuilder: (context, movie, index) =>
                                    DbOnlineMovieCard(
                                      key: ValueKey(_movieKey(movie)),
                                      movie: movie,
                                      config: config,
                                      width: itemWidth,
                                      onTap: () => openDbOnlineMovieUnawaited(
                                        context,
                                        movie,
                                      ),
                                    ),
                                firstPageProgressIndicatorBuilder: (_) =>
                                    Padding(
                                      padding: const EdgeInsets.only(top: 56),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: colors.accent,
                                        ),
                                      ),
                                    ),
                                newPageProgressIndicatorBuilder: (_) =>
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                firstPageErrorIndicatorBuilder: (_) =>
                                    _LibraryListError(
                                      message:
                                          _controller.error?.toString() ??
                                          '加载失败',
                                      onRetry:
                                          _controller.retryLastFailedRequest,
                                    ),
                                newPageErrorIndicatorBuilder: (_) =>
                                    PaginationRetry(
                                      onRetry:
                                          _controller.retryLastFailedRequest,
                                    ),
                                noItemsFoundIndicatorBuilder: (_) =>
                                    const _LibraryListEmpty(),
                                noMoreItemsIndicatorBuilder: (_) =>
                                    const NoMoreContent(),
                              ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryListError extends StatelessWidget {
  const _LibraryListError({required this.message, required this.onRetry});

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
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _LibraryListEmpty extends StatelessWidget {
  const _LibraryListEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(child: Text('暂无符合条件的影片', style: AppText.meta(context))),
    );
  }
}

class _LibraryFilterButton extends StatelessWidget {
  const _LibraryFilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.accent.withValues(alpha: 0.15) : colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? colors.accent.withValues(alpha: 0.5)
                : colors.cardBorder,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          size: 15,
          color: active ? colors.accent : colors.muted,
        ),
      ),
    );
  }
}

class _LibrarySortButton extends StatelessWidget {
  const _LibrarySortButton({required this.ascending, required this.onTap});

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 15, color: colors.muted),
            const SizedBox(width: 5),
            Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: colors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryOrderButton extends StatelessWidget {
  const _LibraryOrderButton({required this.ascending, required this.onTap});

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: colors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              ascending ? '升序' : '降序',
              style: TextStyle(
                color: colors.accent,
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
