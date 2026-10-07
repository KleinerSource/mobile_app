import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/paged_request_coordinator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_paged_sliver.dart';

/// dbonline 最新影片的完整列表。
///
/// [sortBy] 只接受 `update` 或 `release`，页面使用和 OMM 影片库相同的
/// 分页网格与卡片尺寸；数据源仍保持 dbonline 的字符串影片标识。
class DbOnlineLatestMoviesPage extends ConsumerStatefulWidget {
  const DbOnlineLatestMoviesPage({super.key, required this.sortBy});

  final String sortBy;

  @override
  ConsumerState<DbOnlineLatestMoviesPage> createState() =>
      _DbOnlineLatestMoviesPageState();
}

class _DbOnlineLatestMoviesPageState
    extends ConsumerState<DbOnlineLatestMoviesPage> {
  static const _pageSize = 24;

  final _requests = PagedRequestCoordinator(firstPageKey: 1);
  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();

  MediaViewMode get _viewMode => ref.read(mediaServerViewModeProvider);

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
      final request = DbOnlineLatestPageRequest(
        serverId: ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
        page: page,
        limit: _pageSize,
        sortBy: widget.sortBy,
        sort: widget.sortBy,
      );
      final result = await ref.read(dbOnlineLatestPageProvider(request).future);
      if (!pageRequest.isCurrent) return;
      if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    // 订阅全局视图模式，切换时重建列表；_viewMode 供 delegate 读取。
    ref.watch(mediaServerViewModeProvider);
    final l = AppL10n.of(context);
    final title = widget.sortBy == 'release'
        ? l.dbOnlineLatestReleased
        : l.dbOnlineRecentUpdated;

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          bottom: false,
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: 'DB ONLINE',
              bottomPadding: PageHeader.aboveListGap,
              title: title,
              trailing: MediaViewModeToggle(
                mode: _viewMode,
                onChanged: ref.read(mediaServerViewModeProvider.notifier).set,
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
                      emptyBuilder: (_) => const _ListEmpty(),
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

class _ListEmpty extends StatelessWidget {
  const _ListEmpty();

  @override
  Widget build(BuildContext context) {
    return EmptyView(message: AppL10n.of(context).dbOnlineNoData);
  }
}
