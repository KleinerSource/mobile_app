import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_resource_filter.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_resource_condition_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_filter_options.dart';
import 'package:omm/features/db_online/widgets/db_online_list_filter_sheets.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

/// 实体（演员/系列/片商/导演/清单）的影片列表落地页。
///
/// 与网页端 `/actor/:id/movies?type=...` 一致，按发布时间倒序分页；
/// [kind] 使用服务端实体类型（actor/series/maker/director/list）。
/// 页头小字 [eyebrow] 由入口传入：搜索入口传搜索类型名，其余入口默认 DB ONLINE。
class DbOnlineEntityMoviesPage extends ConsumerStatefulWidget {
  const DbOnlineEntityMoviesPage({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    this.eyebrow = 'DB ONLINE',
  });

  final String kind;
  final String id;
  final String title;
  final String eyebrow;

  @override
  ConsumerState<DbOnlineEntityMoviesPage> createState() =>
      _DbOnlineEntityMoviesPageState();
}

class _DbOnlineEntityMoviesPageState
    extends ConsumerState<DbOnlineEntityMoviesPage> {
  static const _pageSize = 24;
  static const _viewModeKey = 'db_online.entity_movies.view_mode.v1';

  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();
  Completer<void>? _refreshCompleter;
  MediaViewMode _viewMode = MediaViewMode.portrait;

  // 落地页过滤器，与网页端一致：资源条件多选（m/c/s/p，p 需服务端
  // can_play 开启）、排序单选、演员专属年份；复用共享选项与固定顺序。
  String _sortBy = 'release';
  final Set<String> _resourceFilters = {};
  String _year = '';

  bool get _isActor => widget.kind == 'actor';

  String get _filterParam =>
      dbOnlineResourceConditionLetters(_resourceFilters).join(',');

  @override
  void initState() {
    super.initState();
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
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
    try {
      final result = await ref.read(
        dbOnlineEntityMoviesPageProvider(
          DbOnlineEntityMoviesPageRequest(
            serverId:
                ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
            kind: widget.kind,
            id: widget.id,
            page: page,
            limit: _pageSize,
            sortBy: _sortBy,
            filter: _filterParam,
            year: _isActor ? _year : '',
          ),
        ).future,
      );
      if (!pageRequest.isCurrent || !mounted) return;

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

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  /// 过滤器变化后重置分页重新加载。
  void _applyFilter(VoidCallback mutate) {
    setState(mutate);
    unawaited(_refresh());
  }

  bool get _filtersActive =>
      _resourceFilters.isNotEmpty || _year.isNotEmpty || _sortBy != 'release';

  // 服务端 can_play 状态在 build 中订阅，供筛选弹层读取快照。
  late bool _onlinePlayAvailable = false;

  /// 落地页过滤器弹层：资源条件（多选）+ 演员年份 + 排序，
  /// 与关注列表的筛选弹层同款交互，选择后立即生效并保持打开。
  Future<void> _openFilterSheet() {
    final currentYear = DateTime.now().year;
    // build 中 watch 保持最新，弹层打开时读取快照。
    final onlinePlayAvailable = _onlinePlayAvailable;
    return showDbOnlineFilterSheet(
      context,
      sections: (l) => [
        DbOnlineFilterSection(
          title: l.dbOnlineFollowingConditions,
          options: dbOnlineResourceConditionOptions(
            l,
            includePlayable: onlinePlayAvailable,
          ),
          selected: _filterParam,
          multiSelect: true,
          onSelected: (value) => _applyFilter(() {
            _resourceFilters
              ..clear()
              ..addAll(value.split(',').where((item) => item.isNotEmpty));
          }),
        ),
        if (_isActor)
          DbOnlineFilterSection(
            title: l.dbOnlineFollowingYear,
            options: [
              (value: '', label: l.filterAll),
              for (var year = currentYear; year >= 2011; year--)
                (value: '$year', label: '$year'),
            ],
            selected: _year,
            onSelected: (value) => _applyFilter(() => _year = value),
          ),
        DbOnlineFilterSection(
          title: l.dbOnlineSort,
          options: dbOnlineEntityMovieSortOptions(l),
          selected: _sortBy,
          onSelected: (value) => _applyFilter(() => _sortBy = value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    _onlinePlayAvailable = ref.watch(dbOnlineOnlinePlayAvailableProvider);
    final isPortrait = _viewMode == MediaViewMode.portrait;
    final delegate = PagedChildBuilderDelegate<DbOnlineMovie>(
      itemBuilder: (context, movie, _) {
        final card = DbOnlineMovieCard(
          key: ValueKey(_movieKey(movie)),
          movie: movie,
          config: config,
          width: double.infinity,
          landscape: _viewMode == MediaViewMode.landscape,
          compact: _viewMode == MediaViewMode.list,
          // 列表模式升级为预览条目：左封面 + 右预览图翻页。
          previewList: _viewMode == MediaViewMode.list,
          onTap: () => openDbOnlineMovieUnawaited(context, movie),
        );
        return _viewMode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      },
      firstPageProgressIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Center(child: CircularProgressIndicator(color: colors.accent)),
      ),
      newPageProgressIndicatorBuilder: (_) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      firstPageErrorIndicatorBuilder: (context) => ErrorView.list(
        retryLabel: AppL10n.of(context).dbOnlineRetry,
        message:
            _controller.error?.toString() ?? AppL10n.of(context).loadFailed,
        onRetry: _controller.retryLastFailedRequest,
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: _controller.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: (_) =>
          EmptyView(message: AppL10n.of(context).dbOnlineNoData),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: widget.eyebrow,
              bottomPadding: PageHeader.aboveListGap,
              title: widget.title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompactFilterButton(
                    label: '',
                    icon: Icons.tune_rounded,
                    active: _filtersActive,
                    onTap: () => unawaited(_openFilterSheet()),
                  ),
                  const SizedBox(width: 8),
                  MediaViewModeToggle(
                    mode: _viewMode,
                    onChanged: (mode) => unawaited(_setViewMode(mode)),
                  ),
                ],
              ),
            ),
            body: RefreshIndicator(
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
      ),
    );
  }
}
