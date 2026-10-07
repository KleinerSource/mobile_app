import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/core/sources/media/dbo/db_online_resource_merge.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';
import 'package:omm/features/db_online/providers/db_online_following_providers.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_following_widgets.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_download.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_sheets.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/pagination_footer.dart';

class DbOnlineReviewResourcesPage extends ConsumerStatefulWidget {
  const DbOnlineReviewResourcesPage({
    super.key,
    required this.serverId,
    required this.userId,
    this.username = '',
    this.latest = false,
  });
  final String serverId;
  final String userId;
  final String username;
  final bool latest;

  @override
  ConsumerState<DbOnlineReviewResourcesPage> createState() =>
      _ReviewResourcesState();
}

class _ReviewResourcesState extends ConsumerState<DbOnlineReviewResourcesPage> {
  final _scroll = ScrollController();
  final List<DbOnlineReviewResourceItem> _items = [];
  final Map<String, ({Map<String, String> magnets, Map<String, String> ed2ks})>
  _history = {};
  final Set<String> _historyLoading = {};
  List<DbOnlineDownloader> _downloaders = [];
  final Set<int> _metadataLoading = {};
  int _session = 0;
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _downloadersLoading = true;
  String _resolvedUsername = '';
  String? _error;
  String? _metadataError;
  String? _pushing;

  bool get _current =>
      mounted && isDbOnlineFollowingServer(ref, widget.serverId);
  bool _currentSession(int session) => _current && session == _session;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant DbOnlineReviewResourcesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverId != widget.serverId ||
        oldWidget.userId != widget.userId ||
        oldWidget.latest != widget.latest) {
      unawaited(_start());
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _session++;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() {
    _session++;
    _items.clear();
    _history.clear();
    _historyLoading.clear();
    _metadataLoading.clear();
    _downloaders = [];
    _downloadersLoading = true;
    _resolvedUsername = widget.username;
    _page = 1;
    _loading = false;
    _hasMore = true;
    _error = null;
    _metadataError = null;
    _pushing = null;
    unawaited(_loadDownloaders(_session));
    return _loadNext();
  }

  void _onScroll() {
    if (!widget.latest &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 400 &&
        _error == null) {
      unawaited(_loadNext());
    }
  }

  Future<void> _refresh() => _start();

  Future<void> _loadNext() async {
    if (!_current || _loading || !_hasMore) return;
    final session = _session;
    final page = _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final capabilities = await ref.read(
        dbOnlineSubscriptionCapabilitiesProvider(widget.serverId).future,
      );
      if (!_currentSession(session)) return;
      if (!capabilities.onlineQuery) {
        setState(() => _hasMore = false);
        return;
      }
      final result = await ref
          .read(dbOnlineFollowingApiProvider(widget.serverId))
          .resources(
            userId: widget.userId,
            username: _resolvedUsername,
            latest: widget.latest,
            page: page,
          );
      if (!_currentSession(session)) return;
      final seen = _items.map((item) => item.reviewId).toSet();
      final added = result.items
          .where((item) => seen.add(item.reviewId))
          .toList();
      setState(() {
        _items.addAll(added);
        if (result.username.isNotEmpty) _resolvedUsername = result.username;
        _page = (result.page >= page ? result.page : page) + 1;
        _hasMore = result.hasNext;
      });
      unawaited(_enrich(added, session));
      if (capabilities.database) {
        for (final code in added.map((item) => item.movie.number).toSet()) {
          unawaited(_loadHistory(code, session));
        }
      }
    } catch (error) {
      if (_currentSession(session)) {
        setState(
          () => _error = localizedErrorMessage(AppL10n.of(context), error),
        );
      }
    } finally {
      if (_currentSession(session)) {
        setState(() => _loading = false);
        // 最新评论的 page 表示服务端已经扫描到的页码，继续逐批累积。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_currentSession(session) &&
              _hasMore &&
              _error == null &&
              (widget.latest ||
                  _scroll.hasClients && _scroll.position.extentAfter < 400)) {
            unawaited(_loadNext());
          }
        });
      }
    }
  }

  Future<void> _enrich(
    List<DbOnlineReviewResourceItem> items,
    int session,
  ) async {
    final l = AppL10n.of(context);
    final pending = items
        .where(
          (item) =>
              item.magnetPayload.isNotEmpty &&
              !_metadataLoading.contains(item.reviewId),
        )
        .toList();
    if (pending.isEmpty || !_currentSession(session)) return;
    setState(
      () => _metadataLoading.addAll(pending.map((item) => item.reviewId)),
    );
    try {
      final metadata = await ref
          .read(dbOnlineFollowingApiProvider(widget.serverId))
          .resourceMetadata(pending);
      if (!_currentSession(session)) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final magnets = metadata[_items[i].reviewId];
          if (magnets != null) _items[i] = _items[i].withMagnets(magnets);
        }
        _metadataError = null;
      });
    } catch (error) {
      if (_currentSession(session)) {
        setState(() => _metadataError = localizedErrorMessage(l, error));
      }
    } finally {
      if (_currentSession(session)) {
        setState(
          () =>
              _metadataLoading.removeAll(pending.map((item) => item.reviewId)),
        );
      }
    }
  }

  Future<void> _loadDownloaders(int session) async {
    try {
      final capabilities = await ref.read(
        dbOnlineSubscriptionCapabilitiesProvider(widget.serverId).future,
      );
      if (!_currentSession(session) || !capabilities.onlineQuery) return;
      final downloaders = await ref
          .read(dboMediaRepositoryProvider)
          .getDownloaders();
      if (_currentSession(session)) setState(() => _downloaders = downloaders);
    } catch (_) {
      // 下载器不可用时仍允许查看、复制资源。
    } finally {
      if (_currentSession(session)) setState(() => _downloadersLoading = false);
    }
  }

  Future<void> _loadHistory(
    String code,
    int session, {
    bool refresh = false,
  }) async {
    if (code.isEmpty ||
        _historyLoading.contains(code) ||
        !refresh && _history.containsKey(code)) {
      return;
    }
    _historyLoading.add(code);
    try {
      final history = await ref
          .read(dboMediaRepositoryProvider)
          .getDownloadHistory(code);
      if (_currentSession(session)) setState(() => _history[code] = history);
    } catch (_) {
      // 历史记录不可用不阻塞资源查询。
    } finally {
      if (_currentSession(session)) _historyLoading.remove(code);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted && _current) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).resourceCopied)),
      );
    }
  }

  Future<void> _push(
    DbOnlineReviewResourceItem item, {
    required String url,
    required String name,
    required String protocol,
    required List<String> tags,
    String? site,
    String? date,
  }) async {
    if (_pushing != null || !_current) return;
    final session = _session;
    final pushed = await pushDbOnlineResource(
      context: context,
      repository: ref.read(dboMediaRepositoryProvider),
      downloaders: _downloaders,
      videoInfo: {
        'code': item.movie.number,
        'title': item.movie.title,
        'date': item.movie.releaseDate ?? '',
        'actors': <Map<String, dynamic>>[],
      },
      url: url,
      protocol: protocol,
      name: name,
      tags: tags,
      site: site,
      date: date,
      isCurrent: () => _currentSession(session),
      onPushing: (pushing) => setState(() => _pushing = pushing ? url : null),
    );
    if (pushed && _currentSession(session)) {
      await _loadHistory(item.movie.number, session, refresh: true);
    }
  }

  Widget _item(DbOnlineReviewResourceItem item) {
    final l = AppL10n.of(context);
    final history = _history[item.movie.number];
    final disabled =
        _pushing != null || _downloadersLoading || _downloaders.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: MediaListLayout.mainAxisSpacing),
      child: GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DbOnlineMovieCard(
                movie: item.movie,
                config: ref.watch(mediaRuntimeConfigProvider),
                compact: true,
                subscriptionActionsEnabled: true,
                listTitleMaxLines: 3,
                showRating: false,
                width: double.infinity,
                onTap: () => openDbOnlineMovieUnawaited(context, item.movie),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Row(
                  children: [
                    Text(
                      formatDbOnlineFollowingDate(item.createdAt),
                      style: AppText.meta(context),
                    ),
                    const Spacer(),
                    if (_metadataLoading.contains(item.reviewId))
                      Tooltip(
                        message: l.dbOnlineFollowingMetadataLoading,
                        child: const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
              for (final magnet in item.magnets)
                DbOnlineResourceRow(
                  name: magnet.name,
                  value: magnet.magnet,
                  tags: magnet.tags,
                  sizeMb: magnet.sizeMb,
                  fileCount: magnet.fileCount,
                  date: magnet.date,
                  site: magnet.site,
                  downloadedAt:
                      history?.magnets[dbOnlineMagnetHash(magnet.magnet)],
                  pushing: _pushing == magnet.magnet,
                  pushDisabled: disabled,
                  onCopy: () => _copy(magnet.magnet),
                  onPush: () => _push(
                    item,
                    url: magnet.magnet,
                    name: magnet.name,
                    protocol: 'magnet',
                    tags: magnet.tags,
                    site: magnet.site,
                    date: magnet.date,
                  ),
                ),
              for (final ed2k in item.ed2ks)
                DbOnlineResourceRow(
                  name: ed2k.name,
                  value: ed2k.ed2k,
                  tags: ed2k.tags,
                  sizeMb: ed2k.sizeMb,
                  date: ed2k.date,
                  site: ed2k.site,
                  downloadedAt: history?.ed2ks[dbOnlineEd2kHash(ed2k.ed2k)],
                  pushing: _pushing == ed2k.ed2k,
                  pushDisabled:
                      disabled ||
                      !_downloaders.any(
                        (downloader) => downloader.ed2kEnabled == true,
                      ),
                  onCopy: () => _copy(ed2k.ed2k),
                  onPush: () => _push(
                    item,
                    url: ed2k.ed2k,
                    name: ed2k.name,
                    protocol: 'ed2k',
                    tags: ed2k.tags,
                    site: ed2k.site,
                    date: ed2k.date,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final capabilities = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(widget.serverId),
    );
    return DbOnlineFollowingLayout(
      eyebrow: widget.latest ? 'DB ONLINE' : l.dbOnlineFollowingUsers,
      title: widget.latest
          ? l.dbOnlineFollowingLatestReviews
          : _resolvedUsername.isEmpty
          ? widget.userId
          : _resolvedUsername,
      scrollController: _scroll,
      actions: [
        HeaderActionButton(
          icon: Icons.refresh_rounded,
          tooltip: l.fanartRefresh,
          onPressed: _refresh,
        ),
      ],
      alignTrailingToPadding: true,
      body: capabilities.asData?.value.onlineQuery == false
          ? EmptyView(message: l.dbOnlineFollowingRequiresOnlineQuery)
          : _items.isEmpty && _error != null
          ? ErrorView(message: _error!, onRetry: _loadNext)
          : _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: MediaListLayout.contentPadding.copyWith(bottom: 32),
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index < _items.length) return _item(_items[index]);
                  return Column(
                    children: [
                      if (_metadataError != null)
                        ErrorView(
                          message: _metadataError!,
                          onRetry: () => _enrich(List.of(_items), _session),
                        ),
                      if (_error != null)
                        PaginationRetry(onRetry: _loadNext)
                      else if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        )
                      else if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l.dbOnlineFollowingNoResources),
                        )
                      else if (!_hasMore)
                        const NoMoreContent(),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
