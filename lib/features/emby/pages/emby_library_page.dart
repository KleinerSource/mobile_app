import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/emby/navigation/emby_navigation.dart';
import 'package:omm/features/emby/providers/emby_providers.dart';
import 'package:omm/features/emby/widgets/emby_item_card.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';

/// Emby 媒体库。
///
/// 顶部按 Emby Views（媒体库）切换，类型筛选在电影/剧集/全部间切换；
/// 排序沿用 Emby 的 SortBy 语义，升降序切换与 DBO 影片库一致。
class EmbyLibraryPage extends ConsumerStatefulWidget {
  const EmbyLibraryPage({super.key, this.initialViewId});

  /// 从首页媒体库卡片进入时预选的库；null 保持默认的“全部库”模式。
  final String? initialViewId;

  @override
  ConsumerState<EmbyLibraryPage> createState() => _EmbyLibraryPageState();
}

class _EmbyLibraryPageState extends ConsumerState<EmbyLibraryPage> {
  static const _pageSize = 24;
  static const _typeOptions = <({String value, String label})>[
    (value: 'Movie,Series', label: '全部'),
    (value: 'Movie', label: '电影'),
    (value: 'Series', label: '剧集'),
  ];
  static const _sortOptions = <({String value, String label})>[
    (value: 'DateCreated', label: '最近添加'),
    (value: 'SortName', label: '名称'),
    (value: 'ProductionYear', label: '年份'),
    (value: 'CommunityRating', label: '评分'),
  ];

  final _controller = PagingController<int, EmbyItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  Completer<void>? _refreshCompleter;
  String? _parentId;
  String _includeItemTypes = 'Movie,Series';
  String _sortBy = 'DateCreated';
  String _sortOrder = 'Descending';
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _parentId = widget.initialViewId;
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _completeRefresh();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int startIndex) async {
    final requestSerial = _requestSerial;
    try {
      final result = await ref.read(
        embyItemPageProvider(
          EmbyItemPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            parentId: _parentId,
            includeItemTypes: _includeItemTypes,
            recursive: true,
            sortBy: _sortBy,
            sortOrder: _sortOrder,
            startIndex: startIndex,
            limit: _pageSize,
          ),
        ).future,
      );
      if (!mounted || requestSerial != _requestSerial) return;

      final current = _controller.itemList ?? const <EmbyItem>[];
      final seen = <String>{for (final item in current) item.id};
      final items = result.items
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _controller.appendLastPage(items);
      } else {
        _controller.appendPage(items, startIndex + _pageSize);
      }
      if (startIndex == 0) _completeRefresh();
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

  void _reloadWith({String? parentId, String? includeItemTypes, String? sortBy, String? sortOrder}) {
    final nextParent = parentId ?? _parentId;
    final nextTypes = includeItemTypes ?? _includeItemTypes;
    final nextSortBy = sortBy ?? _sortBy;
    final nextSortOrder = sortOrder ?? _sortOrder;
    if (nextParent == _parentId &&
        nextTypes == _includeItemTypes &&
        nextSortBy == _sortBy &&
        nextSortOrder == _sortOrder) {
      return;
    }
    setState(() {
      _parentId = nextParent;
      _includeItemTypes = nextTypes;
      _sortBy = nextSortBy;
      _sortOrder = nextSortOrder;
    });
    _requestSerial++;
    _controller.refresh();
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
                  ascending: _sortOrder == 'Ascending',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(
                      sortOrder: _sortOrder == 'Ascending'
                          ? 'Descending'
                          : 'Ascending',
                    );
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

  Future<void> _openTypeMenu(BuildContext context) async {
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
                title: '筛选内容类型',
                padding: EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              for (final option in _typeOptions)
                ListTile(
                  dense: true,
                  title: Text(option.label),
                  trailing: option.value == _includeItemTypes
                      ? Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(includeItemTypes: option.value);
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
    final views = ref.watch(embyViewsProvider);
    final urls = ref.watch(embyServerUrlsProvider);
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
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMBY', style: AppText.eyebrow(context)),
                        const SizedBox(height: 3),
                        Text('媒体库', style: AppText.pageTitle(context)),
                      ],
                    ),
                  ),
                  _LibrarySortButton(
                    ascending: _sortOrder == 'Ascending',
                    onTap: () => _openSortMenu(context),
                  ),
                  const SizedBox(width: 8),
                  _LibraryFilterButton(
                    active: _includeItemTypes != 'Movie,Series',
                    onTap: () => _openTypeMenu(context),
                  ),
                ],
              ),
            ),
            views.maybeWhen(
              data: (list) => list.length <= 1
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: 38,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        scrollDirection: Axis.horizontal,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final view = list[index];
                          final selected = view.id == _parentId;
                          return _ViewChip(
                            label: view.name,
                            selected: selected,
                            onTap: () => _reloadWith(parentId: view.id),
                          );
                        },
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: StatusBarScrollToTop(
                scrollController: _scrollController,
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(embyViewsProvider);
                    await _refresh();
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        sliver: urls.maybeWhen(
                          data: (value) => PagedSliverGrid<int, EmbyItem>(
                            pagingController: _controller,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 0.5,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: spacing,
                                ),
                            builderDelegate:
                                PagedChildBuilderDelegate<EmbyItem>(
                                  itemBuilder: (context, item, index) =>
                                      EmbyItemCard(
                                        key: ValueKey(item.id),
                                        item: item,
                                        urls: value,
                                        width: itemWidth,
                                        onTap: () => openEmbyItemUnawaited(
                                          context,
                                          item,
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
                                      const EmbyEmptyPlaceholder(
                                        text: '暂无符合条件的条目',
                                      ),
                                  noMoreItemsIndicatorBuilder: (_) =>
                                      const NoMoreContent(),
                                ),
                          ),
                          orElse: () => const SliverToBoxAdapter(
                            child: SizedBox.shrink(),
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

class _ViewChip extends StatelessWidget {
  const _ViewChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.muted)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
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
