import 'package:omm/shared/catalog_search_field.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_resource_filter.dart';
import 'package:omm/core/sources/media/dbo/db_online_search.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/search_history.dart';
import 'package:omm/shared/search_type_menu.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_entity_card.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_filter_options.dart';
import 'package:omm/features/db_online/widgets/db_online_list_filter_sheets.dart';
import 'package:omm/features/db_online/widgets/db_online_subscription_action.dart';

/// dbonline 搜索页。
///
/// 搜索类型和结果卡片沿用 OMM 搜索页的交互结构；这里只替换 DBO 的
/// 数据请求、影片卡片和详情跳转。
class DbOnlineSearchPage extends ConsumerStatefulWidget {
  const DbOnlineSearchPage({super.key});

  @override
  ConsumerState<DbOnlineSearchPage> createState() => _DbOnlineSearchPageState();
}

enum DbOnlineSearchType {
  list,
  video,
  actor,
  series,
  maker,
  director,
  playlist,
}

extension on DbOnlineSearchType {
  String label(AppL10n l) => switch (this) {
    DbOnlineSearchType.list => l.searchModeList,
    DbOnlineSearchType.video => l.searchModeVideo,
    DbOnlineSearchType.actor => l.searchModeActorSearch,
    DbOnlineSearchType.series => l.searchModeSeries,
    DbOnlineSearchType.maker => l.searchModeMaker,
    DbOnlineSearchType.director => l.searchModeDirector,
    DbOnlineSearchType.playlist => l.searchModePlaylist,
  };

  String placeholder(AppL10n l) => switch (this) {
    DbOnlineSearchType.list => l.searchPlaceholderList,
    DbOnlineSearchType.video => l.searchPlaceholderVideo,
    DbOnlineSearchType.actor => l.searchPlaceholderActor,
    DbOnlineSearchType.series => l.searchPlaceholderSeries,
    DbOnlineSearchType.maker => l.searchPlaceholderMaker,
    DbOnlineSearchType.director => l.searchPlaceholderDirector,
    DbOnlineSearchType.playlist => l.searchPlaceholderPlaylist,
  };

  IconData get icon => switch (this) {
    DbOnlineSearchType.list => Icons.list_alt_outlined,
    DbOnlineSearchType.video => Icons.movie_outlined,
    DbOnlineSearchType.actor => Icons.person_outline_rounded,
    DbOnlineSearchType.series => Icons.layers_outlined,
    DbOnlineSearchType.maker => Icons.business_outlined,
    DbOnlineSearchType.director => Icons.videocam_outlined,
    DbOnlineSearchType.playlist => Icons.playlist_play_outlined,
  };

  /// 实体搜索类型对应的服务端 type 参数；清单在服务端叫 `list`。
  String get apiType => switch (this) {
    DbOnlineSearchType.series => 'series',
    DbOnlineSearchType.maker => 'maker',
    DbOnlineSearchType.director => 'director',
    DbOnlineSearchType.playlist => 'list',
    _ => throw StateError('$this is not an entity search type'),
  };
}

class _DbOnlineSearchPageState extends ConsumerState<DbOnlineSearchPage> {
  static const _viewModeKey = 'db_online.search.view_mode.v1';

  final _controller = TextEditingController();
  String _submittedQuery = '';
  DbOnlineSearchType _searchType = DbOnlineSearchType.list;
  int _searchSerial = 0;
  MediaViewMode _viewMode = MediaViewMode.portrait;

  // 影片列表搜索的过滤器，与网页端一致：类型单选、资源条件多选、
  // 排序单选；资源条件复用共享选项（请求时映射全词，搜索端点不含
  // p=可播放）。
  String _movieType = 'all';
  String _movieSortBy = 'relevance';
  final Set<String> _resourceFilters = {};

  String get _movieFilterParam =>
      dbOnlineMovieFilterByLetters(_resourceFilters);

  @override
  void initState() {
    super.initState();
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
  }

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
    _recordHistory(query);
    if (_searchType == DbOnlineSearchType.video) {
      FocusScope.of(context).unfocus();
      // 搜索框输入为番号形态，落入详情路由的 code 兜底解析
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => DbOnlineMovieDetailPage(detailKey: query),
          ),
        ),
      );
      return;
    }
    setState(() {
      _submittedQuery = query;
      _searchSerial++;
    });
  }

  void _changeSearchType(DbOnlineSearchType type) {
    if (type == _searchType) return;
    setState(() {
      _searchType = type;
      _submittedQuery = '';
      _searchSerial++;
    });
  }

  /// 过滤器变化后保持关键词重新搜索。
  void _applyMovieFilter(VoidCallback mutate) {
    setState(() {
      mutate();
      if (_submittedQuery.isNotEmpty) _searchSerial++;
    });
  }

  bool get _filtersActive =>
      _movieType != 'all' ||
      _resourceFilters.isNotEmpty ||
      _movieSortBy != 'relevance';

  /// 影片列表搜索过滤器弹层：类型 / 资源条件（多选）/ 排序，
  /// 与关注列表的筛选弹层同款交互，选择后立即生效并保持打开。
  Future<void> _openMovieFilterSheet() {
    return showDbOnlineFilterSheet(
      context,
      sections: (l) => [
        DbOnlineFilterSection(
          title: l.dbOnlineSort,
          options: dbOnlineMovieSortOptions(l),
          selected: _movieSortBy,
          onSelected: (value) => _applyMovieFilter(() => _movieSortBy = value),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineCategorySection,
          options: dbOnlineCategoryOptions(l, includeAll: true),
          selected: _movieType,
          onSelected: (value) => _applyMovieFilter(() => _movieType = value),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineFollowingConditions,
          options: dbOnlineResourceConditionOptions(l),
          selected: dbOnlineResourceConditionLetters(
            _resourceFilters,
          ).join(','),
          multiSelect: true,
          onSelected: (value) => _applyMovieFilter(() {
            _resourceFilters
              ..clear()
              ..addAll(value.split(',').where((item) => item.isNotEmpty));
          }),
        ),
      ],
    );
  }

  /// 搜索历史按服务器独立保存；提交时记录（含番号直达）。
  void _recordHistory(String query) {
    final serverId = ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    unawaited(ref.read(searchHistoryStoreProvider).add(serverId, query));
  }

  Future<void> _clearHistory(String serverId) async {
    await ref.read(searchHistoryStoreProvider).clear(serverId);
    if (mounted) setState(() {});
  }

  Widget _emptyArea() {
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final history = ref.read(searchHistoryStoreProvider).load(serverId);
    if (history.isEmpty) return const _DbOnlineSearchEmptyHint();
    return SearchHistorySection(
      entries: history,
      onSelected: (entry) {
        _controller.text = entry;
        _submitSearch(entry);
      },
      onClear: () => unawaited(_clearHistory(serverId)),
    );
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              eyebrow: l.searchTitle.toUpperCase(),
              bottomPadding: PageHeader.toolbarTopGap,
              title: Text(l.searchFind, style: AppText.pageTitle(context)),
              trailing: _searchType == DbOnlineSearchType.list
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CompactFilterButton(
                          label: '',
                          icon: Icons.tune_rounded,
                          active: _filtersActive,
                          onTap: () => unawaited(_openMovieFilterSheet()),
                        ),
                        const SizedBox(width: 8),
                        MediaViewModeToggle(
                          mode: _viewMode,
                          onChanged: (mode) => unawaited(_setViewMode(mode)),
                        ),
                      ],
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                22,
                0,
                22,
                PageHeader.aboveListGap,
              ),
              child: CatalogSearchField(
                controller: _controller,
                hintText: _searchType.placeholder(l),
                autofocus: true,
                leading: SearchTypeMenu<DbOnlineSearchType>(
                  value: _searchType,
                  options: [
                    for (final type in DbOnlineSearchType.values)
                      SearchTypeOption<DbOnlineSearchType>(
                        value: type,
                        label: type.label(l),
                        icon: type.icon,
                      ),
                  ],
                  onChanged: _changeSearchType,
                ),
                onChanged: _onChanged,
                onSubmitted: _submitSearch,
                onCleared: () => setState(() {
                  _submittedQuery = '';
                  _searchSerial++;
                }),
              ),
            ),
            // 过滤器通过页头按钮 + 弹层操作，与关注列表一致。
            Expanded(
              child: _submittedQuery.isEmpty
                  ? _emptyArea()
                  : switch (_searchType) {
                      DbOnlineSearchType.list => _DbOnlineSearchResults(
                        key: ValueKey('list:$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                        viewMode: _viewMode,
                        movieType: _movieType,
                        movieSortBy: _movieSortBy,
                        movieFilterBy: _movieFilterParam,
                      ),
                      DbOnlineSearchType.video =>
                        const _DbOnlineSearchEmptyHint(),
                      DbOnlineSearchType.actor => _DbOnlineActorSearchResults(
                        key: ValueKey('actor:$_submittedQuery:$_searchSerial'),
                        query: _submittedQuery,
                      ),
                      DbOnlineSearchType.series ||
                      DbOnlineSearchType.maker ||
                      DbOnlineSearchType.director ||
                      DbOnlineSearchType
                          .playlist => _DbOnlineEntitySearchResults(
                        key: ValueKey(
                          '${_searchType.name}:$_submittedQuery:$_searchSerial',
                        ),
                        type: _searchType,
                        query: _submittedQuery,
                      ),
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _DbOnlineSearchEmptyHint extends StatelessWidget {
  const _DbOnlineSearchEmptyHint();

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return CenteredEmptyState(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: colors.muted2),
          const SizedBox(height: 12),
          Text(
            l.searchEmpty,
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(l.searchHint2, style: AppText.meta(context)),
        ],
      ),
    );
  }
}

class _DbOnlineSearchResults extends ConsumerStatefulWidget {
  const _DbOnlineSearchResults({
    super.key,
    required this.query,
    required this.viewMode,
    this.movieType = 'all',
    this.movieSortBy = 'relevance',
    this.movieFilterBy = 'all',
  });

  final String query;
  final MediaViewMode viewMode;
  final String movieType;
  final String movieSortBy;
  final String movieFilterBy;

  @override
  ConsumerState<_DbOnlineSearchResults> createState() =>
      _DbOnlineSearchResultsState();
}

class _DbOnlineSearchResultsState
    extends ConsumerState<_DbOnlineSearchResults> {
  static const _pageSize = 24;

  final _requests = PagedRequestCoordinator();
  final _pagingController = PagingController<int, DbOnlineMovie>(
    firstPageKey: 1,
  );

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _requests.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    final pageRequest = _requests.begin(page);
    if (pageRequest == null) return;
    try {
      final result = await ref.read(
        dbOnlineSearchPageProvider(
          DbOnlineSearchPageRequest(
            serverId:
                ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
            query: widget.query,
            page: page,
            limit: _pageSize,
            movieType: widget.movieType,
            movieSortBy: widget.movieSortBy,
            movieFilterBy: widget.movieFilterBy,
          ),
        ).future,
      );
      if (!pageRequest.isCurrent) return;
      if (!mounted) return;

      final current = _pagingController.itemList ?? const <DbOnlineMovie>[];
      final seen = <String>{for (final movie in current) _movieKey(movie)};
      final items = result.movies
          .where((movie) => seen.add(_movieKey(movie)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.movies.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, page + 1);
      }
    } catch (error) {
      if (!pageRequest.isCurrent) return;
      if (!mounted) return;
      _pagingController.error = localizedErrorMessage(
        AppL10n.of(context),
        error,
      );
    } finally {
      pageRequest.finish();
    }
  }

  String _movieKey(DbOnlineMovie movie) {
    final id = movie.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'number:${movie.number.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mediaRuntimeConfigProvider);
    final isPortrait = widget.viewMode == MediaViewMode.portrait;

    final delegate = PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, _) {
        final card = DbOnlineMovieCard(
          key: ValueKey(_movieKey(movie)),
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: widget.viewMode == MediaViewMode.landscape,
          compact: widget.viewMode == MediaViewMode.list,
          onTap: () => openDbOnlineMovieUnawaited(context, movie),
        );
        return widget.viewMode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      },
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CircularProgressIndicator()),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message:
            _pagingController.error?.toString() ??
            AppL10n.of(context).loadFailed,
        onRetry: _pagingController.refresh,
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: _pagingController.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: (_) =>
          EmptyView(message: AppL10n.of(context).searchNoResult),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );

    return CustomScrollView(
      // 接入 Tab 级 PrimaryScrollController，状态栏点击可回顶。
      primary: true,
      slivers: [
        SliverPadding(
          padding: MediaListLayout.contentPadding.copyWith(bottom: 120),
          sliver: isPortrait
              ? PagedSliverGrid<int, DbOnlineMovie>(
                  pagingController: _pagingController,
                  showNoMoreItemsIndicatorAsGridChild: false,
                  gridDelegate: const MediaGridDelegate(),
                  builderDelegate: delegate,
                )
              : PagedSliverList<int, DbOnlineMovie>(
                  pagingController: _pagingController,
                  builderDelegate: delegate,
                ),
        ),
      ],
    );
  }
}

class _DbOnlineActorSearchResults extends ConsumerWidget {
  const _DbOnlineActorSearchResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(dbOnlineActorSearchProvider(query));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: localizedErrorMessage(AppL10n.of(context), error),
        onRetry: () => ref.invalidate(dbOnlineActorSearchProvider(query)),
      ),
      data: (value) {
        if (value.actors.isEmpty) {
          return EmptyView(message: AppL10n.of(context).searchNoResult);
        }
        return CustomScrollView(
          // 接入 Tab 级 PrimaryScrollController，状态栏点击可回顶。
          primary: true,
          slivers: [
            SliverPadding(
              padding: MediaListLayout.contentPadding.copyWith(bottom: 120),
              sliver: SliverGrid(
                gridDelegate: _actorGridDelegate,
                delegate: SliverChildBuilderDelegate((context, index) {
                  final actor = value.actors[index];
                  return DbOnlineEntityCard(
                    id: actor.id,
                    name: actor.name,
                    label: AppL10n.of(context).searchModeActorSearch,
                    count: actor.videosCount,
                    icon: Icons.person_outline_rounded,
                    imageUrl: actor.avatarUrl,
                    uncensored: actor.uncensored,
                    // 与演员榜一致：优先展示其他名称，无则回退中文名/作品数。
                    metaText: actor.otherName ?? actor.nameZht,
                    subscriptionKind: 'actor',
                    subscriptionData: {
                      'actor_avatar': actor.avatarUrl ?? '',
                      'other_name': actor.otherName ?? '',
                    },
                    onTap: () => _openEntityMovies(
                      context,
                      kind: 'actor',
                      id: actor.id,
                      title: actor.name,
                      eyebrow: AppL10n.of(context).searchModeActorSearch,
                    ),
                  );
                }, childCount: value.actors.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DbOnlineEntitySearchResults extends ConsumerStatefulWidget {
  const _DbOnlineEntitySearchResults({
    super.key,
    required this.type,
    required this.query,
  });

  final DbOnlineSearchType type;
  final String query;

  @override
  ConsumerState<_DbOnlineEntitySearchResults> createState() =>
      _DbOnlineEntitySearchResultsState();
}

class _DbOnlineEntitySearchResultsState
    extends ConsumerState<_DbOnlineEntitySearchResults> {
  static const _pageSize = 24;

  final _pagingController = PagingController<int, DbOnlineSearchEntity>(
    firstPageKey: 1,
  );

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    try {
      final result = await ref.read(
        dbOnlineEntitySearchPageProvider(
          DbOnlineEntitySearchPageRequest(
            serverId:
                ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
            type: widget.type.apiType,
            query: widget.query,
            page: page,
            limit: _pageSize,
          ),
        ).future,
      );
      if (!mounted) return;

      final current =
          _pagingController.itemList ?? const <DbOnlineSearchEntity>[];
      final seen = <String>{for (final item in current) _entityKey(item)};
      final items = result.items
          .where((item) => seen.add(_entityKey(item)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, page + 1);
      }
    } catch (error) {
      if (!mounted) return;
      _pagingController.error = localizedErrorMessage(
        AppL10n.of(context),
        error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return CustomScrollView(
      // 接入 Tab 级 PrimaryScrollController，状态栏点击可回顶。
      primary: true,
      slivers: [
        SliverPadding(
          padding: MediaListLayout.contentPadding.copyWith(bottom: 120),
          sliver: PagedSliverList<int, DbOnlineSearchEntity>(
            pagingController: _pagingController,
            builderDelegate: PagedChildBuilderDelegate<DbOnlineSearchEntity>(
              itemBuilder: (context, item, _) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DbOnlineSearchEntityRow(
                  id: item.id,
                  name: item.name,
                  count: item.moviesCount,
                  icon: type.icon,
                  subscriptionKind: 'series',
                  subscriptionData: {'sub_type': type.apiType},
                  onTap: () => _openEntityMovies(
                    context,
                    kind: type.apiType,
                    id: item.id,
                    title: item.name,
                    eyebrow: type.label(AppL10n.of(context)),
                  ),
                ),
              ),
              firstPageProgressIndicatorBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => ErrorView(
                message:
                    _pagingController.error?.toString() ??
                    AppL10n.of(context).loadFailed,
                onRetry: _pagingController.refresh,
              ),
              newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                onRetry: _pagingController.retryLastFailedRequest,
              ),
              noItemsFoundIndicatorBuilder: (_) =>
                  EmptyView(message: AppL10n.of(context).searchNoResult),
              noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 系列、片商、导演、清单的列表行：这类实体没有头像，一行一条，
/// 左侧类型图标 + 名称与作品数 + 右侧订阅按钮，点击进入影片列表。
class _DbOnlineSearchEntityRow extends StatelessWidget {
  const _DbOnlineSearchEntityRow({
    required this.id,
    required this.name,
    required this.count,
    required this.icon,
    required this.subscriptionKind,
    this.subscriptionData = const <String, dynamic>{},
    this.onTap,
  });

  final String id;
  final String name;
  final int count;
  final IconData icon;
  final String subscriptionKind;
  final Map<String, dynamic> subscriptionData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 22, color: colors.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        AppL10n.of(context).libraryCount(count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DbOnlineSubscriptionAction(
                kind: subscriptionKind,
                id: id,
                title: name,
                initial: subscriptionData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openEntityMovies(
  BuildContext context, {
  required String kind,
  required String id,
  required String title,
  required String eyebrow,
}) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DbOnlineEntityMoviesPage(
          kind: kind,
          id: id,
          title: title,
          eyebrow: eyebrow,
        ),
      ),
    ),
  );
}

/// 演员搜索结果网格：纵向卡片三列布局，头像在上。
///
/// 宽高比 0.62 = 固定的底部信息块（两行名称 + 一行元信息）加上接近
/// 正方形的头像区域。
const _actorGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  childAspectRatio: 0.62,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
);

String _entityKey(DbOnlineSearchEntity item) {
  final id = item.id.trim();
  return id.isNotEmpty ? 'id:$id' : 'name:${item.name.trim()}';
}
