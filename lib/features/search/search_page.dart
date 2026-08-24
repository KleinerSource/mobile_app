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
import '../../shared/glass_menu.dart';
import '../../shared/movie_card.dart';
import '../../shared/paged_scroll_position_restorer.dart';
import '../../shared/pagination_footer.dart';
import '../movie_detail/movie_detail_page.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  MovieSearchType _searchType = MovieSearchType.title;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
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
                    Icon(Icons.search, size: 18, color: c.muted),
                    const SizedBox(width: 4),
                    _SearchTypeMenu(
                      value: _searchType,
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
                          _debounce?.cancel();
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
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

class _SearchTypeMenu extends StatelessWidget {
  const _SearchTypeMenu({required this.value, required this.onChanged});

  final MovieSearchType value;
  final ValueChanged<MovieSearchType> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return GlassMenuAnchor<MovieSearchType>(
      width: 204,
      offset: const Offset(0, 4),
      placement: GlassMenuPlacement.below,
      alignment: GlassMenuAlignment.start,
      initialSelection: value,
      entries: [
        for (final type in MovieSearchType.values)
          GlassMenuEntry<MovieSearchType>.action(
            value: type,
            builder: (context, selected, onTap) => GlassMenuRow(
              icon: type.icon,
              iconSize: 18,
              label: type.label(l),
              selected: selected,
              onTap: onTap,
            ),
          ),
      ],
      onSelected: (type) {
        if (type != value) onChanged(type);
      },
      child: _SearchTypeButton(type: value, color: c.text, muted: c.muted),
    );
  }
}

class _SearchTypeButton extends StatelessWidget {
  const _SearchTypeButton({
    required this.type,
    required this.color,
    required this.muted,
  });

  final MovieSearchType type;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            type.label(AppL10n.of(context)),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 16, color: muted),
        ],
      ),
    );
  }
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)),
    );
    if (mounted) await _refreshAfterMovie();
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

      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      _scrollRestorer.restoreAfterPage(_scrollController);
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
