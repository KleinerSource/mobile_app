import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';

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

  final _controller = PagingController<int, DbOnlineMovie>(firstPageKey: 1);
  final _scrollController = ScrollController();
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _completeRefresh();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    try {
      final request = DbOnlineLatestPageRequest(
        serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
        page: page,
        limit: _pageSize,
        sortBy: widget.sortBy,
        sort: widget.sortBy,
      );
      final result = await ref.read(dbOnlineLatestPageProvider(request).future);
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
      if (page == 1) _completeRefresh();
    } catch (error) {
      _controller.error = toApiException(error).message;
      if (page == 1) _completeRefresh();
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
    _controller.refresh();
    return completer.future;
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
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
    final l = AppL10n.of(context);
    final title = widget.sortBy == 'release'
        ? l.dbOnlineLatestReleased
        : l.dbOnlineRecentUpdated;

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: 'dbonline',
              title: title,
              subtitle: l.dbOnlineAutoLoadMoreHint,
            ),
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    sliver: PagedSliverGrid<int, DbOnlineMovie>(
                      pagingController: _controller,
                      // 尾部提示整行跨列渲染（与 OMM 影片库一致）。
                      showNoMoreItemsIndicatorAsGridChild: false,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio:
                            MediaCardTemplate.gridChildAspectRatio,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: spacing,
                      ),
                      builderDelegate: PagedChildBuilderDelegate<DbOnlineMovie>(
                        itemBuilder: (context, movie, index) =>
                            DbOnlineMovieCard(
                              key: ValueKey(_movieKey(movie)),
                              movie: movie,
                              config: config,
                              width: itemWidth,
                              onTap: () =>
                                  openDbOnlineMovieUnawaited(context, movie),
                            ),
                        firstPageProgressIndicatorBuilder: (_) => Padding(
                          padding: const EdgeInsets.only(top: 56),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colors.accent,
                            ),
                          ),
                        ),
                        newPageProgressIndicatorBuilder: (_) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        firstPageErrorIndicatorBuilder: (context) => _ListError(
                          message:
                              _controller.error?.toString() ??
                              AppL10n.of(context).loadFailed,
                          onRetry: _controller.retryLastFailedRequest,
                        ),
                        newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                          onRetry: _controller.retryLastFailedRequest,
                        ),
                        noItemsFoundIndicatorBuilder: (_) => const _ListEmpty(),
                        noMoreItemsIndicatorBuilder: (_) =>
                            const NoMoreContent(),
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

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

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
            child: Text(AppL10n.of(context).dbOnlineRetry),
          ),
        ],
      ),
    );
  }
}

class _ListEmpty extends StatelessWidget {
  const _ListEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          AppL10n.of(context).dbOnlineNoData,
          style: AppText.meta(context),
        ),
      ),
    );
  }
}
