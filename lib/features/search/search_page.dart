import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/error_view.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/debouncer.dart';
import '../../shared/pagination_footer.dart';
import '../../shared/search_type_menu.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_data_changes.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _debounce = Debouncer();
  String _query = '';
  MovieSearchType _searchType = MovieSearchType.title;

  @override
  void dispose() {
    _controller.dispose();
    _debounce.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce.run(() {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppL10n.of(context).searchTitle.toUpperCase(),
                    style: AppText.eyebrow(context),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppL10n.of(context).searchFind,
                    style: AppText.pageTitle(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    SearchTypeMenu<MovieSearchType>(
                      value: _searchType,
                      options: [
                        for (final type in MovieSearchType.values)
                          SearchTypeOption<MovieSearchType>(
                            value: type,
                            label: type.label(AppL10n.of(context)),
                            icon: type.icon,
                          ),
                      ],
                      onChanged: (type) {
                        setState(() => _searchType = type);
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: _searchType.placeholder(
                            AppL10n.of(context),
                          ),
                          hintStyle: TextStyle(
                            color: c.muted,
                            fontWeight: FontWeight.w500,
                          ),
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: _onChanged,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: c.muted),
                        onPressed: () {
                          _debounce.cancel();
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                    const SizedBox(width: 4),
                    Icon(Icons.search, size: 18, color: c.muted),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _EmptyHint()
                  : _SearchResults(
                      key: ValueKey('${_searchType.queryValue}:$_query'),
                      query: _query,
                      searchType: _searchType,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on MovieSearchType {
  String label(AppL10n l) => switch (this) {
    MovieSearchType.title => l.searchModeTitle,
    MovieSearchType.num => l.searchModeNum,
    MovieSearchType.actor => l.searchModeActor,
    MovieSearchType.filename => l.searchModeFilename,
  };

  IconData get icon => switch (this) {
    MovieSearchType.title => Icons.movie_outlined,
    MovieSearchType.num => Icons.numbers_rounded,
    MovieSearchType.actor => Icons.person_outline_rounded,
    MovieSearchType.filename => Icons.description_outlined,
  };

  String placeholder(AppL10n l) => switch (this) {
    MovieSearchType.title => l.searchPlaceholderTitle,
    MovieSearchType.num => l.searchPlaceholderNum,
    MovieSearchType.actor => l.searchPlaceholderActor,
    MovieSearchType.filename => l.searchPlaceholderFilename,
  };
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: c.muted2),
          const SizedBox(height: 12),
          Text(
            AppL10n.of(context).searchEmpty,
            style: AppText.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(AppL10n.of(context).searchHint2, style: AppText.meta(context)),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerStatefulWidget {
  const _SearchResults({
    super.key,
    required this.query,
    required this.searchType,
  });
  final String query;
  final MovieSearchType searchType;

  @override
  ConsumerState<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<_SearchResults> {
  static const _pageSize = 60;

  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );

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
    await refreshPagedListInBackground<MovieListItem>(
      controller: _controller,
      loadFirstPage: (limit) => ref
          .read(moviesRepositoryProvider)
          .list(
            MovieFilter(
              search: widget.query,
              searchType: widget.searchType,
              sortBy: 'created_at',
              sortOrder: 'desc',
            ),
            limit: limit,
            offset: 0,
          ),
    );
  }

  Future<void> _fetch(int offset) async {
    try {
      final page = await ref
          .read(moviesRepositoryProvider)
          .list(
            MovieFilter(
              search: widget.query,
              searchType: widget.searchType,
              sortBy: 'created_at',
              sortOrder: 'desc',
            ),
            limit: _pageSize,
            offset: offset,
          );
      if (!mounted) return;

      applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: page.items,
        totalCount: page.totalCount,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
    } catch (error) {
      if (!mounted) return;
      _controller.error = toApiException(error).message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    return CustomScrollView(
      controller: _scrollController,
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          sliver: PagedSliverGrid<int, MovieListItem>(
            pagingController: _controller,
            showNoMoreItemsIndicatorAsGridChild: false,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
            ),
            builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
              itemBuilder: (ctx, movie, _) => MovieCard(
                key: ValueKey(movie.id),
                movie: movie,
                posterUrlBuilder: urlBuilder,
                onTap: () => unawaited(_openMovie(movie.id)),
              ),
              firstPageProgressIndicatorBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => ErrorView(
                message: _controller.error?.toString() ?? '加载失败',
                onRetry: _controller.refresh,
              ),
              newPageErrorIndicatorBuilder: (_) =>
                  PaginationRetry(onRetry: _controller.retryLastFailedRequest),
              noItemsFoundIndicatorBuilder: (_) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppL10n.of(context).searchNoResult,
                    style: AppText.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
            ),
          ),
        ),
      ],
    );
  }
}
