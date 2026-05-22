import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/filter_chip.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../movie_detail/movie_detail_page.dart';
import 'movie_filter.dart';
import 'movies_providers.dart';

enum _ViewMode { grid, list }

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
  String _activeChip = 'All';
  _ViewMode _viewMode = _ViewMode.grid;
  int _totalCount = 0;

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
      _totalCount = page.totalCount;
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
      if (mounted) setState(() {});
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  void _applyFilter(MovieFilter newFilter, {String? chipLabel}) {
    if (chipLabel != null) {
      setState(() => _activeChip = chipLabel);
    }
    if (newFilter == _currentFilter) return;
    setState(() => _currentFilter = newFilter);
    ref.read(movieFilterProvider.notifier).state = newFilter;
    _controller.refresh();
  }

  void _onChipTap(String label) {
    switch (label) {
      case 'All':
        _applyFilter(const MovieFilter(), chipLabel: label);
        break;
      case 'Unwatched':
        // 后端尚无 unwatched 字段, 先复用默认排序 + 标记 chip
        _applyFilter(const MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
            chipLabel: label);
        break;
      case 'Rating':
        _applyFilter(const MovieFilter(sortBy: 'rating', sortOrder: 'desc'),
            chipLabel: label);
        break;
      case 'Recent':
        _applyFilter(const MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
            chipLabel: label);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = appColors(context);
    final w = MediaQuery.of(context).size.width;
    final crossAxisCount = w > 600 ? 4 : 3;

    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIBRARY', style: AppText.eyebrow(context)),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _totalCount > 0 ? '$_totalCount' : '—',
                          style: AppText.pageTitle(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'titles',
                          style: TextStyle(
                            color: c.muted,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: _SearchBar(
                  controller: _searchController,
                  onSubmitted: (v) => _applyFilter(_currentFilter.copyWith(search: v)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (ctx, i) {
                    const labels = ['All', 'Recent', 'Rating', 'Unwatched'];
                    final lab = labels[i];
                    return FilterChipPill(
                      label: lab,
                      active: _activeChip == lab,
                      onTap: () => _onChipTap(lab),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_totalCount > 0 ? _totalCount : '—'} results · sorted by ${_currentFilter.sortBy.replaceAll('_', ' ')}',
                        style: TextStyle(
                          color: c.muted,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    _ViewModeToggle(
                      mode: _viewMode,
                      onChanged: (m) => setState(() => _viewMode = m),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              sliver: _viewMode == _ViewMode.grid
                  ? PagedSliverGrid<int, MovieListItem>(
                      pagingController: _controller,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.55,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 10,
                      ),
                      builderDelegate: _buildDelegate(urlBuilder),
                    )
                  : PagedSliverList<int, MovieListItem>(
                      pagingController: _controller,
                      builderDelegate: _buildListDelegate(urlBuilder, c),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildDelegate(
    String Function(String) urlBuilder,
  ) {
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => MovieCard(
        movie: item,
        posterUrlBuilder: urlBuilder,
        onTap: () => Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: item.id)),
        ),
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? '加载失败',
        onRetry: () => _controller.refresh(),
      ),
      newPageErrorIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () => _controller.retryLastFailedRequest(),
          child: Text('加载失败，点击重试'),
        ),
      ),
      noItemsFoundIndicatorBuilder: (_) =>
          const EmptyView(message: '没有找到符合条件的影片'),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildListDelegate(
    String Function(String) urlBuilder,
    AppColors c,
  ) {
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => _ListRow(
        movie: item,
        urlBuilder: urlBuilder,
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? '加载失败',
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) =>
          const EmptyView(message: '没有找到符合条件的影片'),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search titles, people, tags',
                hintStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
              ),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    Widget btn(String label, _ViewMode m) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.text : c.muted,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [btn('Grid', _ViewMode.grid), btn('List', _ViewMode.list)],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.movie, required this.urlBuilder});
  final MovieListItem movie;
  final String Function(String) urlBuilder;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movie.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: MovieCard(
                movie: movie,
                posterUrlBuilder: urlBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
