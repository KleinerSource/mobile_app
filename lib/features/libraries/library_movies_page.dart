import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/library.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import '../../shared/pagination_footer.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 某个媒体库下的影片列表 · library_id 过滤
class LibraryMoviesPage extends ConsumerStatefulWidget {
  const LibraryMoviesPage({super.key, required this.library});
  final LibraryItem library;

  @override
  ConsumerState<LibraryMoviesPage> createState() => _LibraryMoviesPageState();
}

class _LibraryMoviesPageState extends ConsumerState<LibraryMoviesPage> {
  static const _pageSize = 30;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  Completer<void>? _refreshCompleter;

  MovieFilter get _filter => MovieFilter(
    libraryId: widget.library.id,
    sortBy: 'created_at',
    sortOrder: 'desc',
  );

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _completeRefresh();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(moviesRepositoryProvider);
      final page = await repo.list(_filter, limit: _pageSize, offset: offset);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      if (offset == 0) _completeRefresh();
    } catch (e) {
      _controller.error = toApiException(e).message;
      if (offset == 0) _completeRefresh();
    }
  }

  Future<void> _refreshMovies() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    refreshImageCache(ref);
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

  int _hueFor(String name) {
    final h = (name.codeUnits.fold(0, (a, b) => a + b) * 31) % 360;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final hue = _hueFor(widget.library.name);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshMovies,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  background: _Hero(library: widget.library, hue: hue),
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
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailPage(movieId: m.id),
                        ),
                      ),
                    ),
                    firstPageProgressIndicatorBuilder: (_) =>
                        const Center(child: CupertinoActivityIndicator()),
                    firstPageErrorIndicatorBuilder: (_) => ErrorView(
                      message: _controller.error?.toString() ?? '加载失败',
                      onRetry: () => _controller.refresh(),
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        const EmptyView(message: '这个媒体库还没有影片'),
                    noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.library, required this.hue});
  final LibraryItem library;
  final int hue;

  @override
  Widget build(BuildContext context) {
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
                    '媒体库',
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
                    library.name,
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
                    '${library.fileCount} 部影片',
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
