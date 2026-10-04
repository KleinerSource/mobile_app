import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_watched.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_scheduler_provider.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/providers/db_online_watched_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_filter_options.dart';
import 'package:omm/features/db_online/widgets/db_online_following_widgets.dart';
import 'package:omm/features/db_online/widgets/db_online_list_filter_sheets.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_watched_recheck_sheet.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/sheet_controls.dart';

class DbOnlineWatchedPage extends ConsumerWidget {
  const DbOnlineWatchedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final route = ModalRoute.of(context);
    ref.listen(
      mediaRuntimeConfigProvider.select((config) => config?.activeServerId),
      (previous, next) {
        if (previous == next || route == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && route.isActive) {
            Navigator.of(context).popUntil((candidate) => candidate == route);
          }
        });
      },
    );
    return _WatchedPage(key: ValueKey(serverId), serverId: serverId);
  }
}

class _WatchedPage extends ConsumerStatefulWidget {
  const _WatchedPage({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<_WatchedPage> createState() => _WatchedPageState();
}

class _WatchedPageState extends ConsumerState<_WatchedPage> {
  static const _viewModeKey = 'db_online.watched.view_mode.v1';
  final _paging = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _requests = PagedRequestCoordinator();
  final _scroll = ScrollController();
  DbOnlineWatchedFilter _filter = const DbOnlineWatchedFilter();
  Completer<void>? _refreshCompleter;
  Timer? _taskRefresh;
  int _completionRevision = 0;
  int _connectionRevision = 0;

  bool get _current =>
      mounted &&
      ref.read(mediaRuntimeConfigProvider)?.activeServerId == widget.serverId;

  @override
  void initState() {
    super.initState();
    _paging.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _taskRefresh?.cancel();
    _completeRefresh();
    _requests.dispose();
    _paging.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch(int page) async {
    if (!_current) return;
    final request = _requests.begin(page);
    if (request == null) return;
    final query = (serverId: widget.serverId, page: page, filter: _filter);
    final l = AppL10n.of(context);
    try {
      final result = await ref.refresh(
        dbOnlineWatchedPageProvider(query).future,
      );
      if (!_current || !request.isCurrent) return;
      String key(DbOnlineMovie movie) => movie.id.trim().isNotEmpty
          ? 'id:${movie.id.trim()}'
          : 'code:${movie.number.trim()}';
      final seen = {
        for (final movie in _paging.itemList ?? <DbOnlineMovie>[]) key(movie),
      };
      final items = result.movies
          .where((movie) => seen.add(key(movie)))
          .toList();
      if (result.movies.length < DbOnlineWatchedFilter.pageSize) {
        _paging.appendLastPage(items);
      } else {
        _paging.appendPage(items, page + 1);
      }
    } catch (error) {
      if (_current && request.isCurrent) {
        _paging.error = localizedErrorMessage(l, error);
      }
    } finally {
      if (page == 1 && request.isCurrent) _completeRefresh();
      request.finish();
    }
  }

  void _apply(DbOnlineWatchedFilter filter) {
    if (!_current || filter == _filter) return;
    _completeRefresh();
    setState(() => _filter = filter);
    _requests.invalidate();
    refreshPagedController(
      controller: _paging,
      requests: _requests,
      loadPage: _fetch,
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _refresh() {
    _completeRefresh();
    _refreshCompleter = Completer<void>();
    final result = _refreshCompleter!.future;
    _requests.invalidate();
    refreshPagedController(
      controller: _paging,
      requests: _requests,
      loadPage: _fetch,
    );
    return result;
  }

  void _completeRefresh() {
    final pending = _refreshCompleter;
    _refreshCompleter = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void _scheduleTaskRefresh() {
    _taskRefresh?.cancel();
    _taskRefresh = Timer(const Duration(milliseconds: 150), () {
      if (!_current) return;
      ref.invalidate(
        dbOnlineMovieSubscriptionStatusesProvider(widget.serverId),
      );
      unawaited(_refresh());
    });
  }

  Future<void> _recheck() async {
    if (!_current) return;
    final total = await showGlassSheet<int>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => DbOnlineWatchedRecheckSheet(
        serverId: widget.serverId,
        filter: _filter,
      ),
    );
    if (!mounted || !_current || total == null) return;
    final l = AppL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          total == 0
              ? l.dbOnlineWatchedNoMatches
              : l.dbOnlineWatchedStarted(total),
        ),
      ),
    );
  }

  Future<void> _openFilterMenu() {
    return showDbOnlineFilterSheet(
      context,
      sections: (l) => [
        DbOnlineFilterSection(
          title: l.dbOnlineSort,
          options: [
            (value: 'create', label: l.dbOnlineWatchedSortAdded),
            (value: 'release', label: l.dbOnlineWatchedSortReleased),
          ],
          selected: _filter.sortBy,
          ascending: _filter.orderBy == 'asc',
          onSortSelected: (value, ascending) => _apply(
            _filter.copyWith(
              sortBy: value,
              orderBy: ascending ? 'asc' : 'desc',
            ),
          ),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineWatchedType,
          options: dbOnlineCategoryOptions(l, includeAll: true),
          selected: _filter.type,
          onSelected: (value) => _apply(_filter.copyWith(type: value)),
        ),
        DbOnlineFilterSection(
          title: l.dbOnlineWatchedRating,
          options: [
            (value: '', label: l.filterAll),
            for (final value in const ['5', '4', '3', '2', '1'])
              (value: value, label: '$value ${l.dbOnlineLibraryStars}'),
          ],
          selected: _filter.star,
          onSelected: (value) => _apply(_filter.copyWith(star: value)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final titleFontSize = AppText.movieCardTitle(context).fontSize!;
    final config = ref.watch(mediaRuntimeConfigProvider);
    final capability = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(widget.serverId),
    );
    final caps = capability.asData?.value;
    final canQuery = caps?.onlineAccount == true;
    final canRecheck = canQuery && caps?.database == true;
    DbOnlineSchedulerSnapshot? scheduler;
    if (canRecheck) {
      scheduler = ref
          .watch(dbOnlineSchedulerProvider(widget.serverId))
          .asData
          ?.value;
      ref.listen(dbOnlineSchedulerProvider(widget.serverId), (_, next) {
        final value = next.asData?.value;
        if (!_current || value == null) return;
        if (value.completionRevision > _completionRevision ||
            (_connectionRevision > 0 &&
                value.connectionRevision > _connectionRevision)) {
          _scheduleTaskRefresh();
        }
        _completionRevision = value.completionRevision;
        _connectionRevision = value.connectionRevision;
      });
    }
    final viewMode = ref.watch(mediaViewModePreferenceProvider(_viewModeKey));
    final delegate = PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, _) {
        final card = DbOnlineMovieCard(
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: viewMode == MediaViewMode.landscape,
          compact: viewMode == MediaViewMode.list,
          showRating: false,
          onTap: () => openDbOnlineMovieUnawaited(context, movie),
        );
        return viewMode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      },
      firstPageErrorIndicatorBuilder: (_) => ErrorView.list(
        message: _paging.error.toString(),
        onRetry: _paging.retryLastFailedRequest,
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: _paging.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: (_) =>
          EmptyView(message: l.dbOnlineWatchedEmpty),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );
    return DbOnlineFollowingLayout(
      title: l.dbOnlineWatchedTitle,
      scrollController: _scroll,
      actions: [
        if (canRecheck)
          HeaderActionButton(
            icon: Icons.manage_search_rounded,
            tooltip: l.dbOnlineWatchedRecheck,
            onPressed: _recheck,
          ),
        if (canQuery) ...[
          const SizedBox(width: 4),
          const MediaViewModePreferenceToggle(preferenceKey: _viewModeKey),
        ],
      ],
      filters: canQuery
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: l.dbOnlineLibraryFilters,
                  child: CompactFilterButton(
                    label: '',
                    icon: Icons.tune_rounded,
                    active: _filter.type != 'all' || _filter.star.isNotEmpty,
                    onTap: () => unawaited(_openFilterMenu()),
                  ),
                ),
                if (scheduler != null &&
                    (scheduler.rechecking || scheduler.recheckQueued)) ...[
                  const SizedBox(height: 12),
                  Text(
                    !scheduler.connected
                        ? l.dbOnlineWatchedReconnecting
                        : scheduler.rechecking
                        ? l.dbOnlineWatchedProgress(
                            scheduler.completed,
                            scheduler.total,
                          )
                        : l.dbOnlineWatchedQueued,
                    style: AppText.meta(context),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: scheduler.rechecking && scheduler.connected
                        ? scheduler.percent / 100
                        : null,
                  ),
                ],
              ],
            )
          : null,
      body: capability.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: localizedErrorMessage(l, error),
          onRetry: () => ref.invalidate(
            dbOnlineSubscriptionCapabilitiesProvider(widget.serverId),
          ),
        ),
        data: (capabilities) => !capabilities.onlineAccount
            ? EmptyView(message: l.dbOnlineWatchedRequiresAccount)
            : RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: MediaListLayout.contentPadding,
                      sliver: viewMode == MediaViewMode.portrait
                          ? PagedSliverGrid<int, DbOnlineMovie>(
                              pagingController: _paging,
                              showNoMoreItemsIndicatorAsGridChild: false,
                              gridDelegate: MediaGridDelegate(
                                textScaleFactor:
                                    MediaQuery.textScalerOf(
                                      context,
                                    ).scale(titleFontSize) /
                                    titleFontSize,
                              ),
                              builderDelegate: delegate,
                            )
                          : PagedSliverList<int, DbOnlineMovie>(
                              pagingController: _paging,
                              builderDelegate: delegate,
                            ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
      ),
    );
  }
}
