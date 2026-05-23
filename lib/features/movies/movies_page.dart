import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/filter_chip.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/poster.dart';
import '../movie_detail/movie_detail_page.dart';
import '../privacy/privacy_mask.dart';
import 'advanced_filter_sheet.dart';
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
  String _activeChip = '全部';
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
      case '全部':
        _applyFilter(const MovieFilter(), chipLabel: label);
        break;
      case '高分':
        _applyFilter(const MovieFilter(sortBy: 'rating', sortOrder: 'desc'),
            chipLabel: label);
        break;
      case '最近':
        _applyFilter(const MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
            chipLabel: label);
        break;
    }
  }

  Future<void> _openAdvancedFilter() async {
    final next = await AdvancedFilterSheet.show(
      context,
      initial: _currentFilter,
    );
    if (next != null && next != _currentFilter) {
      _applyFilter(next);
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
                    Text(AppL10n.of(context).libraryTitle.toUpperCase(),
                        style: AppText.eyebrow(context)),
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
                          AppL10n.of(context).libraryCountSuffix,
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
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (ctx, i) {
                    const labels = ['全部', '最近', '高分'];
                    final lab = labels[i];
                    final l = AppL10n.of(context);
                    final display = switch (lab) {
                      '全部' => l.filterAll,
                      '最近' => l.filterRecent,
                      '高分' => l.filterTopRated,
                      _ => lab,
                    };
                    return FilterChipPill(
                      label: display,
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
                        AppL10n.of(context).resultsSortedBy(
                          _totalCount > 0 ? _totalCount : 0,
                          _sortLabel(context, _currentFilter.sortBy),
                        ),
                        style: TextStyle(
                          color: c.muted,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    _FilterButton(
                      activeCount: _currentFilter.activeAdvancedCount,
                      onTap: _openAdvancedFilter,
                    ),
                    const SizedBox(width: 8),
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
                      builderDelegate: _buildListDelegate(urlBuilder),
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
    final l = AppL10n.of(context);
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => MovieCard(
        movie: item,
        posterUrlBuilder: urlBuilder,
        onTap: () => Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: item.id)),
        ),
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? l.loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      newPageErrorIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () => _controller.retryLastFailedRequest(),
          child: Text(l.loadFailedRetry),
        ),
      ),
      noItemsFoundIndicatorBuilder: (_) =>
          EmptyView(message: l.noResultFound),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }

  PagedChildBuilderDelegate<MovieListItem> _buildListDelegate(
    String Function(String) urlBuilder,
  ) {
    final l = AppL10n.of(context);
    return PagedChildBuilderDelegate<MovieListItem>(
      itemBuilder: (ctx, item, idx) => _ListRow(
        movie: item,
        urlBuilder: urlBuilder,
      ),
      firstPageErrorIndicatorBuilder: (_) => ErrorView(
        message: _controller.error?.toString() ?? l.loadFailed,
        onRetry: () => _controller.refresh(),
      ),
      noItemsFoundIndicatorBuilder: (_) =>
          EmptyView(message: l.noResultFound),
      firstPageProgressIndicatorBuilder: (_) =>
          const Center(child: CupertinoActivityIndicator()),
    );
  }
}

String _sortLabel(BuildContext context, String key) {
  final l = AppL10n.of(context);
  switch (key) {
    case 'rating':
      return l.sortByRating;
    case 'title':
      return l.sortByTitle;
    case 'year':
      return l.sortByYear;
    case 'release_date':
      return l.sortByReleaseDate;
    case 'created_at':
    default:
      return l.sortByCreatedAt;
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
                hintText: AppL10n.of(context).searchHintAll,
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
    Widget btn(IconData icon, _ViewMode m) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Icon(icon, size: 15, color: active ? c.text : c.muted),
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
        children: [
          btn(Icons.grid_view_rounded, _ViewMode.grid),
          btn(Icons.view_list_rounded, _ViewMode.list),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final active = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.accent.withValues(alpha: 0.5) : c.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: active ? c.accent : c.muted,
            ),
            if (active) ...[
              const SizedBox(width: 5),
              Text(
                '$activeCount',
                style: TextStyle(
                  color: c.accent,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
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
    final progress = (movie.watchRecord?.progressRatio ?? 0).clamp(0.0, 1.0);
    final completed = movie.watchRecord?.completed ?? false;
    final hasRating = movie.rating != null && movie.rating! > 0;
    final meta = <String>[
      if (movie.year != null) '${movie.year}',
      if (movie.runtime != null && movie.runtime! > 0) '${movie.runtime}m',
      if (hasRating) '★ ${movie.rating!.toStringAsFixed(1)}',
    ].join(' · ');

    return PrivacyAwareInkWell(
      movieId: movie.id,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movie.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: PrivacyMask(
                movieId: movie.id,
                radius: 8,
                child: Poster(
                  url: movie.posterUuid != null
                      ? urlBuilder(movie.posterUuid!)
                      : null,
                  title: movie.title,
                  year: movie.year,
                  radius: 8,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrivacyText(
                    movieId: movie.id,
                    text: movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(meta, style: AppText.meta(context)),
                  ],
                  if (!completed && progress > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: c.chipBg,
                              valueColor: AlwaysStoppedAnimation(c.accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: c.muted,
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  AppL10n.of(context).watchedDone,
                  style: TextStyle(
                    color: c.accent,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right, color: c.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
