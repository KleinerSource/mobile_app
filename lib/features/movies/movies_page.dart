import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/platform.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import 'movie_filter.dart';
import 'movies_providers.dart';

class MoviesPage extends ConsumerStatefulWidget {
  const MoviesPage({super.key});

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  static const _pageSize = 50;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _searchController = TextEditingController();
  MovieFilter _currentFilter = const MovieFilter();

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(moviesRepositoryProvider);
      final page = await repo.list(_currentFilter, limit: _pageSize, offset: offset);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  void _onFilterChanged(MovieFilter newFilter) {
    if (newFilter == _currentFilter) return;
    setState(() => _currentFilter = newFilter);
    ref.read(movieFilterProvider.notifier).state = newFilter;
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return AppScaffold(
      body: CustomScrollView(
        slivers: [
          const AppLargeNavBar(title: '影片'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: AppSearchField(
                controller: _searchController,
                placeholder: '搜索影片',
                onSubmitted: (v) {
                  _onFilterChanged(_currentFilter.copyWith(search: v));
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: PagedSliverGrid<int, MovieListItem>(
              pagingController: _controller,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.55,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                itemBuilder: (ctx, item, idx) => MovieCard(
                  movie: item,
                  posterUrlBuilder: urlBuilder,
                ),
                firstPageErrorIndicatorBuilder: (_) => ErrorView(
                  message: _controller.error?.toString() ?? '加载失败',
                  onRetry: () => _controller.refresh(),
                ),
                newPageErrorIndicatorBuilder: (_) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => _controller.retryLastFailedRequest(),
                    child: Text('加载失败，点击重试：${_controller.error}'),
                  ),
                ),
                noItemsFoundIndicatorBuilder: (_) =>
                    const EmptyView(message: '没有找到符合条件的影片'),
                firstPageProgressIndicatorBuilder: (_) =>
                    const Center(child: CupertinoActivityIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
