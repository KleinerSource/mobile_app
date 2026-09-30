import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription_api.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/features/cache/image_cache_manager.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/sheet_controls.dart';

class DbOnlineSubscriptionsPage extends ConsumerStatefulWidget {
  const DbOnlineSubscriptionsPage({super.key});

  @override
  ConsumerState<DbOnlineSubscriptionsPage> createState() =>
      _DbOnlineSubscriptionsPageState();
}

class _DbOnlineSubscriptionsPageState
    extends ConsumerState<DbOnlineSubscriptionsPage> {
  static const _pageSize = 24;

  final _searchController = TextEditingController();
  String _section = 'pending';
  String _keyword = '';
  int _page = 1;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _usesMovieCards =>
      _section == 'pending' || _section == 'completed' || _section == 'online';

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(mediaRuntimeConfigProvider);
    final serverId = serverConfig?.activeServerId ?? '';
    final capabilities = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(serverId),
    );
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: capabilities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _capabilityError(error, serverId),
          data: (value) => _content(value, serverId, serverConfig),
        ),
      ),
    );
  }

  Widget _capabilityError(Object error, String serverId) {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.loadFailed, style: AppText.sectionTitle(context)),
            const SizedBox(height: 8),
            Text(localizedErrorMessage(l, error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(
                dbOnlineSubscriptionCapabilitiesProvider(serverId),
              ),
              child: Text(l.dbOnlineRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    DbOnlineSubscriptionCapabilities capabilities,
    String serverId,
    ServerConfig? serverConfig,
  ) {
    final l = AppL10n.of(context);
    final sections = _sections(l, capabilities);
    if (sections.isNotEmpty &&
        !sections.any((section) => section.$1 == _section)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _section = sections.first.$1);
      });
    }
    final query = DbOnlineSubscriptionQuery(
      serverId: serverId,
      kind: _section,
      page: _page,
      limit: _pageSize,
      keyword: _keyword,
    );
    final page = sections.isEmpty
        ? null
        : ref.watch(dbOnlineSubscriptionListProvider(query));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header(l, capabilities)),
          if (!capabilities.database || !capabilities.onlineAccount)
            SliverToBoxAdapter(child: _capabilityNotice(capabilities, l)),
          if (sections.isNotEmpty)
            SliverToBoxAdapter(child: _sectionPicker(sections)),
          if (sections.isNotEmpty) ...[
            if (_section != 'online')
              SliverToBoxAdapter(child: _searchField(l)),
            if (_busy)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (page != null)
              page.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _inlineError(
                    error,
                    () =>
                        ref.invalidate(dbOnlineSubscriptionListProvider(query)),
                  ),
                ),
                data: (result) => result.items.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            _keyword.isEmpty
                                ? l.dbOnlineSubscriptionEmpty
                                : l.dbOnlineSubscriptionNoResults,
                            style: AppText.body(context),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                        sliver: _usesMovieCards
                            ? SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: MediaCardTemplate
                                          .gridChildAspectRatio,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _movieSubscriptionCard(
                                    result.items[index],
                                    l,
                                    serverConfig,
                                  ),
                                  childCount: result.items.length,
                                ),
                              )
                            : SliverList.separated(
                                itemCount: result.items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    _subscriptionRow(
                                      result.items[index],
                                      l,
                                      serverConfig,
                                    ),
                              ),
                      ),
              ),
            if (page != null)
              page.when(
                loading: () => const SliverToBoxAdapter(child: SizedBox()),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox()),
                data: (result) =>
                    SliverToBoxAdapter(child: _pagination(result, l)),
              ),
          ] else
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    !capabilities.database
                        ? l.dbOnlineSubscriptionFeatureRequiresDatabase
                        : l.dbOnlineSubscriptionFeatureRequiresOnlineAccount,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<(String, String)> _sections(
    AppL10n l,
    DbOnlineSubscriptionCapabilities capabilities,
  ) => [
    if (capabilities.database) ...[
      ('pending', l.dbOnlineSubscriptionPending),
      ('completed', l.dbOnlineSubscriptionCompleted),
    ],
    if (capabilities.onlineAccount) ('online', l.dbOnlineSubscriptionOnline),
    if (capabilities.database) ...[
      ('actor', l.dbOnlineSubscriptionActors),
      ('series', l.dbOnlineSubscriptionSeries),
      ('blacklist', l.dbOnlineSubscriptionBlacklist),
    ],
  ];

  Widget _header(AppL10n l, DbOnlineSubscriptionCapabilities capabilities) {
    final colors = appColors(context);
    final canManageOnlineSync =
        capabilities.database && capabilities.onlineAccount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.dbOnlineSubscriptionsTitle,
              style: AppText.pageTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: l.dbOnlineSubscriptionSettings,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
                border: Border.all(color: colors.cardBorder),
              ),
              child: Icon(Icons.settings, size: 18, color: colors.text),
            ),
          ),
          if (capabilities.database || canManageOnlineSync)
            PopupMenuButton<String>(
              tooltip: l.dbOnlineSubscriptionTitle,
              onSelected: (action) => _handleHeaderAction(action, l),
              itemBuilder: (context) => [
                if (_section == 'pending')
                  PopupMenuItem(
                    value: 'add',
                    child: Text(l.dbOnlineSubscriptionAdd),
                  ),
                if (_section == 'pending' || _section == 'completed')
                  PopupMenuItem(
                    value: 'run',
                    child: Text(l.dbOnlineSubscriptionRun),
                  ),
                if (_section == 'actor' || _section == 'series') ...[
                  PopupMenuItem(
                    value: 'add',
                    child: Text(l.dbOnlineSubscriptionAdd),
                  ),
                  PopupMenuItem(
                    value: 'check',
                    child: Text(l.dbOnlineSubscriptionCheck),
                  ),
                  PopupMenuItem(
                    value: 'run',
                    child: Text(l.dbOnlineSubscriptionRun),
                  ),
                  if (_section == 'series')
                    PopupMenuItem(
                      value: 'prefix',
                      child: Text(l.dbOnlineSubscriptionAddPrefix),
                    ),
                ],
                if (_section == 'online' && canManageOnlineSync) ...[
                  PopupMenuItem(
                    value: 'sync',
                    child: Text(l.dbOnlineSubscriptionSync),
                  ),
                  PopupMenuItem(
                    value: 'autosync',
                    child: Text(l.dbOnlineSubscriptionAutoSync),
                  ),
                  PopupMenuItem(
                    value: 'sync-preset',
                    child: Text(l.dbOnlineSubscriptionSyncPreset),
                  ),
                ],
                if (_section == 'blacklist') ...[
                  PopupMenuItem(
                    value: 'blacklist-add',
                    child: Text(l.dbOnlineSubscriptionBlacklistAdd),
                  ),
                  PopupMenuItem(
                    value: 'blacklist-test',
                    child: Text(l.dbOnlineSubscriptionBlacklistTest),
                  ),
                ],
                if (capabilities.database) ...[
                  PopupMenuItem(
                    value: 'preset',
                    child: Text(l.dbOnlineSubscriptionPreset),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Text(l.dbOnlineSubscriptionShare),
                  ),
                ],
              ],
              icon: Icon(Icons.more_vert_rounded, color: colors.muted),
            ),
        ],
      ),
    );
  }

  Widget _capabilityNotice(
    DbOnlineSubscriptionCapabilities capabilities,
    AppL10n l,
  ) {
    final missing = <String>[
      if (!capabilities.database) l.dbOnlineSubscriptionFeatureRequiresDatabase,
      if (!capabilities.onlineAccount)
        l.dbOnlineSubscriptionFeatureRequiresOnlineAccount,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Material(
        color: appColors(context).surface,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(missing.join(' · '), style: AppText.meta(context)),
        ),
      ),
    );
  }

  Widget _sectionPicker(List<(String, String)> sections) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = sections[index];
          return ChoiceChip(
            label: Text(section.$2),
            selected: section.$1 == _section,
            onSelected: (_) => setState(() {
              _section = section.$1;
              _page = 1;
              _keyword = '';
              _searchController.clear();
            }),
          );
        },
      ),
    );
  }

  Widget _searchField(AppL10n l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => setState(() {
          _keyword = value.trim();
          _page = 1;
        }),
        decoration: InputDecoration(
          hintText: l.dbOnlineSubscriptionSearch,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  tooltip: l.dbOnlineSubscriptionCancel,
                  onPressed: () => setState(() {
                    _keyword = '';
                    _searchController.clear();
                    _page = 1;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _subscriptionRow(
    DbOnlineSubscriptionItem item,
    AppL10n l,
    ServerConfig? serverConfig,
  ) {
    final status = item.status;
    final videoCount = int.tryParse(item.data['video_count']?.toString() ?? '');
    final pendingCount = int.tryParse(
      item.data['pending_count']?.toString() ?? '',
    );
    final completedCount = int.tryParse(
      item.data['completed_count']?.toString() ?? '',
    );
    final subtitle = <String>[
      if (item.id.isNotEmpty) item.id,
      if (status.isNotEmpty) '${l.dbOnlineSubscriptionStatus}: $status',
      if (item.data['active'] is bool)
        item.active
            ? l.dbOnlineSubscriptionActive
            : l.dbOnlineSubscriptionInactive,
      if (item.data['quality']?.toString().isNotEmpty == true)
        item.data['quality'].toString().toUpperCase(),
      if (videoCount != null) l.libraryCount(videoCount),
      if (pendingCount != null && pendingCount > 0)
        '${l.dbOnlineSubscriptionPending}: $pendingCount',
      if (completedCount != null && completedCount > 0)
        '${l.dbOnlineSubscriptionCompleted}: $completedCount',
    ].join(' · ');
    final isActor = _section == 'actor';
    final imageUrl = _resolveSubscriptionImage(serverConfig, [
      item.data['actor_avatar'],
      item.data['avatar_url'],
    ]);
    final entries = _rowMenuEntries(l);
    final card = Container(
      decoration: settingsCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isActor) ...[
                _SubscriptionCardArtwork(imageUrl: imageUrl, isActor: true),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? item.id : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle(context),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta(context),
                      ),
                    ],
                  ],
                ),
              ),
              if (_section == 'actor' || _section == 'series') ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: appColors(context).muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (entries.isEmpty) return card;
    return GlassMenuAnchor<String>(
      width: 232,
      entries: entries,
      onSelected: (action) => _handleItemAction(action, item, l),
      onAnchorTap: _section == 'actor' || _section == 'series'
          ? () => _openEntityVideos(item)
          : () {},
      child: card,
    );
  }

  Widget _movieSubscriptionCard(
    DbOnlineSubscriptionItem item,
    AppL10n l,
    ServerConfig? serverConfig,
  ) {
    final imageUrl = _resolveSubscriptionImage(serverConfig, [
      item.data['thumb_url'],
      item.data['cover_url'],
      item.data['image_url'],
    ]);
    final onlineCode = item.kind == 'online'
        ? item.data['number']?.toString().trim()
        : null;
    final meta = item.data['release_date']?.toString().trim() ?? '';
    final entries = _rowMenuEntries(l);
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = _withSubscriptionMovieBadges(
          CatalogMovieCard(
            title: item.title,
            code: onlineCode?.isNotEmpty == true ? onlineCode : item.id,
            imageUrl: imageUrl,
            meta: meta,
            width: constraints.maxWidth,
            onTap: entries.isEmpty
                ? () => _openSubscriptionMovieDetail(context, item)
                : null,
          ),
          item,
          l,
        );
        if (entries.isEmpty) return card;
        return GlassMenuAnchor<String>(
          width: 232,
          entries: entries,
          onSelected: (action) => _handleItemAction(action, item, l),
          onAnchorTap: () => _openSubscriptionMovieDetail(context, item),
          child: card,
        );
      },
    );
  }

  Future<void> _openEntityVideos(DbOnlineSubscriptionItem item) async {
    final kind = _section;
    final sourceId = item.data['id'];
    if ((kind != 'actor' && kind != 'series') || sourceId == null) return;
    await showGlassSheet<void>(
      context: context,
      builder: (context) => DbOnlineSubscriptionVideosSheet(
        kind: kind,
        sourceId: sourceId,
        title: item.title,
      ),
    );
  }

  List<GlassMenuEntry<String>> _rowMenuEntries(AppL10n l) {
    final danger = appColors(context).danger;
    if (_section == 'pending' || _section == 'completed') {
      final restoring = _section == 'completed';
      return [
        if (!restoring)
          _subscriptionMenuEntry(
            'complete',
            l.dbOnlineSubscriptionCompleted,
            Icons.done_all_rounded,
          )
        else
          _subscriptionMenuEntry(
            'pending',
            l.dbOnlineSubscriptionPendingStatus,
            Icons.restart_alt_rounded,
          ),
        _subscriptionMenuEntry(
          'edit',
          l.dbOnlineSubscriptionEdit,
          Icons.edit_outlined,
        ),
        _subscriptionMenuEntry(
          'check',
          l.dbOnlineSubscriptionCheck,
          Icons.refresh_rounded,
        ),
        _subscriptionMenuEntry(
          'delete',
          l.dbOnlineSubscriptionDelete,
          Icons.delete_outline_rounded,
          color: danger,
        ),
      ];
    }
    if (_section == 'blacklist') {
      return [
        _subscriptionMenuEntry(
          'remove',
          l.dbOnlineSubscriptionRemove,
          Icons.remove_circle_outline_rounded,
          color: danger,
        ),
      ];
    }
    if (_section == 'online') return const [];
    return [
      _subscriptionMenuEntry(
        'edit',
        l.dbOnlineSubscriptionEdit,
        Icons.edit_outlined,
      ),
      _subscriptionMenuEntry(
        'check',
        l.dbOnlineSubscriptionCheck,
        Icons.refresh_rounded,
      ),
      _subscriptionMenuEntry(
        'delete',
        l.dbOnlineSubscriptionDelete,
        Icons.delete_outline_rounded,
        color: danger,
      ),
    ];
  }

  Widget _pagination(DbOnlineSubscriptionPage result, AppL10n l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: l.dbOnlineSubscriptionPreviousPage,
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('${result.page} · ${result.total}'),
          IconButton(
            tooltip: l.dbOnlineSubscriptionNextPage,
            onPressed: result.hasMore ? () => setState(() => _page++) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _inlineError(Object error, VoidCallback retry) {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizedErrorMessage(l, error), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: retry, child: Text(l.dbOnlineRetry)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleHeaderAction(String action, AppL10n l) async {
    switch (action) {
      case 'add':
        await _editSubscription(_section == 'pending' ? 'video' : _section);
        return;
      case 'run':
        if (_section == 'actor') {
          await _perform(() => _api.runActorSubscriptions());
        } else if (_section == 'series') {
          await _handleSeriesRun();
        } else {
          await _runAllVideoSubscriptions();
        }
        return;
      case 'check':
        await _checkAllEntitySubscriptions();
        return;
      case 'sync':
        await _perform(() => _api.syncOnlineSubscriptions());
        return;
      case 'autosync':
        await _editAutoSync();
        return;
      case 'sync-preset':
        await _editSyncPreset();
        return;
      case 'preset':
        await _editPreset();
        return;
      case 'share':
        await _showShareActions();
        return;
      case 'blacklist-add':
        await _addBlacklistItem();
        return;
      case 'blacklist-test':
        await _testBlacklist();
        return;
      case 'prefix':
        await _addSeriesPrefixes();
        return;
    }
  }

  Future<void> _handleItemAction(
    String action,
    DbOnlineSubscriptionItem item,
    AppL10n l,
  ) async {
    switch (action) {
      case 'edit':
        await _editSubscription(
          _section == 'pending' || _section == 'completed' ? 'video' : _section,
          item: item,
        );
        return;
      case 'check':
        await _checkOne(item);
        return;
      case 'delete':
        await _deleteSubscription(item, l);
        return;
      case 'complete':
        await _updateQueueStatus(item.id, 'completed');
        return;
      case 'pending':
        await _updateQueueStatus(item.id, 'pending');
        return;
      case 'remove':
        await _removeBlacklistItem(item);
        return;
    }
  }

  Future<void> _editSubscription(
    String kind, {
    DbOnlineSubscriptionItem? item,
    Map<String, dynamic>? initial,
  }) async {
    final initialData = <String, dynamic>{
      if (item != null) ...item.data,
      if (initial != null) ...initial,
    };
    final saved = await showGlassSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => DbOnlineSubscriptionEditor(
        kind: kind,
        initial: initialData,
        l: AppL10n.of(context),
        isEdit: item != null,
      ),
    );
    if (saved == null) return;
    final api = _api;
    await _perform(() async {
      if (item != null) {
        switch (kind) {
          case 'video':
            await api.updateVideoSubscription(item.id, saved);
            break;
          case 'actor':
            await api.updateActorSubscription(item.id, saved);
            break;
          case 'series':
            await api.updateSeriesSubscription(
              item.id,
              saved,
              subType: item.data['sub_type']?.toString() ?? 'series',
            );
            break;
        }
      } else {
        switch (kind) {
          case 'video':
            await api.createVideoSubscription(saved);
            break;
          case 'actor':
            await api.createActorSubscription(saved);
            break;
          case 'series':
            await api.createSeriesSubscription(saved);
            break;
        }
      }
    });
  }

  Future<void> _deleteSubscription(
    DbOnlineSubscriptionItem item,
    AppL10n l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.dbOnlineSubscriptionDelete),
        content: Text(l.dbOnlineSubscriptionDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.dbOnlineSubscriptionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.dbOnlineSubscriptionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(() async {
      switch (_section) {
        case 'pending' || 'completed':
          await _api.deleteVideoSubscription(item.id);
          break;
        case 'actor':
          await _api.deleteActorSubscription(item.id);
          break;
        case 'series':
          await _api.deleteSeriesSubscription(
            item.id,
            subType: item.data['sub_type']?.toString() ?? 'series',
          );
          break;
      }
    });
  }

  Future<void> _checkOne(DbOnlineSubscriptionItem item) => _perform(() async {
    if (_section == 'pending' || _section == 'completed') {
      await _api.checkVideoSubscription(item.id);
    } else if (_section == 'actor') {
      await _api.checkActorSubscription(item.id);
    } else if (_section == 'series') {
      await _api.checkSeriesSubscription(
        item.id,
        subType: item.data['sub_type']?.toString() ?? 'series',
      );
    }
  });

  Future<void> _updateQueueStatus(String code, String status) => _perform(
    () => _api.updateSubscriptionVideoStatus({
      'source_type': 'video',
      'video_code': code,
      'status': status,
    }),
  );

  Future<void> _removeBlacklistItem(DbOnlineSubscriptionItem item) => _perform(
    () => _api.removeFromBlacklist(
      item.id,
      entryType: item.data['entry_type']?.toString() ?? 'video_code',
    ),
  );

  Future<void> _runAllVideoSubscriptions() =>
      _perform(() => _api.runVideoSubscriptionChecks());

  Future<void> _checkAllEntitySubscriptions() => _perform(() async {
    if (_section == 'actor') {
      await _api.batchCheckActorSubscriptions();
    } else if (_section == 'series') {
      await _api.batchCheckSeriesSubscriptions(subType: 'all');
    }
  });

  Future<void> _handleSeriesRun() => _perform(() async {
    await _api.runSeriesSubscriptions(subType: 'all');
  });

  Future<void> _perform(Future<dynamic> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ref.invalidate(dbOnlineSubscriptionListProvider(_query));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).dbOnlineSubscriptionActionCompleted,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(AppL10n.of(context), error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAutoSync() async {
    try {
      final existing = _payloadMap(await _api.getAutoSync());
      if (!mounted) return;
      final result = await showGlassSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            _AutoSyncEditor(initial: existing, l: AppL10n.of(context)),
      );
      if (result == null) return;
      await _perform(() => _api.updateAutoSync(result));
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(AppL10n.of(context), error));
    }
  }

  Future<void> _editPreset() async {
    try {
      final existing = _payloadMap(await _api.getSubscriptionPreset());
      if (!mounted) return;
      final preset = _mapValue(existing['preset']);
      final result = await showGlassSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => DbOnlineSubscriptionEditor(
          kind: 'video',
          presetOnly: true,
          initial: preset,
          l: AppL10n.of(context),
        ),
      );
      if (result == null) return;
      await _perform(() => _api.updateSubscriptionPreset({'preset': result}));
      if (!mounted) return;
      final apply = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppL10n.of(context).dbOnlineSubscriptionOverwrite),
          content: Text(
            AppL10n.of(context).dbOnlineSubscriptionOverwriteConfirm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppL10n.of(context).dbOnlineSubscriptionCancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppL10n.of(context).dbOnlineSubscriptionOverwrite),
            ),
          ],
        ),
      );
      if (apply == true) {
        await _perform(
          () => _api.overwriteSubscriptionPreset({'preset': result}),
        );
      }
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(AppL10n.of(context), error));
    }
  }

  Future<void> _editSyncPreset() async {
    try {
      final autoSync = _payloadMap(await _api.getAutoSync());
      if (!mounted) return;
      final result = await showGlassSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => DbOnlineSubscriptionEditor(
          kind: 'video',
          presetOnly: true,
          initial: _mapValue(autoSync['preset']),
          l: AppL10n.of(context),
        ),
      );
      if (result == null) return;
      await _perform(
        () => _api.updateAutoSync({...autoSync, 'preset': result}),
      );
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(AppL10n.of(context), error));
    }
  }

  Future<void> _showShareActions() async {
    final l = AppL10n.of(context);
    final action = await showGlassSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.share_outlined,
              title: l.dbOnlineSubscriptionShare,
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(l.dbOnlineSubscriptionExport),
              onTap: () => Navigator.pop(context, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(l.dbOnlineSubscriptionImport),
              onTap: () => Navigator.pop(context, 'import'),
            ),
          ],
        ),
      ),
    );
    if (action == 'export') {
      await _exportShare();
    } else if (action == 'import') {
      await _importShare();
    }
  }

  Future<void> _exportShare() async {
    await _perform(() async {
      final response = _payloadMap(
        await _api.exportSubscriptionShare({
          'include_video': true,
          'include_actor': true,
          'include_series_sub_types': ['series', 'prefix'],
        }),
      );
      final share = response['share_text'] ?? response['share_code'];
      final text = share?.toString() ?? jsonEncode(response);
      await Clipboard.setData(ClipboardData(text: text));
    });
  }

  Future<void> _importShare() async {
    final l = AppL10n.of(context);
    final controller = TextEditingController();
    final shareText = await showGlassSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.file_download_outlined,
                title: l.dbOnlineSubscriptionImport,
              ),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l.dbOnlineSubscriptionShareText,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: Text(l.dbOnlineSubscriptionImport),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (shareText == null || shareText.isEmpty) return;
    Map<String, dynamic> analysis;
    try {
      analysis = _payloadMap(
        await _api.analyzeSubscriptionShare({'share_text': shareText}),
      );
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(l, error));
      return;
    }
    if (!mounted) return;
    final summary = _mapValue(analysis['summary']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.dbOnlineSubscriptionImport),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonEncode(summary.isEmpty ? analysis : summary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.dbOnlineSubscriptionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.dbOnlineSubscriptionImport),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _perform(
      () => _api.importSubscriptionShare({
        'share_text': shareText,
        'include_video': true,
        'include_actor': true,
        'include_series_sub_types': ['series', 'prefix'],
      }),
    );
  }

  Future<void> _addSeriesPrefixes() async {
    final l = AppL10n.of(context);
    final controller = TextEditingController();
    final text = await showGlassSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.add_rounded,
                title: l.dbOnlineSubscriptionSeries,
              ),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l.dbOnlineSubscriptionCode,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(l.dbOnlineSubscriptionSave),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (text == null) return;
    final prefixes = text
        .split(RegExp(r'[\n,\s]+'))
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(100);
    await _perform(() async {
      for (final prefix in prefixes) {
        await _api.createSeriesSubscription({
          'external_id': prefix,
          'sub_type': 'prefix',
          'series_name': prefix,
          'active': true,
          'quality': '',
          'require_sub': false,
          'require_uncensored': false,
          'min_size_mb': 0,
          'max_size_mb': 0,
          'max_file_count': 0,
        });
      }
    });
  }

  Future<void> _addBlacklistItem() async {
    final l = AppL10n.of(context);
    final rulesController = TextEditingController();
    final reasonController = TextEditingController();
    var entryType = 'video_code';
    final result = await showGlassSheet<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  icon: Icons.block_rounded,
                  title: l.dbOnlineSubscriptionBlacklistAdd,
                ),
                DropdownButtonFormField<String>(
                  initialValue: entryType,
                  decoration: InputDecoration(
                    labelText: l.dbOnlineSubscriptionType,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'video_code',
                      child: Text(l.dbOnlineSubscriptionBlacklistVideoCode),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text(l.dbOnlineSubscriptionBlacklistCategory),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => entryType = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rulesController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: entryType == 'category'
                        ? l.dbOnlineSubscriptionBlacklistCategory
                        : l.dbOnlineSubscriptionCode,
                  ),
                ),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: l.dbOnlineSubscriptionReason,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'entry_type': entryType,
                    'rules': rulesController.text,
                    'reason': reasonController.text,
                  }),
                  child: Text(l.dbOnlineSubscriptionSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    rulesController.dispose();
    reasonController.dispose();
    if (result == null) return;
    final type = result['entry_type'] ?? 'video_code';
    final rules = (result['rules'] ?? '')
        .split(type == 'category' ? RegExp(r'[\n,]+') : RegExp(r'[\n,\s]+'))
        .map(
          (value) =>
              type == 'category' ? value.trim() : value.trim().toUpperCase(),
        )
        .where((value) => value.isNotEmpty)
        .take(100)
        .toList(growable: false);
    if (rules.isEmpty) return;
    await _perform(
      () => _api.addToBlacklist({
        'entry_type': type,
        'video_codes': rules,
        'reason': result['reason']?.trim() ?? '',
      }),
    );
  }

  Future<void> _testBlacklist() async {
    final l = AppL10n.of(context);
    final codesController = TextEditingController();
    final categoryRuleController = TextEditingController();
    var entryType = 'video_code';
    final form = await showGlassSheet<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  icon: Icons.rule_rounded,
                  title: l.dbOnlineSubscriptionBlacklistTest,
                ),
                DropdownButtonFormField<String>(
                  initialValue: entryType,
                  decoration: InputDecoration(
                    labelText: l.dbOnlineSubscriptionType,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'video_code',
                      child: Text(l.dbOnlineSubscriptionBlacklistVideoCode),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text(l.dbOnlineSubscriptionBlacklistCategory),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => entryType = value);
                  },
                ),
                TextField(
                  controller: codesController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l.dbOnlineSubscriptionTestContent,
                  ),
                ),
                if (entryType == 'category')
                  TextField(
                    controller: categoryRuleController,
                    decoration: InputDecoration(
                      labelText: l.dbOnlineSubscriptionCategoryRule,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'entry_type': entryType,
                    'codes': codesController.text,
                    'category_rule': categoryRuleController.text,
                  }),
                  child: Text(l.dbOnlineSubscriptionCheck),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    codesController.dispose();
    categoryRuleController.dispose();
    if (form == null) return;
    final codes = (form['codes'] ?? '')
        .split(RegExp(r'[\n,\s]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (codes.isEmpty) return;
    await _perform(
      () => _api.testBlacklist(
        codes: codes,
        entryType: form['entry_type'] ?? 'video_code',
        categoryRule: form['category_rule'] ?? '',
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(dbOnlineSubscriptionListProvider(_query));
    try {
      await ref.read(dbOnlineSubscriptionListProvider(_query).future);
    } catch (_) {}
  }

  DbOnlineSubscriptionQuery get _query => DbOnlineSubscriptionQuery(
    serverId: ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
    kind: _section,
    page: _page,
    limit: _pageSize,
    keyword: _keyword,
  );

  DbOnlineSubscriptionApi get _api =>
      ref.read(dboSubscriptionRepositoryProvider).api;

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

void _openSubscriptionMovieDetail(
  BuildContext context,
  DbOnlineSubscriptionItem item,
) {
  final videoId = item.data['video_id']?.toString().trim() ?? '';
  final code = [item.data['number'], item.data['video_code'], item.data['code']]
      .map((value) => value?.toString().trim() ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (videoId.isEmpty && code.isEmpty) return;

  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => videoId.isNotEmpty
          ? DbOnlineMovieDetailPage.byVideoId(videoId: videoId)
          : DbOnlineMovieDetailPage(code: code),
    ),
  );
}

Widget _withSubscriptionMovieBadges(
  Widget child,
  DbOnlineSubscriptionItem item,
  AppL10n l,
) {
  final data = item.data;
  final status = item.status;
  final overdue = data['overdue'] == true;
  final matchedFlags =
      int.tryParse(data['matched_flags']?.toString() ?? '') ?? 0;
  final badges = <Widget>[];

  if (overdue) {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionOverdue,
        const Color(0xFFF97316),
      ),
    );
  } else if (status == 'completed') {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionCompleted,
        const Color(0xFF22C55E),
      ),
    );
  } else if (status == 'pending') {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionPendingBadge,
        const Color(0xFFFACC15),
      ),
    );
  } else if (status == 'skipped') {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionSkipped,
        const Color(0xFFEF4444),
      ),
    );
  }

  if (data['wash_mode'] == true) {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionWashShort,
        const Color(0xFFA855F7),
        matched: status == 'completed',
      ),
    );
  }
  if (data['pre_download_mode'] == true) {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionPreDownloadShort,
        const Color(0xFF00C878),
        matched: matchedFlags != 0,
      ),
    );
  }
  final quality = data['quality']?.toString().toLowerCase();
  if (quality == 'hd') {
    badges.add(
      _subscriptionBadge(
        'HD',
        const Color(0xFF00CFE8),
        matched: (matchedFlags & 2) != 0,
      ),
    );
  } else if (quality == 'uhd') {
    badges.add(
      _subscriptionBadge(
        'UHD',
        const Color(0xFF4A9EFF),
        matched: (matchedFlags & 4) != 0,
      ),
    );
  }
  if (data['require_sub'] == true) {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionSubtitleShort,
        const Color(0xFFFFC107),
        matched: (matchedFlags & 8) != 0,
      ),
    );
  }
  if (data['require_uncensored'] == true) {
    badges.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionUncensoredShort,
        const Color(0xFFFF0050),
        matched: (matchedFlags & 16) != 0,
      ),
    );
  }
  if (badges.isEmpty) return child;

  return Stack(
    children: [
      child,
      Positioned(
        top: 5,
        left: 5,
        right: 5,
        child: IgnorePointer(
          child: Wrap(spacing: 3, runSpacing: 3, children: badges),
        ),
      ),
    ],
  );
}

Widget _subscriptionBadge(String label, Color color, {bool matched = true}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: matched ? color.withValues(alpha: 0.82) : Colors.black54,
        border: Border.all(color: color.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: matched ? Colors.white : color,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

class DbOnlineSubscriptionVideosSheet extends ConsumerStatefulWidget {
  const DbOnlineSubscriptionVideosSheet({
    super.key,
    required this.kind,
    required this.sourceId,
    required this.title,
  });

  final String kind;
  final Object sourceId;
  final String title;

  @override
  ConsumerState<DbOnlineSubscriptionVideosSheet> createState() =>
      _DbOnlineSubscriptionVideosSheetState();
}

class _DbOnlineSubscriptionVideosSheetState
    extends ConsumerState<DbOnlineSubscriptionVideosSheet> {
  static const _pageSize = 24;
  static const _statuses = ['pending', 'completed', 'skipped'];

  final _searchController = TextEditingController();
  String _keyword = '';
  String _status = 'pending';
  int _page = 1;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(mediaRuntimeConfigProvider);
    final serverId = serverConfig?.activeServerId ?? '';
    final query = DbOnlineSubscriptionQuery(
      serverId: serverId,
      kind: widget.kind == 'actor' ? 'actor-videos' : 'series-videos',
      sourceType: widget.kind,
      sourceId: widget.sourceId,
      queueStatus: _status,
      page: _page,
      limit: _pageSize,
      keyword: _keyword,
    );
    final result = ref.watch(dbOnlineSubscriptionListProvider(query));
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            children: [
              SheetHeader(
                icon: widget.kind == 'actor'
                    ? Icons.person_outline_rounded
                    : Icons.layers_outlined,
                title: widget.title,
              ),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statuses.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    final label = switch (status) {
                      'pending' => l.dbOnlineSubscriptionPending,
                      'completed' => l.dbOnlineSubscriptionCompleted,
                      _ => l.dbOnlineSubscriptionSkipped,
                    };
                    return ChoiceChip(
                      label: Text(label),
                      selected: _status == status,
                      onSelected: (_) => setState(() {
                        _status = status;
                        _page = 1;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => setState(() {
                  _keyword = value.trim();
                  _page = 1;
                }),
                decoration: InputDecoration(
                  hintText: l.dbOnlineSubscriptionSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.dbOnlineSubscriptionCancel,
                          onPressed: () => setState(() {
                            _keyword = '';
                            _searchController.clear();
                            _page = 1;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refresh(query),
                  child: result.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 90),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            localizedErrorMessage(l, error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => ref.invalidate(
                              dbOnlineSubscriptionListProvider(query),
                            ),
                            child: Text(l.dbOnlineRetry),
                          ),
                        ),
                      ],
                    ),
                    data: (page) => page.items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              Center(
                                child: Text(
                                  _keyword.isEmpty
                                      ? l.dbOnlineSubscriptionEmpty
                                      : l.dbOnlineSubscriptionNoResults,
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: page.items.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                  childAspectRatio:
                                      MediaCardTemplate.gridChildAspectRatio,
                                ),
                            itemBuilder: (context, index) => _videoCard(
                              page.items[index],
                              l,
                              query,
                              serverConfig,
                            ),
                          ),
                  ),
                ),
              ),
              result.when(
                loading: () => const SizedBox(height: 44),
                error: (_, _) => const SizedBox(height: 44),
                data: (page) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: l.dbOnlineSubscriptionPreviousPage,
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('${page.page} · ${page.total}'),
                    IconButton(
                      tooltip: l.dbOnlineSubscriptionNextPage,
                      onPressed: page.hasMore
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
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
    DbOnlineSubscriptionQuery query,
    ServerConfig? serverConfig,
  ) {
    final releaseDate = [
      if (item.data['release_date']?.toString().isNotEmpty == true)
        item.data['release_date'].toString(),
    ].join(' · ');
    final imageUrl = _resolveSubscriptionImage(serverConfig, [
      item.data['thumb_url'],
      item.data['cover_url'],
    ]);
    final meta = releaseDate;
    final menuEntries = [
      for (final status in _statuses.where(
        (value) => value != item.status && value != 'skipped',
      ))
        _subscriptionMenuEntry(
          status,
          _subscriptionQueueStatusLabel(status, l),
          status == 'pending' ? Icons.schedule_rounded : Icons.done_all_rounded,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GlassMenuAnchor<String>(
        width: 232,
        entries: menuEntries,
        onSelected: (status) => _updateStatus(item, status, query, l),
        onAnchorTap: () => _openSubscriptionMovieDetail(context, item),
        child: _withSubscriptionMovieBadges(
          CatalogMovieCard(
            title: item.title,
            code: item.id,
            imageUrl: imageUrl,
            meta: meta,
            width: constraints.maxWidth,
          ),
          item,
          l,
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    DbOnlineSubscriptionItem item,
    String status,
    DbOnlineSubscriptionQuery query,
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
      ref.invalidate(dbOnlineSubscriptionListProvider(query));
      ref.invalidate(dbOnlineSubscriptionListProvider);
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

  Future<void> _refresh(DbOnlineSubscriptionQuery query) async {
    ref.invalidate(dbOnlineSubscriptionListProvider(query));
    try {
      await ref.read(dbOnlineSubscriptionListProvider(query).future);
    } catch (_) {}
  }
}

Future<Map<String, dynamic>?> showDbOnlineSubscriptionEditor(
  BuildContext context, {
  required String kind,
  required Map<String, dynamic> initial,
  bool isEdit = false,
}) => showGlassSheet<Map<String, dynamic>>(
  context: context,
  builder: (context) => DbOnlineSubscriptionEditor(
    kind: kind,
    initial: initial,
    l: AppL10n.of(context),
    isEdit: isEdit,
  ),
);

class DbOnlineSubscriptionEditor extends StatefulWidget {
  const DbOnlineSubscriptionEditor({
    super.key,
    required this.kind,
    required this.initial,
    required this.l,
    this.presetOnly = false,
    this.isEdit = false,
  });

  final String kind;
  final Map<String, dynamic> initial;
  final AppL10n l;
  final bool presetOnly;
  final bool isEdit;

  @override
  State<DbOnlineSubscriptionEditor> createState() =>
      _DbOnlineSubscriptionEditorState();
}

class _DbOnlineSubscriptionEditorState
    extends State<DbOnlineSubscriptionEditor> {
  late final TextEditingController _id = TextEditingController(
    text: _value(const ['video_code', 'actor_id', 'external_id', 'id']),
  );
  late final TextEditingController _name = TextEditingController(
    text: _value(const ['video_title', 'actor_name', 'series_name', 'name']),
  );
  late final TextEditingController _startDate = TextEditingController(
    text: _value(const ['after_date', 'start_date']),
  );
  late final TextEditingController _minimum = TextEditingController(
    text: _value(const ['min_size_mb'], fallback: '0'),
  );
  late final TextEditingController _maximum = TextEditingController(
    text: _value(const ['max_size_mb'], fallback: '0'),
  );
  late final TextEditingController _fileCount = TextEditingController(
    text: _value(const ['max_file_count'], fallback: '0'),
  );
  late final TextEditingController _overdueDays = TextEditingController(
    text: _value(const ['overdue_days'], fallback: '0'),
  );
  late final TextEditingController _includeCategories = TextEditingController(
    text: _stringList(widget.initial['include_categories']),
  );
  late final TextEditingController _excludeCategories = TextEditingController(
    text: _stringList(widget.initial['exclude_categories']),
  );
  late final TextEditingController _downloader = TextEditingController(
    text: _value(const ['downloader']),
  );
  late final TextEditingController _savePath = TextEditingController(
    text: _value(const ['save_path']),
  );
  late final TextEditingController _deviceTarget = TextEditingController(
    text: _value(const ['device_target']),
  );
  late String _quality = _value(const ['quality']);
  late bool _active =
      (widget.initial['enabled'] ?? widget.initial['active']) != false;
  late bool _requireSub = widget.initial['require_sub'] == true;
  late bool _requireUncensored = widget.initial['require_uncensored'] == true;
  late bool _preDownload = widget.initial['pre_download_mode'] == true;
  late bool _washMode = widget.initial['wash_mode'] == true;

  String _value(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = widget.initial[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _startDate,
      _minimum,
      _maximum,
      _fileCount,
      _overdueDays,
      _includeCategories,
      _excludeCategories,
      _downloader,
      _savePath,
      _deviceTarget,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final title = widget.presetOnly
        ? l.dbOnlineSubscriptionPreset
        : widget.isEdit
        ? l.dbOnlineSubscriptionEdit
        : l.dbOnlineSubscriptionAdd;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          8,
          22,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                icon: widget.kind == 'actor'
                    ? Icons.person_add_alt_1_rounded
                    : widget.kind == 'series'
                    ? Icons.layers_outlined
                    : Icons.subscriptions_outlined,
                title: title,
              ),
              if (!widget.presetOnly) ...[
                _field(
                  _id,
                  widget.kind == 'video'
                      ? l.dbOnlineSubscriptionCode
                      : l.dbOnlineSubscriptionId,
                  readOnly: widget.isEdit,
                ),
                _field(
                  _name,
                  l.dbOnlineSubscriptionName,
                  readOnly: widget.isEdit,
                ),
              ],
              _field(_startDate, l.dbOnlineSubscriptionStartDate),
              DropdownButtonFormField<String>(
                initialValue: const ['', 'hd', 'uhd'].contains(_quality)
                    ? _quality
                    : '',
                decoration: InputDecoration(
                  labelText: l.dbOnlineSubscriptionQuality,
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l.dbOnlineSubscriptionQualityNormal),
                  ),
                  DropdownMenuItem(
                    value: 'hd',
                    child: Text(l.dbOnlineSubscriptionQualityHd),
                  ),
                  DropdownMenuItem(
                    value: 'uhd',
                    child: Text(l.dbOnlineSubscriptionQualityUhd),
                  ),
                ],
                onChanged: (value) => setState(() => _quality = value ?? ''),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dbOnlineSubscriptionActive),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dbOnlineSubscriptionSubtitle),
                value: _requireSub,
                onChanged: (value) => setState(() => _requireSub = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dbOnlineSubscriptionUncensored),
                value: _requireUncensored,
                onChanged: (value) =>
                    setState(() => _requireUncensored = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dbOnlineSubscriptionPreDownload),
                value: _preDownload,
                onChanged: (value) => setState(() => _preDownload = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dbOnlineSubscriptionWashMode),
                value: _washMode,
                onChanged: (value) => setState(() => _washMode = value),
              ),
              _field(
                _minimum,
                l.dbOnlineSubscriptionMinimumSize,
                numeric: true,
              ),
              _field(
                _maximum,
                l.dbOnlineSubscriptionMaximumSize,
                numeric: true,
              ),
              _field(_fileCount, l.dbOnlineSubscriptionMaxFiles, numeric: true),
              _field(
                _overdueDays,
                l.dbOnlineSubscriptionOverdueDays,
                numeric: true,
              ),
              if (widget.kind == 'actor') ...[
                _field(
                  _includeCategories,
                  l.dbOnlineSubscriptionIncludeCategories,
                ),
                _field(
                  _excludeCategories,
                  l.dbOnlineSubscriptionExcludeCategories,
                ),
              ],
              _field(_downloader, l.dbOnlineSubscriptionDownloader),
              _field(_savePath, l.dbOnlineSubscriptionSavePath),
              _field(_deviceTarget, l.dbOnlineSubscriptionDevice),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _save,
                child: Text(l.dbOnlineSubscriptionSave),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.dbOnlineSubscriptionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    ),
  );

  void _save() {
    if (!widget.presetOnly &&
        !widget.isEdit &&
        (_id.text.trim().isEmpty || _name.text.trim().isEmpty)) {
      return;
    }
    final values = <String, dynamic>{
      ...widget.initial,
      if (widget.presetOnly) 'enabled': _active,
      if (!widget.presetOnly) 'active': _active,
      'pre_download_mode': _preDownload,
      'wash_mode': _washMode,
      'quality': _quality,
      'require_sub': _requireSub,
      'require_uncensored': _requireUncensored,
      'min_size_mb': double.tryParse(_minimum.text) ?? 0,
      'max_size_mb': double.tryParse(_maximum.text) ?? 0,
      'max_file_count': int.tryParse(_fileCount.text) ?? 0,
      'overdue_days': int.tryParse(_overdueDays.text) ?? 0,
      'downloader': _downloader.text.trim(),
      'save_path': _savePath.text.trim(),
      'device_target': _deviceTarget.text.trim(),
      if (widget.kind == 'video') 'after_date': _startDate.text.trim(),
      if (widget.kind != 'video') 'start_date': _startDate.text.trim(),
      if (widget.kind == 'actor')
        'include_categories': _parseList(_includeCategories.text),
      if (widget.kind == 'actor')
        'exclude_categories': _parseList(_excludeCategories.text),
    };
    if (!widget.presetOnly && !widget.isEdit) {
      switch (widget.kind) {
        case 'video':
          values['video_code'] = _id.text.trim();
          values['video_title'] = _name.text.trim();
        case 'actor':
          values['actor_id'] = _id.text.trim();
          values['actor_name'] = _name.text.trim();
        case 'series':
          values['external_id'] = _id.text.trim();
          values['sub_type'] =
              widget.initial['sub_type']?.toString() ?? 'series';
          values['series_name'] = _name.text.trim();
      }
    }
    Navigator.pop(context, values);
  }

  List<String> _parseList(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class _AutoSyncEditor extends StatefulWidget {
  const _AutoSyncEditor({required this.initial, required this.l});

  final Map<String, dynamic> initial;
  final AppL10n l;

  @override
  State<_AutoSyncEditor> createState() => _AutoSyncEditorState();
}

class _AutoSyncEditorState extends State<_AutoSyncEditor> {
  late bool _enabled = widget.initial['enabled'] == true;
  late final TextEditingController _schedules = TextEditingController(
    text: _scheduleText(widget.initial['schedules']),
  );

  @override
  void dispose() {
    _schedules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        8,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            icon: Icons.sync_rounded,
            title: widget.l.dbOnlineSubscriptionAutoSync,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(widget.l.dbOnlineSubscriptionActive),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          TextField(
            controller: _schedules,
            decoration: InputDecoration(
              labelText: widget.l.dbOnlineSubscriptionSchedules,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              ...widget.initial,
              'enabled': _enabled,
              'schedules': _schedules.text
                  .split(RegExp(r'[,\s]+'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false),
            }),
            child: Text(widget.l.dbOnlineSubscriptionSave),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.l.dbOnlineSubscriptionCancel),
          ),
        ],
      ),
    ),
  );
}

String _scheduleText(Object? raw) => raw is List
    ? raw.map((item) => item.toString()).join(', ')
    : raw?.toString() ?? '';

Map<String, dynamic> _payloadMap(Object? raw) {
  final root = _mapValue(raw);
  final data = _mapValue(root['data']);
  return data.isEmpty ? root : data;
}

Map<String, dynamic> _mapValue(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

String _stringList(Object? raw) => raw is List
    ? raw.map((item) => item.toString()).join(', ')
    : raw?.toString() ?? '';

String? _resolveSubscriptionImage(
  ServerConfig? config,
  List<Object?> candidates,
) {
  if (config == null) return null;
  for (final candidate in candidates) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isNotEmpty) return resolveServerUrl(config, value);
  }
  return null;
}

class _SubscriptionCardArtwork extends StatelessWidget {
  const _SubscriptionCardArtwork({this.imageUrl, this.isActor = false});

  final String? imageUrl;
  final bool isActor;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final fallback = Center(
      child: Icon(
        isActor ? Icons.person_outline_rounded : Icons.movie_outlined,
        size: 22,
        color: colors.muted,
      ),
    );
    final source = imageUrl?.trim() ?? '';
    return Container(
      width: isActor ? 56 : 58,
      height: isActor ? 56 : 82,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.chipBg,
        shape: isActor ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isActor ? null : BorderRadius.circular(10),
        border: Border.all(color: colors.cardBorder),
      ),
      child: source.isEmpty
          ? fallback
          : CachedNetworkImage(
              cacheManager: AppImageCacheManager.instance,
              imageUrl: source,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

GlassMenuEntry<String> _subscriptionMenuEntry(
  String value,
  String label,
  IconData icon, {
  Color? color,
}) => GlassMenuEntry<String>.action(
  value: value,
  builder: (context, selected, onTap) => GlassMenuRow(
    icon: icon,
    label: label,
    selected: selected,
    foregroundColor: color,
    onTap: onTap,
  ),
);

String _subscriptionQueueStatusLabel(String status, AppL10n l) =>
    switch (status) {
      'pending' => l.dbOnlineSubscriptionPendingStatus,
      'completed' => l.dbOnlineSubscriptionCompleted,
      'skipped' => l.dbOnlineSubscriptionSkipped,
      _ => status,
    };
