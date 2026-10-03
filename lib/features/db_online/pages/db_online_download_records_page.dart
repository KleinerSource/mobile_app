import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_download_record_providers.dart';
import 'package:omm/features/db_online/providers/db_online_following_providers.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_download_record_filter_sheet.dart';
import 'package:omm/features/db_online/widgets/db_online_download_record_widgets.dart';
import 'package:omm/features/db_online/widgets/db_online_following_widgets.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_download.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/catalog_search_field.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/shared/pagination_footer.dart';

class DbOnlineDownloadRecordsPage extends ConsumerWidget {
  const DbOnlineDownloadRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId =
        ref.watch(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final route = ModalRoute.of(context);
    ref.listen(
      mediaRuntimeConfigProvider.select((config) => config?.activeServerId),
      (previous, next) {
        if (previous == next || route == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && route.isActive) {
            Navigator.of(context).popUntil((candidate) => candidate == route);
          }
        });
      },
    );
    return _DownloadRecordsPage(key: ValueKey(serverId), serverId: serverId);
  }
}

class _DownloadRecordsPage extends ConsumerStatefulWidget {
  const _DownloadRecordsPage({super.key, required this.serverId});
  final String serverId;

  @override
  ConsumerState<_DownloadRecordsPage> createState() => _RecordsState();
}

class _RecordsState extends ConsumerState<_DownloadRecordsPage> {
  final _paging = PagingController<int, DbOnlineDownloadRecord>(
    firstPageKey: 0,
  );
  final _requests = PagedRequestCoordinator();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _expanded = <int>{};
  DbOnlineDownloadRecordFilter _filter = DbOnlineDownloadRecordFilter.today();
  int _total = 0;
  int _filtered = 0;
  int? _pushing;

  bool get _current =>
      mounted &&
      ref.read(mediaRuntimeConfigProvider)?.activeServerId == widget.serverId;

  @override
  void initState() {
    super.initState();
    _paging.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _requests.dispose();
    _paging.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    if (!_current) return;
    final request = _requests.begin(offset);
    if (request == null) return;
    final filter = _filter;
    final l = AppL10n.of(context);
    try {
      final result = await ref
          .read(dbOnlineDownloadRecordApiProvider(widget.serverId))
          .list(filter, offset: offset);
      if (!_current || !request.isCurrent) return;
      final seen = {
        for (final item in _paging.itemList ?? <DbOnlineDownloadRecord>[])
          item.id,
      };
      final records = result.records
          .where((item) => seen.add(item.id))
          .toList();
      setState(() {
        _total = result.totalCount;
        _filtered = result.filteredCount;
      });
      if (!result.hasMore || result.records.isEmpty) {
        _paging.appendLastPage(records);
      } else {
        // 去重只影响展示，偏移量必须使用服务端返回条数。
        _paging.appendPage(records, offset + result.records.length);
      }
    } catch (error) {
      if (_current && request.isCurrent) {
        _paging.error = localizedErrorMessage(l, error);
      }
    } finally {
      request.finish();
    }
  }

  Future<void> _refresh() {
    if (!_current) return Future.value();
    return _requests.refresh(() {
      _expanded.clear();
      _paging.refresh();
      unawaited(_fetch(0));
    });
  }

  Future<void> _reload() async {
    if (!_current) return;
    final l = AppL10n.of(context);
    final capability = dbOnlineSubscriptionCapabilitiesProvider(
      widget.serverId,
    );
    ref.invalidate(capability);
    try {
      final capabilities = await ref.read(capability.future);
      if (!_current || !capabilities.database) return;
      ref.invalidate(dbOnlineRecordDownloadersProvider(widget.serverId));
      ref.invalidate(dbOnlineFollowingStylesProvider(widget.serverId));
      await _refresh();
    } catch (error) {
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l, error))),
        );
      }
    }
  }

  void _apply(DbOnlineDownloadRecordFilter filter) {
    if (!_current || mapEquals(filter.toQuery(), _filter.toQuery())) return;
    setState(() {
      _filter = filter;
      _total = 0;
      _filtered = 0;
    });
    _requests.invalidate();
    _expanded.clear();
    _paging.refresh();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_fetch(0));
  }

  Future<void> _filters(List<DbOnlineRecordDownloader> downloaders) async {
    final labels = {
      for (final downloader in downloaders)
        downloader.name: downloader.displayName,
      for (final record in _paging.itemList ?? <DbOnlineDownloadRecord>[])
        if (record.downloader.isNotEmpty &&
            !downloaders.any((item) => item.name == record.downloader))
          record.downloader: record.downloader,
    };
    if (_filter.downloader.isNotEmpty) {
      labels.putIfAbsent(_filter.downloader, () => _filter.downloader);
    }
    final filter = await showGlassSheet<DbOnlineDownloadRecordFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DbOnlineDownloadRecordFilterSheet(
        filter: _filter,
        downloaders: [
          for (final entry in labels.entries)
            (value: entry.key, label: entry.value),
        ],
        isCurrent: () => _current,
      ),
    );
    if (filter != null && _current) _apply(filter);
  }

  Future<void> _repush(
    DbOnlineDownloadRecord record,
    List<DbOnlineRecordDownloader> downloaders,
  ) async {
    if (!_current || _pushing != null) return;
    final l = AppL10n.of(context);
    var submitted = false;
    final success = await pushDbOnlineResource(
      context: context,
      repository: ref.read(dboMediaRepositoryProvider),
      downloaders: downloaders.map((item) => item.option).toList(),
      downloaderQuotas: {
        for (final item in downloaders)
          if (item.name == 'pan115' && item.availableQuota != null)
            item.name: item.availableQuota!,
      },
      videoInfo: record.videoInfo,
      url: record.resourceUrl,
      protocol: record.resourceProtocol,
      name: record.resourceName,
      tags: record.resourceTypes,
      recordResource: record.recordResource,
      isCurrent: () => _current,
      onPushing: (value) => setState(() => _pushing = value ? record.id : null),
      onSubmitted: () => submitted = true,
      successMessage: l.dbOnlineDownloadRecordsRepushedTo,
    );
    if (!_current || !submitted) return;
    // 服务端在推送失败时也会更新原记录，完成后统一重新查询。
    if (success) {
      ref.invalidate(dbOnlineRecordDownloadersProvider(widget.serverId));
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    final capabilities = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(widget.serverId),
    );
    final database = capabilities.asData?.value.database == true;
    final downloaderState = database
        ? ref.watch(dbOnlineRecordDownloadersProvider(widget.serverId))
        : const AsyncData<List<DbOnlineRecordDownloader>>([]);
    final downloaders = downloaderState.asData?.value ?? [];
    final styles = database
        ? ref
                  .watch(dbOnlineFollowingStylesProvider(widget.serverId))
                  .asData
                  ?.value ??
              []
        : const [];
    final labels = {
      for (final item in downloaders) item.name: item.displayName,
    };

    return DbOnlineFollowingLayout(
      title: l.dbOnlineDownloadRecordsTitle,
      scrollController: _scroll,
      actions: [
        DbOnlineFollowingActionIcon(
          icon: Icons.refresh_rounded,
          tooltip: l.mediaBrowserRefresh,
          onPressed: () => unawaited(_reload()),
        ),
        DbOnlineFollowingActionIcon(
          icon: Icons.tune_rounded,
          tooltip: l.dbOnlineDownloadRecordsFilters,
          onPressed: database ? () => unawaited(_filters(downloaders)) : null,
        ),
      ],
      filters: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CatalogSearchField(
              controller: _search,
              hintText: l.dbOnlineDownloadRecordsSearch,
              onSubmitted: (value) {
                if (database) _apply(_filter.copyWith(keyword: value.trim()));
              },
              onCleared: () {
                if (database) _apply(_filter.copyWith(keyword: ''));
              },
            ),
            if (database) ...[
              const SizedBox(height: 8),
              Text(l.dbOnlineDownloadRecordsStats(_total, _filtered)),
            ],
            if (downloaderState.hasError)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizedErrorMessage(l, downloaderState.error!),
                    ),
                  ),
                  IconButton(
                    tooltip: l.commonRetry,
                    onPressed: () => ref.invalidate(
                      dbOnlineRecordDownloadersProvider(widget.serverId),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
          ],
        ),
      ),
      body: capabilities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: localizedErrorMessage(l, error),
          onRetry: () => unawaited(_reload()),
        ),
        data: (value) => !value.database
            ? EmptyView(message: l.dbOnlineDownloadRecordsRequiresDatabase)
            : RefreshIndicator(
                onRefresh: _refresh,
                child: PagedListView<int, DbOnlineDownloadRecord>.separated(
                  pagingController: _paging,
                  scrollController: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  builderDelegate:
                      PagedChildBuilderDelegate<DbOnlineDownloadRecord>(
                        itemBuilder: (context, record, _) =>
                            DbOnlineDownloadRecordCard(
                              key: ValueKey(record.id),
                              record: record,
                              serverId: widget.serverId,
                              config: config,
                              styles: {
                                for (final style in styles)
                                  style.id: style.name,
                              },
                              downloaderLabel:
                                  labels[record.downloader] ??
                                  (record.downloader.isEmpty
                                      ? l.dbOnlineDownloadRecordsNoDownloader
                                      : record.downloader),
                              expanded: _expanded.contains(record.id),
                              pushing: _pushing == record.id,
                              onToggle: () => setState(() {
                                if (!_expanded.remove(record.id)) {
                                  _expanded.add(record.id);
                                }
                              }),
                              onOpen:
                                  record.videoCode.isEmpty &&
                                      record.videoId.isEmpty
                                  ? null
                                  : () => openDbOnlineMovieUnawaited(
                                      context,
                                      DbOnlineMovie(
                                        id: record.videoId,
                                        number: record.videoCode,
                                        title: record.videoTitle,
                                      ),
                                    ),
                              onRepush:
                                  _pushing != null ||
                                      downloaderState.isLoading ||
                                      record.resourceUrl.isEmpty ||
                                      !downloaders.any(
                                        (item) =>
                                            record.resourceProtocol != 'ed2k' ||
                                            item.ed2kEnabled,
                                      )
                                  ? null
                                  : () =>
                                        unawaited(_repush(record, downloaders)),
                            ),
                        firstPageProgressIndicatorBuilder: (_) =>
                            const Center(child: CircularProgressIndicator()),
                        firstPageErrorIndicatorBuilder: (_) => ErrorView(
                          message: _paging.error.toString(),
                          onRetry: _paging.retryLastFailedRequest,
                        ),
                        newPageErrorIndicatorBuilder: (_) => PaginationRetry(
                          onRetry: _paging.retryLastFailedRequest,
                        ),
                        noItemsFoundIndicatorBuilder: (_) =>
                            EmptyView(message: l.dbOnlineDownloadRecordsEmpty),
                        noMoreItemsIndicatorBuilder: (_) =>
                            const NoMoreContent(),
                      ),
                ),
              ),
      ),
    );
  }
}
