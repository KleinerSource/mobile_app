import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_search_field.dart';
import '../../core/ui/tokens.dart';
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
      final page = await repo.list(_currentFilter,
          limit: _pageSize, offset: offset);
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

  void _onSubmitted(String v) {
    final next = _currentFilter.copyWith(search: v);
    if (next == _currentFilter) return;
    setState(() => _currentFilter = next);
    ref.read(movieFilterProvider.notifier).state = next;
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = Theme.of(context).extension<AppColors>()!;

    return AppScaffold(
      body: AppPage(
        title: '影片库',
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l, 0, AppSpacing.l, AppSpacing.m,
              ),
              child: AppSearchField(
                controller: _searchController,
                placeholder: '搜索片名 / 演员 / 标签',
                onSubmitted: _onSubmitted,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            sliver: PagedSliverGrid<int, MovieListItem>(
              pagingController: _controller,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                mainAxisSpacing: AppSpacing.s,
                crossAxisSpacing: AppSpacing.s,
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
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: TextButton(
                    onPressed: () => _controller.retryLastFailedRequest(),
                    child: Text(
                      '加载失败，点击重试：${_controller.error}',
                      style: TextStyle(color: c.brand),
                    ),
                  ),
                ),
                noItemsFoundIndicatorBuilder: (_) =>
                    const EmptyView(message: '没有找到符合条件的影片'),
                firstPageProgressIndicatorBuilder: (_) => Center(
                  child: CircularProgressIndicator(color: c.brand),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
