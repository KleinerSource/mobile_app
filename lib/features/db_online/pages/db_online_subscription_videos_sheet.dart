part of 'db_online_subscriptions_page.dart';

class DbOnlineSubscriptionVideosSheet extends ConsumerStatefulWidget {
  const DbOnlineSubscriptionVideosSheet({
    super.key,
    required this.kind,
    required this.sourceId,
    required this.title,
    required this.pendingCount,
    required this.completedCount,
    required this.skippedCount,
    this.privacyId,
  });

  final String kind;
  final Object sourceId;
  final String title;
  final int? pendingCount;
  final int? completedCount;
  final int? skippedCount;
  final String? privacyId;

  @override
  ConsumerState<DbOnlineSubscriptionVideosSheet> createState() =>
      _DbOnlineSubscriptionVideosSheetState();
}

class _DbOnlineSubscriptionVideosSheetState
    extends ConsumerState<DbOnlineSubscriptionVideosSheet> {
  static const _pageSize = 24;
  static const _statuses = ['pending', 'completed', 'skipped'];

  final _searchController = TextEditingController();
  final _requests = PagedRequestCoordinator(firstPageKey: 1);
  final _pagingController = PagingController<int, DbOnlineSubscriptionItem>(
    firstPageKey: 1,
  );
  String _keyword = '';
  String _status = 'pending';
  bool _busy = false;
  late final Map<String, int?> _statusCounts = {
    'pending': widget.pendingCount,
    'completed': widget.completedCount,
    'skipped': widget.skippedCount,
  };
  bool _pagingListenerAttached = false;
  String? _pagingQueryKey;

  @override
  void dispose() {
    _requests.dispose();
    _pagingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncPagingQuery(String serverId) {
    final queryKey =
        '$serverId|${widget.kind}|${widget.sourceId}|$_status|$_keyword';
    if (_pagingQueryKey == queryKey) return;
    final hadQuery = _pagingQueryKey != null;
    _pagingQueryKey = queryKey;
    if (!_pagingListenerAttached) {
      _pagingListenerAttached = true;
      _pagingController.addPageRequestListener(_fetchPage);
      return;
    }
    if (!hadQuery) return;
    _requests.invalidate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pagingQueryKey != queryKey) return;
      _resetPaging(invalidateRequests: false);
    });
  }

  void _reloadForQuery() {
    final serverId = ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    _pagingQueryKey =
        '$serverId|${widget.kind}|${widget.sourceId}|$_status|$_keyword';
    _resetPaging();
  }

  void _resetPaging({bool invalidateRequests = true}) {
    if (!_pagingListenerAttached) return;
    if (invalidateRequests) {
      _requests.invalidate();
    }
    refreshPagedController(
      controller: _pagingController,
      requests: _requests,
      loadPage: _fetchPage,
    );
  }

  Future<void> _fetchPage(int page) async {
    final request = _requests.begin(page);
    if (request == null) return;
    try {
      final query = DbOnlineSubscriptionQuery(
        serverId: ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
        kind: widget.kind == 'actor' ? 'actor-videos' : 'series-videos',
        sourceType: widget.kind,
        sourceId: widget.sourceId,
        queueStatus: _status,
        page: page,
        limit: _pageSize,
        keyword: _keyword,
      );
      final result = await ref
          .read(dboSubscriptionRepositoryProvider)
          .list(query);
      if (!request.isCurrent || !mounted) return;
      final current =
          _pagingController.itemList ?? const <DbOnlineSubscriptionItem>[];
      final seen = <String>{for (final item in current) _itemKey(item)};
      final items = result.items
          .where((item) => seen.add(_itemKey(item)))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, page + 1);
      }
    } catch (error) {
      if (!request.isCurrent || !mounted) return;
      _pagingController.error = localizedErrorMessage(
        AppL10n.of(context),
        error,
      );
    } finally {
      request.finish();
    }
  }

  String _itemKey(DbOnlineSubscriptionItem item) {
    final videoId = item.data['video_id']?.toString().trim() ?? '';
    if (videoId.isNotEmpty) return 'video:$videoId';
    return '${item.kind}:${item.id}';
  }

  Future<void> _refreshList() {
    if (!_pagingListenerAttached) return Future<void>.value();
    return _requests.refresh(() {
      refreshPagedController(
        controller: _pagingController,
        requests: _requests,
        loadPage: _fetchPage,
      );
    });
  }

  Widget _inlineError(Object error, VoidCallback retry) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(localizedErrorMessage(l, error), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: retry, child: Text(l.dbOnlineRetry)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(mediaRuntimeConfigProvider);
    final serverId = serverConfig?.activeServerId ?? '';
    _syncPagingQuery(serverId);
    final l = AppL10n.of(context);
    final viewMode = ref.watch(
      mediaViewModePreferenceProvider(_subscriptionViewModeKey),
    );
    final privacyId =
        widget.privacyId ??
        'dbo:subscription:${widget.kind}:${widget.sourceId}';
    final revealedProvider = widget.kind == 'actor'
        ? revealedActorsProvider
        : revealedMoviesProvider;
    final hidden =
        ref.watch(privacyShieldProvider) &&
        !ref.watch(revealedProvider).contains(privacyId);
    final delegate = PagedChildBuilderDelegate<DbOnlineSubscriptionItem>(
      itemBuilder: (context, item, _) =>
          _videoCard(item, l, serverConfig, viewMode),
      firstPageProgressIndicatorBuilder: (_) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      firstPageErrorIndicatorBuilder: (_) => _inlineError(
        _pagingController.error ?? StateError(l.loadFailed),
        _pagingController.refresh,
      ),
      newPageErrorIndicatorBuilder: (_) =>
          PaginationRetry(onRetry: _pagingController.retryLastFailedRequest),
      noItemsFoundIndicatorBuilder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _keyword.isEmpty
                ? l.dbOnlineSubscriptionEmpty
                : l.dbOnlineSubscriptionNoResults,
          ),
        ),
      ),
      noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
    );
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hidden
                    ? () =>
                          ref.read(revealedProvider.notifier).reveal(privacyId)
                    : null,
                child: SheetHeader(
                  icon: widget.kind == 'actor'
                      ? Icons.person_outline_rounded
                      : Icons.layers_outlined,
                  title: hidden ? '▆▆▆▆▆' : widget.title,
                  trailing: const MediaViewModePreferenceToggle(
                    preferenceKey: _subscriptionViewModeKey,
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statuses.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    final label = switch (status) {
                      'pending' => l.dbOnlineSubscriptionPending,
                      'completed' => l.dbOnlineSubscriptionCompleted,
                      _ => l.dbOnlineSubscriptionSkipped,
                    };
                    final count = _statusCounts[status];
                    return MediaSectionTab(
                      label: count == null ? label : '$label($count)',
                      selected: _status == status,
                      onTap: () {
                        if (_status == status) return;
                        setState(() => _status = status);
                        _reloadForQuery();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  final keyword = value.trim();
                  if (_keyword == keyword) return;
                  setState(() => _keyword = keyword);
                  _reloadForQuery();
                },
                decoration: InputDecoration(
                  hintText: l.dbOnlineSubscriptionSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.dbOnlineSubscriptionCancel,
                          onPressed: () {
                            setState(() {
                              _keyword = '';
                              _searchController.clear();
                            });
                            _reloadForQuery();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshList,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MediaListLayout.horizontalInset - 18,
                          vertical: 8,
                        ),
                        sliver: viewMode == MediaViewMode.portrait
                            ? PagedSliverGrid<int, DbOnlineSubscriptionItem>(
                                pagingController: _pagingController,
                                showNoMoreItemsIndicatorAsGridChild: false,
                                gridDelegate: const MediaGridDelegate(),
                                builderDelegate: delegate,
                              )
                            : PagedSliverList<int, DbOnlineSubscriptionItem>(
                                pagingController: _pagingController,
                                builderDelegate: delegate,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoCard(
    DbOnlineSubscriptionItem item,
    AppL10n l,
    ServerConfig? serverConfig,
    MediaViewMode viewMode,
  ) {
    final menuEntries = [
      for (final status in _statuses.where(
        (value) =>
            value != item.status &&
            (value != 'skipped' || item.status == 'pending'),
      ))
        _subscriptionMenuEntry(
          status,
          _subscriptionQueueStatusLabel(status, l),
          switch (status) {
            'pending' => Icons.schedule_rounded,
            'skipped' => Icons.skip_next_rounded,
            _ => Icons.done_all_rounded,
          },
        ),
    ];
    final privacyId = _subscriptionMoviePrivacyId(item);
    final hidden =
        ref.watch(privacyShieldProvider) &&
        !ref.watch(revealedMoviesProvider).contains(privacyId);
    final card = LayoutBuilder(
      builder: (context, constraints) => GlassMenuAnchor<String>(
        width: 232,
        entries: hidden ? const [] : menuEntries,
        onSelected: (status) => _updateStatus(item, status, l),
        onAnchorTap: () => _openSubscriptionMovieDetail(context, ref, item),
        child: _subscriptionMovieTile(
          item,
          l,
          serverConfig: serverConfig,
          viewMode: viewMode,
          code: item.id,
          width: constraints.maxWidth,
        ),
      ),
    );
    return viewMode == MediaViewMode.landscape
        ? MediaLandscapeListItem(child: card)
        : card;
  }

  Future<void> _updateStatus(
    DbOnlineSubscriptionItem item,
    String status,
    AppL10n l,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dboSubscriptionRepositoryProvider)
          .api
          .updateSubscriptionVideoStatus({
            'source_type': widget.kind,
            'source_id': widget.sourceId,
            'video_code': item.id,
            'status': status,
          });
      if (!mounted) return;
      _adjustStatusCounts(item.status, status);
      await _refreshList();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.dbOnlineSubscriptionActionCompleted)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _adjustStatusCounts(String previousStatus, String nextStatus) {
    if (previousStatus == nextStatus) return;
    setState(() {
      final previousCount = _statusCounts[previousStatus];
      if (previousCount != null) {
        _statusCounts[previousStatus] = previousCount > 0
            ? previousCount - 1
            : 0;
      }
      final nextCount = _statusCounts[nextStatus];
      if (nextCount != null) _statusCounts[nextStatus] = nextCount + 1;
    });
  }
}
