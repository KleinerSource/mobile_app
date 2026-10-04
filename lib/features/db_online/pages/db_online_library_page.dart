import 'package:omm/shared/page_header.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_filter_options.dart';
import 'package:omm/features/db_online/widgets/db_online_list_filter_sheets.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

/// DBO 影片库。
///
/// DBO 本地影片库复用网页版的资源筛选、用户评分和排序参数。
class DbOnlineLibraryPage extends ConsumerStatefulWidget {
  const DbOnlineLibraryPage({super.key});

  @override
  ConsumerState<DbOnlineLibraryPage> createState() =>
      _DbOnlineLibraryPageState();
}

class _DbOnlineLibraryPageState extends ConsumerState<DbOnlineLibraryPage> {
  static const _pageSize = 24;
  static const _viewModeKey = 'db_online.library.view_mode.v1';
  static final _userScoreOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: '', label: (l) => l.filterAll),
        for (final score in const ['5', '4', '3', '2', '1'])
          (value: score, label: (l) => '$score ${l.dbOnlineLibraryStars}'),
        (value: '-1', label: (l) => l.dbOnlineLibraryUnrated),
      ];
  static final _minScoreOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: '', label: (l) => l.filterAll),
        for (final score in const ['5', '4', '3', '2', '1'])
          (value: score, label: (l) => '$score ${l.dbOnlineLibraryStars}'),
      ];
  static final _sortOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'created', label: (l) => l.dbOnlineLibrarySortCreated),
        (value: 'date', label: (l) => l.dbOnlineLibrarySortDate),
        (value: 'updated', label: (l) => l.dbOnlineLibrarySortUpdated),
      ];

  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();
  Completer<void>? _refreshCompleter;
  String _resourceFilter = '';
  String _userScore = '';
  String _minScore = '';
  String _sortBy = 'created';
  String _orderBy = 'desc';
  MediaViewMode _viewMode = MediaViewMode.portrait;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _completeRefresh();
    _requests.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    final pageRequest = _requests.begin(page);
    if (pageRequest == null) return;
    final requestSerial = _requestSerial;
    try {
      final result = await ref.read(
        dbOnlineLibraryPageProvider(
          DbOnlineLibraryPageRequest(
            serverId:
                ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
            page: page,
            limit: _pageSize,
            resourceFilter: _resourceFilter,
            userScore: _userScore,
            minScore: _minScore,
            sortBy: _sortBy,
            orderBy: _orderBy,
          ),
        ).future,
      );
      if (!pageRequest.isCurrent) return;
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
      if (!pageRequest.isCurrent) return;
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = localizedErrorMessage(AppL10n.of(context), error);
      if (page == 1) _completeRefresh();
    } finally {
      pageRequest.finish();
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
    _requests.invalidate();
    refreshPagedController(
      controller: _controller,
      requests: _requests,
      loadPage: _fetchPage,
    );
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _loadViewMode() {
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  void _reloadWith({
    String? resourceFilter,
    String? userScore,
    String? minScore,
    String? sortBy,
    String? orderBy,
  }) {
    final nextResourceFilter = resourceFilter ?? _resourceFilter;
    final nextUserScore = userScore ?? _userScore;
    final nextMinScore = minScore ?? _minScore;
    final nextSortBy = sortBy ?? _sortBy;
    final nextOrderBy = orderBy ?? _orderBy;
    if (nextResourceFilter == _resourceFilter &&
        nextUserScore == _userScore &&
        nextMinScore == _minScore &&
        nextSortBy == _sortBy &&
        nextOrderBy == _orderBy) {
      return;
    }
    setState(() {
      _resourceFilter = nextResourceFilter;
      _userScore = nextUserScore;
      _minScore = nextMinScore;
      _sortBy = nextSortBy;
      _orderBy = nextOrderBy;
    });
    _requestSerial++;
    _requests.invalidate();
    refreshPagedController(
      controller: _controller,
      requests: _requests,
      loadPage: _fetchPage,
    );
  }

  static List<DbOnlineFilterOption> _resolve(
    List<({String value, String Function(AppL10n l) label})> options,
    AppL10n l,
  ) => [
    for (final option in options) (value: option.value, label: option.label(l)),
  ];

  Future<void> _openFilterMenu(BuildContext context) {
    return showDbOnlineFilterSheet(
      context,
      sections: (l) => [
        DbOnlineFilterSection(
          title: l.dbOnlineLibraryResourceType,
          options: dbOnlineLibraryResourceOptions(l),
          selected: _resourceFilter,
          onSelected: (value) => _reloadWith(resourceFilter: value),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineLibraryUserRating,
          options: _resolve(_userScoreOptions, l),
          selected: _userScore,
          onSelected: (value) => _reloadWith(userScore: value),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineLibraryCommunityRating,
          options: _resolve(_minScoreOptions, l),
          selected: _minScore,
          onSelected: (value) => _reloadWith(minScore: value),
        ),
      ],
    );
  }

  Future<void> _openSortMenu(BuildContext context) {
    return showDbOnlineSortSheet(
      context,
      options: _resolve(_sortOptions, AppL10n.of(context)),
      selected: _sortBy,
      ascending: _orderBy == 'asc',
      onSelected: (value) => _reloadWith(sortBy: value),
      onToggleOrder: () =>
          _reloadWith(orderBy: _orderBy == 'asc' ? 'desc' : 'asc'),
    );
  }

  PagedChildBuilderDelegate<DbOnlineMovie> _movieDelegate({
    required BuildContext context,
    required ServerConfig? config,
    required Color progressColor,
  }) {
    return PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, index) {
        final card = DbOnlineMovieCard(
          key: ValueKey(_movieKey(movie)),
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: _viewMode == MediaViewMode.landscape,
          compact: _viewMode == MediaViewMode.list,
          showRating: false,
          onTap: () => openDbOnlineMovieUnawaited(context, movie),
        );
        return _viewMode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      },
      firstPageProgressIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Center(child: CircularProgressIndicator(color: progressColor)),
      ),
      newPageProgressIndicatorBuilder: (_) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView.list(
        retryLabel: AppL10n.of(context).dbOnlineRetry,
        message:
            _controller.error?.toString() ?? AppL10n.of(context).loadFailed,
        onRetry: _controller.retryLastFailedRequest,
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: _controller.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: (_) => const _LibraryListEmpty(),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    final isPortrait = _viewMode == MediaViewMode.portrait;
    final delegate = _movieDelegate(
      context: context,
      config: config,
      progressColor: colors.accent,
    );

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              eyebrow: 'DB ONLINE',
              bottomPadding: PageHeader.aboveListGap,
              title: Text(
                AppL10n.of(context).libraryTitle,
                style: AppText.pageTitle(context),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DbOnlineSortFilterButtons(
                    ascending: _orderBy == 'asc',
                    filterActive:
                        _resourceFilter.isNotEmpty ||
                        _userScore.isNotEmpty ||
                        _minScore.isNotEmpty,
                    onSort: () => _openSortMenu(context),
                    onFilter: () => _openFilterMenu(context),
                  ),
                  const SizedBox(width: 8),
                  MediaViewModeToggle(
                    mode: _viewMode,
                    onChanged: (mode) => unawaited(_setViewMode(mode)),
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
                        padding: MediaListLayout.contentPadding,
                        sliver: isPortrait
                            ? PagedSliverGrid<int, DbOnlineMovie>(
                                pagingController: _controller,
                                // 尾部提示整行跨列渲染（与 OMM 影片库一致）。
                                showNoMoreItemsIndicatorAsGridChild: false,
                                gridDelegate: const MediaGridDelegate(),
                                builderDelegate: delegate,
                              )
                            : PagedSliverList<int, DbOnlineMovie>(
                                pagingController: _controller,
                                builderDelegate: delegate,
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

class _LibraryListEmpty extends StatelessWidget {
  const _LibraryListEmpty();

  @override
  Widget build(BuildContext context) {
    return EmptyView(message: AppL10n.of(context).noResultFound);
  }
}
