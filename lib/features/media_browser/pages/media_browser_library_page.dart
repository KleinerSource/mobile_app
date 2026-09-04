import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/media_browser/widgets/media_browser_selection.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';

/// MediaBrowser 媒体库。
///
/// 顶部按 MediaBrowser Views（媒体库）切换，类型筛选在电影/剧集/全部间切换；
/// 排序沿用 MediaBrowser 的 SortBy 语义，升降序切换与 DBO 影片库一致。
/// 长按进入拖选多选（与 OMM 影片库同构），批量收藏/已看标记。
class MediaBrowserLibraryPage extends ConsumerStatefulWidget {
  const MediaBrowserLibraryPage({
    super.key,
    this.initialViewId,
    this.personId,
    this.personName,
  });

  /// 从首页媒体库卡片进入时预选的库；null 保持默认的“全部库”模式。
  final String? initialViewId;

  /// 演员作品模式：按 PersonIds 过滤（Emby/Jellyfin），标题显示演员名。
  final String? personId;
  final String? personName;

  @override
  ConsumerState<MediaBrowserLibraryPage> createState() =>
      _MediaBrowserLibraryPageState();
}

class _MediaBrowserLibraryPageState
    extends ConsumerState<MediaBrowserLibraryPage> {
  static const _pageSize = 24;
  static final _videoTypeOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'Movie,Series', label: (l) => l.filterAll),
        (value: 'Movie', label: (l) => l.mediaBrowserTypeMovies),
        (value: 'Series', label: (l) => l.mediaBrowserTypeTvShows),
      ];
  static final _musicTypeOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'MusicAlbum', label: (l) => l.mediaBrowserTypeAlbums),
        (value: 'Audio', label: (l) => l.mediaBrowserTypeSongs),
      ];
  static final _sortOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'DateCreated', label: (l) => l.mediaBrowserSortRecent),
        (value: 'SortName', label: (l) => l.mediaBrowserSortName),
        (value: 'ProductionYear', label: (l) => l.mediaBrowserSortYear),
        (value: 'CommunityRating', label: (l) => l.mediaBrowserSortRating),
      ];

  final _controller = PagingController<int, MediaBrowserItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final PagedSelectionController<MediaBrowserItem> _selection;
  Completer<void>? _refreshCompleter;
  String? _parentId;
  String? _collectionType;
  String _includeItemTypes = 'Movie,Series';
  String _sortBy = 'DateCreated';
  String _sortOrder = 'Descending';
  int _requestSerial = 0;
  bool _pageRequestTriggeredByRefresh = false;
  bool _batchBusy = false;

  /// 当前选中库的类型过滤选项；音乐库切到「专辑/歌曲」。
  List<({String value, String Function(AppL10n l) label})> get _typeOptions =>
      _typeOptionsFor(_collectionType);

  static List<({String value, String Function(AppL10n l) label})>
  _typeOptionsFor(String? collectionType) =>
      _isMusicCollectionType(collectionType)
      ? _musicTypeOptions
      : _videoTypeOptions;

  static bool _isMusicCollectionType(String? collectionType) =>
      (collectionType ?? '').trim().toLowerCase() == 'music';

  bool get _isMusicGrid => _isMusicCollectionType(_collectionType);

  bool get _isPersonMode => widget.personId?.trim().isNotEmpty == true;

  bool get _isStash =>
      ref.read(mediaBrowserConfigProvider)?.project == ServerProject.stash;

  String get _requestIncludeItemTypes => _isStash ? 'Movie' : _includeItemTypes;

  @override
  void initState() {
    super.initState();
    _parentId = widget.initialViewId;
    _selection = createMediaBrowserItemSelection();
    _selection.addModeListener(_onSelectionModeChanged);
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _completeRefresh();
    _controller.dispose();
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchPage(int startIndex) async {
    if (startIndex == _controller.firstPageKey) {
      _pageRequestTriggeredByRefresh = true;
    }
    final requestSerial = _requestSerial;
    try {
      final result = await readMediaBrowserItemPage(
        ref,
        MediaBrowserItemPageRequest(
          serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
          parentId: _parentId,
          includeItemTypes: _requestIncludeItemTypes,
          recursive: true,
          sortBy: _sortBy,
          sortOrder: _sortOrder,
          startIndex: startIndex,
          limit: _pageSize,
          personIds: _isPersonMode ? widget.personId : null,
        ),
      );
      if (!mounted || requestSerial != _requestSerial) return;

      final current = _controller.itemList ?? const <MediaBrowserItem>[];
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
    _refreshController();
    return completer.future;
  }

  void _refreshController() {
    _pageRequestTriggeredByRefresh = false;
    _controller.refresh();
    if (!_pageRequestTriggeredByRefresh) {
      unawaited(_fetchPage(_controller.firstPageKey));
    }
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _reloadWith({
    String? parentId,
    String? includeItemTypes,
    String? sortBy,
    String? sortOrder,
  }) {
    final nextParent = parentId ?? _parentId;
    final nextCollectionType = _collectionTypeOf(nextParent);
    final nextTypeOptions = _typeOptionsFor(nextCollectionType);
    final nextTypes =
        includeItemTypes ??
        (_collectionTypeOf(_parentId) == nextCollectionType
            ? _includeItemTypes
            : nextTypeOptions.first.value);
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
      _collectionType = nextCollectionType;
      _includeItemTypes = nextTypes;
      _sortBy = nextSortBy;
      _sortOrder = nextSortOrder;
    });
    _selection.exit();
    _requestSerial++;
    _refreshController();
  }

  /// 从已加载的 Views 里解析选中库的 collectionType；「全部库」为 null。
  String? _collectionTypeOf(String? parentId) {
    if (parentId == null) return null;
    final views = ref.read(mediaBrowserViewsProvider).value;
    for (final view in views ?? const <MediaBrowserItem>[]) {
      if (view.id == parentId) return view.collectionType;
    }
    return null;
  }

  /// Views 异步到达后补齐选中库的类型（如从首页音乐库卡片直接进入），
  /// 类型过滤不匹配时切到该库的默认选项。
  void _syncCollectionType(List<MediaBrowserItem> views) {
    if (_isPersonMode) return;
    final next = _collectionTypeOf(_parentId);
    if (next == _collectionType) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || next != _collectionTypeOf(_parentId)) return;
      final options = _typeOptionsFor(next);
      final typesChanged = !options.any(
        (option) => option.value == _includeItemTypes,
      );
      setState(() {
        _collectionType = next;
        if (typesChanged) {
          _includeItemTypes = options.first.value;
        }
      });
      if (!typesChanged) return;
      _selection.exit();
      _requestSerial++;
      _refreshController();
    });
  }

  Future<void> _openItem(MediaBrowserItem item) async {
    await openMediaBrowserItem(context, ref, item);
    if (!mounted) return;
    // 详情页内可能切换了收藏/已看，返回时后台刷新已加载条目并保持滚动位置。
    await _refreshLoadedInBackground();
  }

  Future<void> _refreshLoadedInBackground() async {
    final parentId = _parentId;
    final includeItemTypes = _includeItemTypes;
    final sortBy = _sortBy;
    final sortOrder = _sortOrder;
    final refreshed = await refreshPagedListInBackground<MediaBrowserItem>(
      controller: _controller,
      loadFirstPage: (limit) async {
        final result = await readMediaBrowserItemPage(
          ref,
          MediaBrowserItemPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            parentId: parentId,
            includeItemTypes: _isStash ? 'Movie' : includeItemTypes,
            recursive: true,
            sortBy: sortBy,
            sortOrder: sortOrder,
            startIndex: 0,
            limit: limit,
            personIds: _isPersonMode ? widget.personId : null,
          ),
        );
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

  /// 批量收藏/已看标记：循环/提示/退出选择由通用执行器处理，
  /// 页面只提供 busy 状态与原位刷新回调。
  Future<void> _applySelection({bool? favorite, bool? played}) {
    if (_batchBusy) return Future.value();
    return runMediaBrowserSelectionBatch(
      context: context,
      ref: ref,
      selection: _selection,
      refreshLoaded: _refreshLoadedInBackground,
      onBusyChanged: (busy) {
        if (mounted) setState(() => _batchBusy = busy);
      },
      favorite: favorite,
      played: played,
    );
  }

  Future<void> _openSortMenu(BuildContext context) async {
    final colors = appColors(context);
    final l = AppL10n.of(context);
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
                title: l.mediaBrowserSort,
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
                  title: Text(option.label(l)),
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
    final l = AppL10n.of(context);
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.tune_rounded,
                title: l.mediaBrowserFilterContentType,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              for (final option in _typeOptions)
                ListTile(
                  dense: true,
                  title: Text(option.label(l)),
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
    final isStash =
        ref.watch(mediaBrowserConfigProvider)?.project == ServerProject.stash;
    final views = ref.watch(mediaBrowserViewsProvider);
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    views.maybeWhen(data: _syncCollectionType, orElse: () {});
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
    // 影视海报 2:3 + 双行文字；音乐方形封面按实际卡片高度反推比例。
    final cardAspectRatio = _isMusicGrid ? itemWidth / (itemWidth + 62) : 0.5;

    // 独立路由进入时页面自身就是 Material 根：无 Scaffold 会让 debug
    // 构建的文本出现黄色双下划线。底色由 FrostedBase 自绘，保持透明。
    return Scaffold(
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                  _isPersonMode
                                      ? (widget.personName?.trim().isNotEmpty ==
                                                true
                                            ? widget.personName!.trim()
                                            : AppL10n.of(
                                                context,
                                              ).mediaBrowserActorWorks)
                                      : AppL10n.of(
                                          context,
                                        ).mediaBrowserLibrariesTitle,
                                  style: AppText.pageTitle(context),
                                ),
                              ],
                            ),
                          ),
                          _LibrarySortButton(
                            ascending: _sortOrder == 'Ascending',
                            onTap: () => _openSortMenu(context),
                          ),
                          const SizedBox(width: 8),
                          if (!isStash)
                            _LibraryFilterButton(
                              active:
                                  _includeItemTypes != _typeOptions.first.value,
                              onTap: () => _openTypeMenu(context),
                            ),
                        ],
                      ),
                    ),
                    views.maybeWhen(
                      data: (list) => _isPersonMode || list.length <= 1
                          ? const SizedBox.shrink()
                          : SizedBox(
                              height: 38,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                scrollDirection: Axis.horizontal,
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final view = list[index];
                                  final selected = view.id == _parentId;
                                  return _ViewChip(
                                    privacyId: view.id,
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
                            ref.invalidate(mediaBrowserViewsProvider);
                            await _refresh();
                          },
                          child: PagedSelectionScope<MediaBrowserItem>(
                            selection: _selection,
                            scrollController: _scrollController,
                            layout: DragSelectionLayout.grid,
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  sliver: urls.maybeWhen(
                                    data: (value) => PagedSliverGrid<int, MediaBrowserItem>(
                                      pagingController: _controller,
                                      // 与 OMM 影片库一致：尾部提示整行跨列渲染，
                                      // 否则「没有更多内容」会被塞进单个网格单元。
                                      showNoMoreItemsIndicatorAsGridChild:
                                          false,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            childAspectRatio: cardAspectRatio,
                                            mainAxisSpacing: 14,
                                            crossAxisSpacing: spacing,
                                          ),
                                      builderDelegate:
                                          PagedChildBuilderDelegate<
                                            MediaBrowserItem
                                          >(
                                            itemBuilder: (context, item, index) =>
                                                mediaBrowserSelectableGridItem(
                                                  selection: _selection,
                                                  item: item,
                                                  urls: value,
                                                  width: itemWidth,
                                                  index: index,
                                                  square: _isMusicGrid,
                                                  showFavoriteBadge: !isStash,
                                                  selectionEnabled: !isStash,
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
                                                          color: colors.accent,
                                                        ),
                                                  ),
                                                ),
                                            newPageProgressIndicatorBuilder:
                                                (_) => const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 18,
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                            firstPageErrorIndicatorBuilder:
                                                (_) => _LibraryListError(
                                                  message:
                                                      _controller.error
                                                          ?.toString() ??
                                                      AppL10n.of(
                                                        context,
                                                      ).loadFailed,
                                                  onRetry: _controller
                                                      .retryLastFailedRequest,
                                                ),
                                            newPageErrorIndicatorBuilder: (_) =>
                                                PaginationRetry(
                                                  onRetry: _controller
                                                      .retryLastFailedRequest,
                                                ),
                                            noItemsFoundIndicatorBuilder: (_) =>
                                                MediaBrowserEmptyPlaceholder(
                                                  text: AppL10n.of(
                                                    context,
                                                  ).mediaBrowserNoMatchingItems,
                                                ),
                                            noMoreItemsIndicatorBuilder: (_) =>
                                                const NoMoreContent(),
                                          ),
                                    ),
                                    loading: () => const SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    error: (error, _) => SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: _LibraryListError(
                                        message: toApiException(error).message,
                                        onRetry: () => ref.invalidate(
                                          mediaBrowserServerUrlsProvider,
                                        ),
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
                if (!isStash)
                  PagedSelectionToolbar<MediaBrowserItem>(
                    selection: _selection,
                    onSelectAll: () => _selection.selectAll(
                      _controller.itemList ?? const <MediaBrowserItem>[],
                    ),
                    actionsBuilder: (selected) => [
                      EntityBatchAction(
                        icon: Icons.favorite_rounded,
                        label: AppL10n.of(context).mediaBrowserFavoriteAction,
                        onTap: selected.isEmpty || _batchBusy
                            ? null
                            : () => unawaited(_applySelection(favorite: true)),
                      ),
                      EntityBatchAction(
                        icon: Icons.favorite_border_rounded,
                        label: AppL10n.of(context).mediaBrowserUnfavoriteAction,
                        color: colors.danger,
                        onTap: selected.isEmpty || _batchBusy
                            ? null
                            : () => unawaited(_applySelection(favorite: false)),
                      ),
                      EntityBatchAction(
                        icon: Icons.task_alt_rounded,
                        label: AppL10n.of(context).mediaBrowserMarkWatched,
                        onTap: selected.isEmpty || _batchBusy
                            ? null
                            : () => unawaited(_applySelection(played: true)),
                      ),
                      EntityBatchAction(
                        icon: Icons.check_circle_outline_rounded,
                        label: AppL10n.of(context).mediaBrowserUnmarkWatched,
                        onTap: selected.isEmpty || _batchBusy
                            ? null
                            : () => unawaited(_applySelection(played: false)),
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

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.privacyId,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 库 id · 隐私模式下库名按 PrivacyScope.library 域遮罩/揭开
  final String privacyId;
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
        child: PrivacyText(
          movieId: privacyId,
          scope: PrivacyScope.library,
          text: label,
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
              ascending
                  ? AppL10n.of(context).mediaBrowserAscending
                  : AppL10n.of(context).mediaBrowserDescending,
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
