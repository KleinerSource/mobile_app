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
import 'package:omm/features/media_browser/widgets/media_browser_selection.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';

/// MediaBrowser 搜索页。
///
/// 搜索框和结果网格沿用 OMM/DBO 搜索页的交互结构；MediaBrowser 的
/// SearchTerm 同时命中电影和剧集，结果卡片按类型跳转对应详情。
class MediaBrowserSearchPage extends ConsumerStatefulWidget {
  const MediaBrowserSearchPage({super.key});

  @override
  ConsumerState<MediaBrowserSearchPage> createState() =>
      _MediaBrowserSearchPageState();
}

class _MediaBrowserSearchPageState
    extends ConsumerState<MediaBrowserSearchPage> {
  final _controller = TextEditingController();
  String _submittedQuery = '';
  int _searchSerial = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
  }

  void _submitSearch([String? value]) {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) {
      if (_submittedQuery.isNotEmpty) {
        setState(() {
          _submittedQuery = '';
          _searchSerial++;
        });
      }
      return;
    }
    setState(() {
      _submittedQuery = query;
      _searchSerial++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);

    // 独立路由进入时页面自身就是 Material 根：无 Scaffold 会让 debug
    // 构建的文本出现黄色双下划线。底色由 FrostedBase 自绘，保持透明。
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.watch(mediaBrowserConfigProvider)?.brandLabel ?? '',
                      style: AppText.eyebrow(context),
                    ),
                    const SizedBox(height: 3),
                    Text(l.searchFind, style: AppText.pageTitle(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.cardBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded, size: 18, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: l.mediaBrowserSearchHint,
                            hintStyle: TextStyle(
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: _onChanged,
                          onSubmitted: _submitSearch,
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: colors.muted,
                          ),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _submittedQuery = '';
                              _searchSerial++;
                            });
                          },
                        ),
                      IconButton(
                        tooltip: l.searchTitle,
                        icon: Icon(Icons.search, size: 18, color: colors.muted),
                        onPressed: _submitSearch,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _submittedQuery.isEmpty
                    ? _MediaBrowserSearchEmptyHint(hint: l.searchEmpty)
                    : _MediaBrowserSearchResults(
                        key: ValueKey('$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaBrowserSearchEmptyHint extends StatelessWidget {
  const _MediaBrowserSearchEmptyHint({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: colors.muted2),
          const SizedBox(height: 12),
          Text(
            hint,
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MediaBrowserSearchResults extends ConsumerStatefulWidget {
  const _MediaBrowserSearchResults({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_MediaBrowserSearchResults> createState() =>
      _MediaBrowserSearchResultsState();
}

class _MediaBrowserSearchResultsState
    extends ConsumerState<_MediaBrowserSearchResults> {
  static const _pageSize = 24;

  bool get _isStash =>
      ref.read(mediaBrowserConfigProvider)?.project == ServerProject.stash;

  String get _requestIncludeItemTypes =>
      _isStash ? 'Movie' : 'Movie,Series,Episode,MusicAlbum,Audio';

  final _pagingController = PagingController<int, MediaBrowserItem>(
    firstPageKey: 0,
  );
  final _scrollController = ScrollController();
  late final PagedSelectionController<MediaBrowserItem> _selection;
  bool _batchBusy = false;

  @override
  void initState() {
    super.initState();
    _selection = createMediaBrowserItemSelection();
    _selection.addModeListener(_onSelectionModeChanged);
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openItem(MediaBrowserItem item) async {
    await openMediaBrowserItem(context, ref, item);
    if (!mounted) return;
    // 详情页内可能切换了收藏/已看，返回时后台刷新已加载条目。
    await _refreshLoadedInBackground();
  }

  Future<void> _refreshLoadedInBackground() async {
    final query = widget.query;
    final refreshed = await refreshPagedListInBackground<MediaBrowserItem>(
      controller: _pagingController,
      loadFirstPage: (limit) async {
        final result = await readMediaBrowserItemPage(
          ref,
          MediaBrowserItemPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            includeItemTypes: _requestIncludeItemTypes,
            recursive: true,
            searchTerm: query,
            sortBy: 'SortName',
            sortOrder: 'Ascending',
            startIndex: 0,
            limit: limit,
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

  Future<void> _fetchPage(int startIndex) async {
    try {
      final result = await readMediaBrowserItemPage(
        ref,
        MediaBrowserItemPageRequest(
          serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
          includeItemTypes: _requestIncludeItemTypes,
          recursive: true,
          searchTerm: widget.query,
          sortBy: 'SortName',
          sortOrder: 'Ascending',
          startIndex: startIndex,
          limit: _pageSize,
        ),
      );
      if (!mounted) return;

      final current = _pagingController.itemList ?? const <MediaBrowserItem>[];
      final seen = <String>{for (final item in current) item.id};
      final items = result.items
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, startIndex + _pageSize);
      }
    } catch (error) {
      if (!mounted) return;
      _pagingController.error = toApiException(error).message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    final isStash =
        ref.watch(mediaBrowserConfigProvider)?.project == ServerProject.stash;
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = (width - 44 - 20) / 3;
    final content = PagedSelectionPopScope<MediaBrowserItem>(
      selection: _selection,
      child: Stack(
        children: [
          PagedSelectionScope<MediaBrowserItem>(
            selection: _selection,
            scrollController: _scrollController,
            layout: isStash
                ? DragSelectionLayout.list
                : DragSelectionLayout.grid,
            child: CustomScrollView(
              controller: _scrollController,
              primary: false,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
                  sliver: urls.maybeWhen(
                    data: (value) {
                      final delegate =
                          PagedChildBuilderDelegate<MediaBrowserItem>(
                            itemBuilder: (context, item, index) => isStash
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: StashSceneCard(
                                      item: item,
                                      urls: value,
                                      width: width - 44,
                                      onTap: () => unawaited(_openItem(item)),
                                    ),
                                  )
                                : mediaBrowserSelectableGridItem(
                                    selection: _selection,
                                    item: item,
                                    urls: value,
                                    width: itemWidth,
                                    index: index,
                                    showFavoriteBadge: !isStash,
                                    selectionEnabled: !isStash,
                                    onOpen: _openItem,
                                  ),
                            firstPageProgressIndicatorBuilder: (_) =>
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            firstPageErrorIndicatorBuilder: (_) => ErrorView(
                              message:
                                  _pagingController.error?.toString() ??
                                  AppL10n.of(context).loadFailed,
                              onRetry: _pagingController.refresh,
                            ),
                            newPageErrorIndicatorBuilder: (_) =>
                                PaginationRetry(
                                  onRetry:
                                      _pagingController.retryLastFailedRequest,
                                ),
                            noItemsFoundIndicatorBuilder: (_) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  AppL10n.of(context).searchNoResult,
                                  style: AppText.meta(context),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            noMoreItemsIndicatorBuilder: (_) =>
                                const NoMoreContent(),
                          );
                      if (isStash) {
                        return PagedSliverList<int, MediaBrowserItem>(
                          pagingController: _pagingController,
                          builderDelegate: delegate,
                        );
                      }
                      return PagedSliverGrid<int, MediaBrowserItem>(
                        pagingController: _pagingController,
                        showNoMoreItemsIndicatorAsGridChild: false,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 14,
                            ),
                        builderDelegate: delegate,
                      );
                    },
                    orElse: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                ),
              ],
            ),
          ),
          if (!isStash)
            PagedSelectionToolbar<MediaBrowserItem>(
              selection: _selection,
              onSelectAll: () => _selection.selectAll(
                _pagingController.itemList ?? const <MediaBrowserItem>[],
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
    );
    return isStash ? StashPreviewScope(child: content) : content;
  }
}
