import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/models/resource.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/pagination_footer.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_data_changes.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';
import 'resources_repository.dart';

/// 按 genre/tag/series 维度筛选的影片列表
class ResourceMoviesPage extends ConsumerStatefulWidget {
  const ResourceMoviesPage({
    super.key,
    required this.kind,
    required this.resource,
  });

  final ResourceKind kind;
  final ResourceItem resource;

  @override
  ConsumerState<ResourceMoviesPage> createState() => _ResourceMoviesPageState();
}

class _ResourceMoviesPageState extends ConsumerState<ResourceMoviesPage> {
  static const _pageSize = 30;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  int? _totalCount;

  MovieFilter get _filter {
    switch (widget.kind) {
      case ResourceKind.genre:
        return MovieFilter(
          genreIds: [widget.resource.id],
          sortBy: 'created_at',
          sortOrder: 'desc',
        );
      case ResourceKind.tag:
        return MovieFilter(
          tagIds: [widget.resource.id],
          sortBy: 'created_at',
          sortOrder: 'desc',
        );
      case ResourceKind.series:
        return MovieFilter(
          seriesIds: [widget.resource.id],
          sortBy: 'created_at',
          sortOrder: 'desc',
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(moviesRepositoryProvider);
      final page = await repo.list(_filter, limit: _pageSize, offset: offset);
      if (mounted) setState(() => _totalCount = page.totalCount);
      applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: page.items,
        totalCount: page.totalCount,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  Future<void> _openMovie(int movieId) async {
    final changesBeforeVisit = MovieDataChanges.snapshot(movieId: movieId);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
    );
    if (!mounted) return;
    // 详情页内没有任何真实变更时沿用缓存,不刷新。
    final now = changesBeforeVisit.latest;
    if (now.imagesChangedSince(changesBeforeVisit)) refreshImageCache(ref);
    if (now.metadata != changesBeforeVisit.metadata ||
        now.progress != changesBeforeVisit.progress) {
      await _refreshAfterMovie();
    }
  }

  Future<void> _refreshAfterMovie() async {
    final refreshed = await refreshPagedListInBackground<MovieListItem>(
      controller: _controller,
      loadFirstPage: (limit) async {
        final page = await ref
            .read(moviesRepositoryProvider)
            .list(_filter, limit: limit, offset: 0);
        _totalCount = page.totalCount;
        return page;
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, size: 18),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _Hero(
                  kind: widget.kind,
                  item: widget.resource,
                  overrideCount: _totalCount,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 80),
              sliver: PagedSliverGrid<int, MovieListItem>(
                pagingController: _controller,
                showNoMoreItemsIndicatorAsGridChild: false,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                ),
                builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                  itemBuilder: (ctx, m, idx) => MovieCard(
                    movie: m,
                    posterUrlBuilder: urlBuilder,
                    onTap: () => unawaited(_openMovie(m.id)),
                  ),
                  firstPageProgressIndicatorBuilder: (_) =>
                      const Center(child: CupertinoActivityIndicator()),
                  firstPageErrorIndicatorBuilder: (_) => ErrorView(
                    message: _controller.error?.toString() ?? '加载失败',
                    onRetry: () => _controller.refresh(),
                  ),
                  noItemsFoundIndicatorBuilder: (_) =>
                      const EmptyView(message: '这个维度下还没有影片'),
                  noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.kind, required this.item, this.overrideCount});
  final ResourceKind kind;
  final ResourceItem item;
  final int? overrideCount;

  @override
  Widget build(BuildContext context) {
    // 用名称 hash 选一个稳定的 hue
    final hue = (item.name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppHues.top(hue), AppHues.bottom(hue)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            width: 240,
            height: 240,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppHues.highlight(hue),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    kind.icon,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      letterSpacing: -0.9,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${overrideCount ?? item.movieCount} 部影片',
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
