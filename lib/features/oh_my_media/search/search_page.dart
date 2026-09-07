import 'package:omm/shared/preview/auto_preview_controller.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/actor.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/actor_avatar.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/debouncer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/search_type_menu.dart';
import 'package:omm/shared/preview/preview_player.dart';
import 'package:omm/shared/preview/preview_visibility.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/movies/omm_movie_preview_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _viewModeKey = 'omm.search.view_mode.v1';
  final _controller = TextEditingController();
  final _debounce = Debouncer();
  String _query = '';
  MovieSearchType _searchType = MovieSearchType.title;
  MediaViewMode _viewMode = MediaViewMode.portrait;
  List<ActorItem> _actorSuggestions = const [];
  String? _actorSearchError;
  bool _actorSearchLoading = false;
  int _actorRequestId = 0;
  int? _selectedActorId;

  @override
  void initState() {
    super.initState();
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    final query = v.trim();
    final requestId = ++_actorRequestId;
    if (_searchType == MovieSearchType.actor) {
      setState(() {
        _query = query;
        _selectedActorId = null;
        _actorSuggestions = const [];
        _actorSearchError = null;
        _actorSearchLoading = query.isNotEmpty;
      });
      _debounce.run(() {
        if (!mounted ||
            requestId != _actorRequestId ||
            _searchType != MovieSearchType.actor ||
            query.isEmpty) {
          return;
        }
        unawaited(_searchActors(query, requestId));
      });
      return;
    }

    _debounce.run(() {
      if (mounted) {
        setState(() {
          _query = query;
          _selectedActorId = null;
          _actorSuggestions = const [];
          _actorSearchError = null;
          _actorSearchLoading = false;
        });
      }
    });
  }

  void _onSearchTypeChanged(MovieSearchType type) {
    _debounce.cancel();
    final query = _controller.text.trim();
    final requestId = ++_actorRequestId;
    setState(() {
      _searchType = type;
      _query = query;
      _selectedActorId = null;
      _actorSuggestions = const [];
      _actorSearchError = null;
      _actorSearchLoading = type == MovieSearchType.actor && query.isNotEmpty;
    });
    if (type == MovieSearchType.actor && query.isNotEmpty) {
      _debounce.run(() {
        if (!mounted ||
            requestId != _actorRequestId ||
            _searchType != MovieSearchType.actor) {
          return;
        }
        unawaited(_searchActors(query, requestId));
      });
    }
  }

  Future<void> _searchActors(String query, int requestId) async {
    try {
      final source = ref.read(ommMediaSourceProvider);
      if (source == null) throw StateError('当前服务器不是 OMM');
      final raw = await source.metadataOperations.searchActors({
        'search': query,
        'limit': 8,
        'offset': 0,
      });
      final result = unwrapOptions<ActorItem>(
        raw,
        (data) => ActorItem.fromJson(data),
      );
      if (!mounted ||
          requestId != _actorRequestId ||
          _searchType != MovieSearchType.actor ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() {
        _actorSuggestions = result.items;
        _actorSearchError = null;
        _actorSearchLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _actorRequestId) return;
      setState(() {
        _actorSuggestions = const [];
        _actorSearchError = toApiException(error).message;
        _actorSearchLoading = false;
      });
    }
  }

  void _submitSearch(String value) {
    if (_searchType != MovieSearchType.actor) return;
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce.cancel();
    final requestId = ++_actorRequestId;
    setState(() {
      _query = query;
      _selectedActorId = null;
      _actorSuggestions = const [];
      _actorSearchError = null;
      _actorSearchLoading = true;
    });
    unawaited(_searchActors(query, requestId));
  }

  void _selectActor(ActorItem actor) {
    _debounce.cancel();
    ++_actorRequestId;
    setState(() {
      _selectedActorId = actor.id;
      _actorSuggestions = const [];
      _actorSearchError = null;
      _actorSearchLoading = false;
    });
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref
        .read(sharedPrefsProvider)
        .setString(
          _viewModeKey,
          mode == MediaViewMode.portrait ? 'grid' : mode.name,
        );
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  MediaViewModeToggle(
                    mode: _viewMode,
                    onChanged: (mode) => unawaited(_setViewMode(mode)),
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
                      onChanged: _onSearchTypeChanged,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textAlignVertical: TextAlignVertical.center,
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
                        onSubmitted: _submitSearch,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: c.muted),
                        onPressed: () {
                          _debounce.cancel();
                          ++_actorRequestId;
                          _controller.clear();
                          setState(() {
                            _query = '';
                            _selectedActorId = null;
                            _actorSuggestions = const [];
                            _actorSearchError = null;
                            _actorSearchLoading = false;
                          });
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
                  : _searchType == MovieSearchType.actor &&
                        _selectedActorId == null
                  ? _ActorSuggestions(
                      actors: _actorSuggestions,
                      loading: _actorSearchLoading,
                      error: _actorSearchError,
                      onSelected: _selectActor,
                      onRetry: () {
                        final query = _controller.text.trim();
                        if (query.isEmpty) return;
                        final requestId = ++_actorRequestId;
                        setState(() => _actorSearchLoading = true);
                        unawaited(_searchActors(query, requestId));
                      },
                    )
                  : _SearchResults(
                      key: ValueKey(
                        '${_searchType.queryValue}:$_query:$_selectedActorId',
                      ),
                      query: _query,
                      searchType: _searchType,
                      actorId: _selectedActorId,
                      viewMode: _viewMode,
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
    return CenteredEmptyState(
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

class _ActorSuggestions extends StatelessWidget {
  const _ActorSuggestions({
    required this.actors,
    required this.loading,
    required this.error,
    required this.onSelected,
    required this.onRetry,
  });

  final List<ActorItem> actors;
  final bool loading;
  final String? error;
  final ValueChanged<ActorItem> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ErrorView(message: error!, onRetry: onRetry);
    }
    if (actors.isEmpty) {
      return EmptyView(message: AppL10n.of(context).searchNoResult);
    }

    final c = appColors(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
      itemCount: actors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final actor = actors[index];
        return Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelected(actor),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  ActorAvatar(
                    actorId: actor.id,
                    name: actor.name,
                    hue: AppHues.all[index % AppHues.all.length],
                    size: 40,
                    avatarPaths: actor.avatarPaths,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      actor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerStatefulWidget {
  const _SearchResults({
    super.key,
    required this.query,
    required this.searchType,
    this.actorId,
    required this.viewMode,
  });
  final String query;
  final MovieSearchType searchType;
  final int? actorId;
  final MediaViewMode viewMode;

  @override
  ConsumerState<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<_SearchResults> {
  static const _pageSize = 60;

  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final _scrollRestorer = PagedScrollPositionRestorer<MovieListItem>(
    _controller,
  );
  late final _autoPreview = AutoPreviewController<int>(
    candidate: _nextAutoPreviewId,
  )..addListener(_onAutoPreviewChanged);
  int? get _autoPreviewId => _autoPreview.value;

  void _onAutoPreviewChanged() {
    if (mounted) setState(() {});
  }

  final _previewViewportKey = GlobalKey();
  final _previewItemKeys = <int, GlobalKey>{};
  final _previewCoordinator = PreviewCoordinator();

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
    _scrollController.addListener(_scheduleAutoPreviewUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAutoPreviewUpdate();
    });
  }

  @override
  void didUpdateWidget(covariant _SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode) {
      _scheduleAutoPreviewUpdate();
    }
  }

  @override
  void dispose() {
    _autoPreview.dispose();
    _requests.dispose();
    _controller.dispose();
    _scrollController.removeListener(_scheduleAutoPreviewUpdate);
    _scrollController.dispose();
    _previewCoordinator.dispose();
    super.dispose();
  }

  void _scheduleAutoPreviewUpdate() => _autoPreview.schedule();

  MovieFilter get _movieFilter => MovieFilter(
    search: widget.actorId == null ? widget.query : null,
    searchType: widget.actorId == null
        ? widget.searchType
        : MovieSearchType.title,
    actorIds: widget.actorId == null ? const [] : [widget.actorId!],
    sortBy: 'created_at',
    sortOrder: 'desc',
  );

  int? _nextAutoPreviewId() {
    if (widget.viewMode != MediaViewMode.landscape) return null;
    final items = _controller.itemList ?? const <MovieListItem>[];
    if (items.isEmpty) return null;
    final width = (MediaQuery.sizeOf(context).width - 44).clamp(
      1.0,
      double.infinity,
    );
    final coverHeight = width * 9 / 16;
    final actualIndex = previewItemIndexForViewportKeys(
      itemKeys: items.map((item) => _previewItemKeys[item.id]),
      viewportKey: _previewViewportKey,
      coverHeight: coverHeight,
    );
    final index =
        actualIndex ??
        previewItemIndexForScroll(
          scrollOffset: _scrollController.hasClients
              ? _scrollController.offset
              : 0,
          cardHeight: coverHeight,
          itemGap: 14,
          itemCount: items.length,
          leadingPadding: 4,
        );
    return index == null ? null : items[index].id;
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
      requests: _requests,
      loadFirstPage: (limit) => ref
          .read(mediaRepositoryProvider)
          .list(_movieFilter, limit: limit, offset: 0),
    );
  }

  Future<void> _fetch(int offset) async {
    final pageRequest = _requests.begin(offset);
    if (pageRequest == null) return;
    try {
      final page = await ref
          .read(mediaRepositoryProvider)
          .list(_movieFilter, limit: _pageSize, offset: offset);
      if (!pageRequest.isCurrent) return;
      if (!mounted) return;

      applyPagedListPage(
        controller: _controller,
        offset: offset,
        items: page.items,
        totalCount: page.totalCount,
        restorer: _scrollRestorer,
        scrollController: _scrollController,
      );
      _scheduleAutoPreviewUpdate();
    } catch (error) {
      if (!pageRequest.isCurrent) return;
      if (!mounted) return;
      _controller.error = toApiException(error).message;
    } finally {
      pageRequest.finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final isPortrait = widget.viewMode == MediaViewMode.portrait;
    final isLandscape = widget.viewMode == MediaViewMode.landscape;
    return CustomScrollView(
      key: _previewViewportKey,
      controller: _scrollController,
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          sliver: isPortrait
              ? PagedSliverGrid<int, MovieListItem>(
                  pagingController: _controller,
                  showNoMoreItemsIndicatorAsGridChild: false,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: MediaCardTemplate.gridChildAspectRatio,
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
                      message:
                          _controller.error?.toString() ??
                          AppL10n.of(context).loadFailed,
                      onRetry: _controller.refresh,
                    ),
                    newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                      onRetry: _controller.retryLastFailedRequest,
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        EmptyView(message: AppL10n.of(context).searchNoResult),
                    noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                  ),
                )
              : PagedSliverList<int, MovieListItem>(
                  pagingController: _controller,
                  builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                    itemBuilder: (ctx, movie, _) => isLandscape
                        ? OmmMoviePreviewCard(
                            key: _previewItemKeys.putIfAbsent(
                              movie.id,
                              GlobalKey.new,
                            ),
                            movie: movie,
                            posterUrlBuilder: urlBuilder,
                            coordinator: _previewCoordinator,
                            autoPlayPreview: movie.id == _autoPreviewId,
                            onTap: () => unawaited(_openMovie(movie.id)),
                          )
                        : CatalogListMovieCard(
                            key: ValueKey(movie.id),
                            title: movie.title,
                            imageUrl: movie.posterUuid == null
                                ? null
                                : urlBuilder(movie.posterUuid!),
                            meta: formatMediaCardMeta(
                              AppL10n.of(context),
                              year: movie.year,
                              duration: movie.runtime,
                            ),
                            privacyId: movie.id,
                            onTap: () => unawaited(_openMovie(movie.id)),
                          ),
                    firstPageProgressIndicatorBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    firstPageErrorIndicatorBuilder: (_) => ErrorView(
                      message:
                          _controller.error?.toString() ??
                          AppL10n.of(context).loadFailed,
                      onRetry: _controller.refresh,
                    ),
                    newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                      onRetry: _controller.retryLastFailedRequest,
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        EmptyView(message: AppL10n.of(context).searchNoResult),
                    noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
                  ),
                ),
        ),
      ],
    );
  }
}
