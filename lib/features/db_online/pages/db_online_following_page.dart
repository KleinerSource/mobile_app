import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_following_providers.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_following_filter_sheet.dart';
import 'package:omm/features/db_online/widgets/db_online_following_presets_sheet.dart';
import 'package:omm/features/db_online/widgets/db_online_following_widgets.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_subscription_action.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_followed_users_page.dart';

class DbOnlineFollowingPage extends ConsumerWidget {
  const DbOnlineFollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    // 换服务器时收起这个模块打开的弹层和子页面，筛选状态由新 key 重建。
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
    return _FollowingPage(key: ValueKey(serverId), serverId: serverId);
  }
}

class _FollowingPage extends ConsumerStatefulWidget {
  const _FollowingPage({super.key, required this.serverId});
  final String serverId;

  @override
  ConsumerState<_FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<_FollowingPage> {
  static const _pageSize = 24;
  static const _viewModeKey = 'db_online.following.view_mode.v1';
  final _paging = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _requests = PagedRequestCoordinator();
  final _scroll = ScrollController();
  DbOnlineFollowingFilter _filter = const DbOnlineFollowingFilter();
  int? _presetId;
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _paging.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _completeRefresh();
    _requests.dispose();
    _paging.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _current =>
      mounted && isDbOnlineFollowingServer(ref, widget.serverId);

  Future<void> _fetch(int page) async {
    if (!_current) return;
    final request = _requests.begin(page);
    if (request == null) return;
    final filter = _filter;
    final l = AppL10n.of(context);
    try {
      final result = await ref
          .read(dboMediaRepositoryProvider)
          .taggedMoviesPage(
            filterBy: filter.filterBy,
            page: page,
            limit: _pageSize,
            sortBy: filter.sortBy,
            orderBy: filter.sortBy == 'update' ? 'desc' : filter.orderBy,
          );
      if (!_current || !request.isCurrent) return;
      final seen = {
        for (final movie in _paging.itemList ?? <DbOnlineMovie>[])
          movie.id.isEmpty ? movie.number : movie.id,
      };
      final items = result.movies
          .where(
            (movie) => seen.add(movie.id.isEmpty ? movie.number : movie.id),
          )
          .toList();
      if (!result.hasMore || result.movies.length < _pageSize) {
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

  void _apply(DbOnlineFollowingFilter filter, {int? presetId}) {
    if (!_current) return;
    _completeRefresh();
    setState(() {
      _filter = filter;
      _presetId = presetId;
    });
    _requests.invalidate();
    _paging.refresh();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _refresh() {
    _completeRefresh();
    _refreshCompleter = Completer<void>();
    final future = _refreshCompleter!.future;
    _requests.invalidate();
    refreshPagedController(
      controller: _paging,
      requests: _requests,
      loadPage: _fetch,
    );
    return future;
  }

  void _completeRefresh() {
    final pending = _refreshCompleter;
    _refreshCompleter = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> _filters(bool database) => showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    minHeight: sheetMinHeight(context),
    builder: (_) => DbOnlineFollowingFilterSheet(
      serverId: widget.serverId,
      filter: _filter,
      database: database,
      onChanged: _apply,
    ),
  );

  Future<void> _managePresets() async {
    final preset = await showGlassSheet<DbOnlineFollowingPreset>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => DbOnlineFollowingPresetsSheet(
        serverId: widget.serverId,
        filter: _filter,
      ),
    );
    if (preset != null && _current) {
      _apply(preset.filter, presetId: preset.id);
    }
  }

  Future<void> _savePreset() async {
    final preset = await showDbOnlineFollowingPresetDialog(
      context,
      filter: _filter,
    );
    if (!mounted || preset == null || !_current) return;
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(dbOnlineFollowingApiProvider(widget.serverId))
          .savePreset(preset);
      if (!_current) return;
      ref.invalidate(dbOnlineFollowingPresetsProvider(widget.serverId));
      setState(() => _presetId = saved.id);
    } catch (error) {
      if (_current) {
        messenger.showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l, error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final capability = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(widget.serverId),
    );
    final database = capability.asData?.value.database == true;
    final query = capability.asData?.value.onlineQuery == true;
    final presets = database
        ? ref.watch(dbOnlineFollowingPresetsProvider(widget.serverId))
        : null;
    final config = ref.watch(mediaRuntimeConfigProvider);
    final externalId = _filter.followExternalId;
    final styles = database
        ? ref
              .watch(dbOnlineFollowingStylesProvider(widget.serverId))
              .asData
              ?.value
        : null;
    final styleName = _filter.followStyleIds
        .map(
          (id) =>
              styles?.where((item) => item.id == id).firstOrNull?.name ?? id,
        )
        .join(', ');
    final viewMode = ref.watch(mediaViewModePreferenceProvider(_viewModeKey));
    final delegate = PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, _) {
        final card = DbOnlineMovieCard(
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: viewMode == MediaViewMode.landscape,
          compact: viewMode == MediaViewMode.list,
          // 列表模式升级为预览条目：左封面 + 右预览图翻页。
          previewList: viewMode == MediaViewMode.list,
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
          EmptyView(message: l.dbOnlineFollowingNoMovies),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );
    return DbOnlineFollowingLayout(
      eyebrow: l.tabYou,
      title: l.dbOnlineFollowingTitle,
      scrollController: _scroll,
      actions: [
        if (database && externalId.isNotEmpty)
          DbOnlineSubscriptionAction(
            key: ValueKey(externalId),
            kind: 'series',
            id: externalId,
            title: styleName,
            initial: const {'sub_type': 'follow'},
          ),
        if (database)
          HeaderActionButton(
            icon: Icons.people_outline_rounded,
            tooltip: l.dbOnlineFollowingUsers,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    DbOnlineFollowedUsersPage(serverId: widget.serverId),
              ),
            ),
          ),
        HeaderActionButton(
          icon: Icons.tune_rounded,
          tooltip: l.dbOnlineFollowingFilters,
          onPressed: query ? () => _filters(database) : null,
        ),
        const SizedBox(width: 4),
        const MediaViewModePreferenceToggle(preferenceKey: _viewModeKey),
      ],
      filters: database
          ? Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets!.when<List<Widget>>(
                        skipLoadingOnReload: true,
                        loading: () => const [
                          Padding(
                            padding: EdgeInsets.only(right: 7),
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ],
                        error: (error, _) => [
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: Tooltip(
                              message: localizedErrorMessage(l, error),
                              child: CompactFilterButton(
                                label: l.dbOnlineRetry,
                                icon: Icons.refresh_rounded,
                                active: false,
                                onTap: () => ref.invalidate(
                                  dbOnlineFollowingPresetsProvider(
                                    widget.serverId,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        data: (items) => [
                          for (final preset in items)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: CompactFilterButton(
                                label: preset.name,
                                active: _presetId == preset.id,
                                onTap: () =>
                                    _apply(preset.filter, presetId: preset.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Tooltip(
                  message: l.dbOnlineFollowingAddPreset,
                  child: CompactFilterButton(
                    label: '',
                    icon: Icons.add_rounded,
                    active: false,
                    onTap: _savePreset,
                  ),
                ),
                const SizedBox(width: 7),
                Tooltip(
                  message: l.dbOnlineFollowingManagePresets,
                  child: CompactFilterButton(
                    label: '',
                    icon: Icons.settings_outlined,
                    active: false,
                    onTap: _managePresets,
                  ),
                ),
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
        data: (capabilities) => !capabilities.onlineQuery
            ? EmptyView(message: l.dbOnlineFollowingRequiresOnlineQuery)
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
                              gridDelegate: const MediaGridDelegate(),
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
