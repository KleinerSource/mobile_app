import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
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
import 'package:omm/shared/page_header.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_paged_sliver.dart';
import 'package:omm/features/db_online/providers/db_online_resource_condition_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_filter_options.dart';
import 'package:omm/features/db_online/widgets/db_online_list_filter_sheets.dart';

/// 实体（演员/系列/片商/发行商/导演/清单/类别）的影片列表落地页。
///
/// 与网页端实体落地页（`/{actor|series|maker|publisher|director|list|
/// category}/:id/movies`）一致，服务端在线优先、不可用时回退数据库；
/// [kind] 使用服务端实体类型（actor/series/maker/publisher/director/
/// list/category）。
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

  final _requests = PagedRequestCoordinator(firstPageKey: 1);
  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();

  MediaViewMode get _viewMode => ref.read(mediaServerViewModeProvider);

  // 落地页过滤器，与网页端一致：资源条件多选（m/c/s/p，p 需服务端
  // can_play 开启）、排序单选、演员专属年份；复用共享选项与固定顺序。
  // 类别（tag）查询不支持资源条件，仅保留排序。
  String _sortBy = 'release';
  final Set<String> _resourceFilters = {};
  String _year = '';

  // 首页数据来源（api=在线 / database=回退），用于页头降级标注。
  String? _dataSource;

  bool get _isActor => widget.kind == 'actor';
  bool get _isCategory => widget.kind == 'category';

  String get _filterParam => _isCategory
      ? ''
      : dbOnlineResourceConditionLetters(_resourceFilters).join(',');

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
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
      if (page == 1 && _dataSource != result.source) {
        setState(() => _dataSource = result.source);
      }
    } catch (error) {
      if (!pageRequest.isCurrent) return;
      _controller.error = localizedErrorMessage(AppL10n.of(context), error);
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
    return _requests.refresh(() {
      refreshPagedController(
        controller: _controller,
        requests: _requests,
        loadPage: _fetchPage,
      );
    });
  }

  /// 过滤器变化后重置分页重新加载。
  void _applyFilter(VoidCallback mutate) {
    setState(mutate);
    _requests.invalidate();
    unawaited(_refresh());
  }

  bool get _filtersActive =>
      (!_isCategory && _resourceFilters.isNotEmpty) ||
      _year.isNotEmpty ||
      _sortBy != 'release';

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
          title: l.dbOnlineSort,
          options: dbOnlineEntityMovieSortOptions(l),
          selected: _sortBy,
          onSelected: (value) => _applyFilter(() => _sortBy = value),
        ),
        // 类别（tag）查询不支持 m/c/s/p 资源条件。
        if (!_isCategory)
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    _onlinePlayAvailable = ref.watch(dbOnlineOnlinePlayAvailableProvider);
    // 订阅全局视图模式，切换时重建列表；_viewMode 供 delegate 读取。
    ref.watch(mediaServerViewModeProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              // 在线不可用回退数据库时，页头标注来源提示数据为本地快照。
              eyebrow: _dataSource == 'database'
                  ? '${widget.eyebrow} · ${AppL10n.of(context).dbOnlineSourceDatabase}'
                  : widget.eyebrow,
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
                  const SizedBox(width: PageHeader.actionGap),
                  MediaViewModeToggle(
                    mode: _viewMode,
                    onChanged: ref
                        .read(mediaServerViewModeProvider.notifier)
                        .set,
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
                    padding: MediaListLayout.contentPadding.copyWith(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: DbOnlineMoviePagedSliver(
                      controller: _controller,
                      mode: _viewMode,
                      config: config,
                      movieKey: _movieKey,
                      onOpen: (movie) =>
                          openDbOnlineMovieUnawaited(context, movie),
                      emptyBuilder: (_) => EmptyView(
                        message: AppL10n.of(context).dbOnlineNoData,
                      ),
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
