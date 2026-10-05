import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/movies/omm_movie_paged_sliver.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
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
  final _requests = PagedRequestCoordinator();
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
    _requests.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    final pageRequest = _requests.begin(offset);
    if (pageRequest == null) return;
    final l = AppL10n.of(context);
    try {
      final repo = ref.read(mediaRepositoryProvider);
      final page = await repo.list(_filter, limit: _pageSize, offset: offset);
      if (!pageRequest.isCurrent) return;
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
      if (!pageRequest.isCurrent) return;
      _controller.error = localizedErrorMessage(l, e);
    } finally {
      pageRequest.finish();
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
    if (now.changedSince(changesBeforeVisit)) {
      await _refreshAfterMovie();
    }
  }

  Future<void> _refreshAfterMovie() async {
    final refreshed = await refreshPagedListInBackground<MovieListItem>(
      controller: _controller,
      requests: _requests,
      onApplied: (page) => _totalCount = page.totalCount,
      loadPage: (limit, offset) async {
        final page = await ref
            .read(mediaRepositoryProvider)
            .list(_filter, limit: limit, offset: offset);
        return page;
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final urlBuilder = ref.watch(imageUrlBuilderProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: StatusBarScrollToTop(
          // 列表持自有控制器（分页位置恢复），由此接入状态栏点击回顶。
          scrollController: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  widget.resource.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: Center(
                  child: HeaderActionButton(
                    icon: Icons.arrow_back,
                    tooltip: l.back,
                    style: HeaderActionStyle.overlay,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
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
                padding: MediaListLayout.contentPadding.copyWith(bottom: 80),
                sliver: OmmMoviePagedSliver(
                  controller: _controller,
                  urlBuilder: urlBuilder,
                  onOpenMovie: (m) => unawaited(_openMovie(m.id)),
                  emptyMessage: l.resourceMoviesEmpty,
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
  const _Hero({required this.kind, required this.item, this.overrideCount});
  final ResourceKind kind;
  final ResourceItem item;
  final int? overrideCount;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
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
              padding: const EdgeInsets.fromLTRB(
                22,
                56,
                22,
                PageHeader.aboveListGap,
              ),
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
                  const SizedBox(height: 6),
                  Text(
                    l.resourceMovieCount(overrideCount ?? item.movieCount),
                    maxLines: 1,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
