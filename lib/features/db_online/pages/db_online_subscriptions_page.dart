import 'package:omm/core/sources/media/dbo/db_online_watched.dart';
import 'package:omm/features/db_online/widgets/db_online_download_requirements_fields.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_section_tab.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription_api.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_actor_categories_sheet.dart';
import 'package:omm/features/db_online/widgets/db_online_subscription_status_badge.dart';
import 'package:omm/features/cache/image_cache_manager.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/sheet_controls.dart';

part 'db_online_subscription_videos_sheet.dart';
part 'db_online_subscription_editor.dart';
part 'db_online_auto_sync_editor.dart';
part 'db_online_subscription_share_sheet.dart';

/// 订阅管理统一的影片视图模式：订阅中、已完成、在线订阅以及演员/综合订阅
/// 的影片列表共用，不按板块单独保存。
const _subscriptionViewModeKey = 'db_online.subscriptions.view_mode.v1';

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
  final _requests = PagedRequestCoordinator(firstPageKey: 1);
  final _pagingController = PagingController<int, DbOnlineSubscriptionItem>(
    firstPageKey: 1,
  );
  final _scrollController = ScrollController();
  final _sectionPickerController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  String _section = 'pending';
  String _keyword = '';
  bool _busy = false;
  bool _pagingListenerAttached = false;
  bool _lastPageComplete = false;
  String? _pagingQueryKey;
  late final PagedSelectionController<DbOnlineSubscriptionItem>
  _blacklistSelection;
  double _horizontalDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _blacklistSelection = PagedSelectionController<DbOnlineSubscriptionItem>(
      idOf: _blacklistItemKey,
    )..addModeListener(_onBlacklistSelectionModeChanged);
  }

  @override
  void dispose() {
    _blacklistSelection.removeModeListener(_onBlacklistSelectionModeChanged);
    _blacklistSelection.dispose();
    _requests.dispose();
    _pagingController.dispose();
    _scrollController.dispose();
    _sectionPickerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _selectingBlacklist =>
      _section == 'blacklist' && _blacklistSelection.isActive;

  void _onBlacklistSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  String _blacklistItemKey(DbOnlineSubscriptionItem item) {
    final type = item.data['entry_type']?.toString() ?? 'video_code';
    final rule = item.data['video_code']?.toString() ?? item.id;
    return '$type:$rule';
  }

  bool get _usesMovieCards =>
      _section == 'pending' || _section == 'completed' || _section == 'online';

  /// 演员与综合订阅本身是实体列表，视图切换作用于其影片弹层。
  bool get _showsViewModeToggle =>
      _usesMovieCards || _section == 'actor' || _section == 'series';

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(mediaRuntimeConfigProvider);
    final serverId = serverConfig?.activeServerId ?? '';
    final capabilities = ref.watch(
      dbOnlineSubscriptionCapabilitiesProvider(serverId),
    );
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _blacklistToolbar(AppL10n.of(context)),
      body: PopScope(
        canPop: !_selectingBlacklist,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectingBlacklist) _blacklistSelection.exit();
        },
        child: SafeArea(
          bottom: false,
          child: capabilities.when(
            loading: () =>
                _stateContent(const Center(child: CircularProgressIndicator())),
            error: (error, _) =>
                _stateContent(_capabilityError(error, serverId)),
            data: (value) => _content(value, serverId, serverConfig),
          ),
        ),
      ),
    );
  }

  Widget? _blacklistToolbar(AppL10n l) {
    if (!_selectingBlacklist) return null;
    final colors = appColors(context);
    return ValueListenableBuilder<Set<Object>>(
      valueListenable: _blacklistSelection.selectedListenable,
      builder: (context, selected, _) => EntityBatchToolbar(
        selectedCount: selected.length,
        onSelectAll: _selectAllLoadedBlacklist,
        onClear: _blacklistSelection.clear,
        onClose: _blacklistSelection.exit,
        actions: [
          EntityBatchAction(
            icon: Icons.delete_outline_rounded,
            label: l.dbOnlineSubscriptionDelete,
            color: colors.danger,
            onTap: selected.isEmpty || _busy
                ? null
                : () => _deleteSelectedBlacklistItems(l),
          ),
        ],
      ),
    );
  }

  void _selectAllLoadedBlacklist() {
    _blacklistSelection.selectAll(
      _pagingController.itemList ?? const <DbOnlineSubscriptionItem>[],
    );
  }

  Widget _stateContent(Widget body) => SettingsFixedHeaderLayout(
    header: _header(AppL10n.of(context), null, null, hasBlockBelow: false),
    body: body,
  );

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
    final viewMode = ref.watch(
      mediaViewModePreferenceProvider(_subscriptionViewModeKey),
    );
    final sections = _sections(l, capabilities);
    if (sections.isNotEmpty &&
        !sections.any((section) => section.$1 == _section)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _section = sections.first.$1);
        _scrollSelectedSectionIntoView();
        _reloadForQuery();
      });
    }
    if (sections.isNotEmpty) _syncPagingQuery(serverId);
    final autoSync = _section == 'online' && capabilities.onlineAccount
        ? ref.watch(dbOnlineSubscriptionAutoSyncProvider(serverId))
        : null;

    // 头部/横幅的底距随其后是否有块切换：下面还有块用块间距，
    // 列表直接跟随时用列表间距，保证组件增减不改变列表与上一块的间距。
    final showsNotice = !capabilities.database || !capabilities.onlineAccount;
    final hasToolbar = sections.isNotEmpty;
    return SettingsFixedHeaderLayout(
      scrollController: _scrollController,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            l,
            capabilities,
            autoSync,
            hasBlockBelow: showsNotice || hasToolbar,
          ),
          if (showsNotice)
            _capabilityNotice(capabilities, l, hasToolbar: hasToolbar),
          if (hasToolbar) _sectionPicker(sections),
          if (hasToolbar && _section != 'online')
            _searchField(l)
          else if (hasToolbar)
            const SizedBox(height: PageHeader.aboveListGap),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: sections.length > 1
              ? (_) => _horizontalDragDistance = 0
              : null,
          onHorizontalDragUpdate: sections.length > 1
              ? (details) => _horizontalDragDistance += details.delta.dx
              : null,
          onHorizontalDragEnd: sections.length > 1
              ? (_) => _switchSectionBySwipe(sections)
              : null,
          onHorizontalDragCancel: () => _horizontalDragDistance = 0,
          child: PagedSelectionScope<DbOnlineSubscriptionItem>(
            selection: _blacklistSelection,
            scrollController: _scrollController,
            layout: DragSelectionLayout.list,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (sections.isNotEmpty) ...[
                  if (_busy)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      _usesMovieCards || _section == 'blacklist'
                          ? MediaListLayout.horizontalInset
                          : 18,
                      MediaListLayout.contentTopInset,
                      _usesMovieCards || _section == 'blacklist'
                          ? MediaListLayout.horizontalInset
                          : 18,
                      _selectingBlacklist
                          ? 136
                          : floatingTabBarContentBottomInset(context),
                    ),
                    sliver: _usesMovieCards
                        ? viewMode == MediaViewMode.portrait
                              ? PagedSliverGrid<int, DbOnlineSubscriptionItem>(
                                  pagingController: _pagingController,
                                  showNoMoreItemsIndicatorAsGridChild: false,
                                  gridDelegate: const MediaGridDelegate(),
                                  builderDelegate: _pagingDelegate(
                                    l,
                                    serverConfig,
                                    viewMode,
                                  ),
                                )
                              : PagedSliverList<int, DbOnlineSubscriptionItem>(
                                  pagingController: _pagingController,
                                  builderDelegate: _pagingDelegate(
                                    l,
                                    serverConfig,
                                    viewMode,
                                  ),
                                )
                        : PagedSliverList<
                            int,
                            DbOnlineSubscriptionItem
                          >.separated(
                            pagingController: _pagingController,
                            separatorBuilder: (_, itemIndex) {
                              if (_section != 'blacklist') {
                                return const SizedBox(height: 8);
                              }
                              final count =
                                  _pagingController.itemList?.length ?? 0;
                              return itemIndex >= count - 1
                                  ? const SizedBox.shrink()
                                  : Divider(
                                      height: 1,
                                      color: appColors(context).divider,
                                    );
                            },
                            builderDelegate: _pagingDelegate(
                              l,
                              serverConfig,
                              viewMode,
                            ),
                          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  PagedChildBuilderDelegate<DbOnlineSubscriptionItem> _pagingDelegate(
    AppL10n l,
    ServerConfig? serverConfig,
    MediaViewMode viewMode,
  ) => PagedChildBuilderDelegate<DbOnlineSubscriptionItem>(
    itemBuilder: (context, item, index) {
      if (_usesMovieCards) {
        final card = _movieSubscriptionCard(item, l, serverConfig, viewMode);
        return viewMode == MediaViewMode.landscape
            ? MediaLandscapeListItem(child: card)
            : card;
      }
      if (_section == 'blacklist') {
        return PagedSelectionItem<DbOnlineSubscriptionItem>(
          selection: _blacklistSelection,
          item: item,
          cardBuilder: (context, item, selected) => _subscriptionRow(
            item,
            l,
            serverConfig,
            selectedBlacklist: selected,
            blacklistIndex: index,
          ),
        );
      }
      return _subscriptionRow(item, l, serverConfig);
    },
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
          style: AppText.body(context),
        ),
      ),
    ),
    noMoreItemsIndicatorBuilder: (_) => const NoMoreContent(),
  );

  void _syncPagingQuery(String serverId) {
    final queryKey = '$serverId|$_section|$_keyword';
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
      if (_blacklistSelection.isActive) _blacklistSelection.exit();
      _resetPaging(invalidateRequests: false);
    });
  }

  void _reloadForQuery() {
    if (_blacklistSelection.isActive) _blacklistSelection.exit();
    final serverId = ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    _pagingQueryKey = '$serverId|$_section|$_keyword';
    _resetPaging();
  }

  void _resetPaging({bool invalidateRequests = true}) {
    if (!_pagingListenerAttached) return;
    if (invalidateRequests) {
      _requests.invalidate();
    }
    _lastPageComplete = false;
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
        kind: _section,
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
      _lastPageComplete = isLastPage;
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
    final subType = item.data['sub_type']?.toString() ?? '';
    return '${item.kind}:$subType:${item.id}';
  }

  void _switchSectionBySwipe(List<(String, String, IconData)> sections) {
    final distance = _horizontalDragDistance;
    _horizontalDragDistance = 0;
    if (distance.abs() < 60) return;

    final currentIndex = sections.indexWhere(
      (section) => section.$1 == _section,
    );
    final nextIndex = currentIndex + (distance < 0 ? 1 : -1);
    if (currentIndex < 0 || nextIndex < 0 || nextIndex >= sections.length) {
      return;
    }

    if (_section != sections[nextIndex].$1) _blacklistSelection.exit();
    setState(() {
      _section = sections[nextIndex].$1;
      _keyword = '';
      _searchController.clear();
    });
    _scrollSelectedSectionIntoView();
    _reloadForQuery();
  }

  void _scrollSelectedSectionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sectionPickerController.hasClients) return;
      final targetContext = _sectionKeys[_section]?.currentContext;
      if (targetContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  GlobalKey _sectionKey(String section) =>
      _sectionKeys.putIfAbsent(section, GlobalKey.new);

  List<(String, String, IconData)> _sections(
    AppL10n l,
    DbOnlineSubscriptionCapabilities capabilities,
  ) => [
    if (capabilities.database) ...[
      (
        'pending',
        l.dbOnlineSubscriptionPending,
        Icons.notifications_none_rounded,
      ),
      (
        'completed',
        l.dbOnlineSubscriptionCompleted,
        Icons.check_circle_outline_rounded,
      ),
    ],
    if (capabilities.onlineAccount)
      ('online', l.dbOnlineSubscriptionOnline, Icons.cloud_outlined),
    if (capabilities.database) ...[
      ('actor', l.dbOnlineSubscriptionActorTab, Icons.person_outline_rounded),
      ('series', l.dbOnlineSubscriptionComprehensive, Icons.layers_outlined),
      ('blacklist', l.dbOnlineSubscriptionBlacklist, Icons.block_rounded),
    ],
  ];

  Widget _header(
    AppL10n l,
    DbOnlineSubscriptionCapabilities? capabilities,
    AsyncValue<Map<String, dynamic>>? autoSync, {
    required bool hasBlockBelow,
  }) {
    final canManageOnlineSync =
        capabilities != null &&
        capabilities.database &&
        capabilities.onlineAccount;
    final actions = capabilities == null
        ? const <String>[]
        : switch (_section) {
            'pending' => <String>['run', 'preset', 'share'],
            'completed' => <String>['share'],
            'online' => <String>[
              if (canManageOnlineSync) 'sync-preset',
              if (canManageOnlineSync) 'autosync',
              if (canManageOnlineSync) 'sync',
              if (capabilities.database) 'share',
            ],
            'actor' => <String>['fetch-list', 'run', 'share'],
            'series' => <String>['fetch-list', 'run', 'prefix'],
            'blacklist' => <String>['blacklist-test', 'blacklist-add', 'share'],
            _ => const <String>[],
          };
    final autoSyncEnabled =
        autoSync?.when(
          data: (value) => value['enabled'] == true,
          loading: () => false,
          error: (_, _) => false,
        ) ??
        false;
    return PageHeader(
      eyebrow: l.tabYou.toUpperCase(),
      bottomPadding: hasBlockBelow
          ? PageHeader.toolbarTopGap
          : PageHeader.aboveListGap,
      title: Text(
        l.dbOnlineSubscriptionsManageTitle,
        style: AppText.pageTitle(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (capabilities != null && _showsViewModeToggle) ...[
            const MediaViewModePreferenceToggle(
              preferenceKey: _subscriptionViewModeKey,
            ),
            const SizedBox(width: 4),
          ],
          if (actions.isNotEmpty)
            HeaderMenuButton<String>(
              icon: Icons.more_vert_rounded,
              tooltip: l.dbOnlineSubscriptionTitle,
              menuWidth: 232,
              onSelected: (action) => _handleHeaderAction(action, l),
              entries: [
                for (final action in actions)
                  GlassMenuEntry<String>.action(
                    value: action,
                    builder: (context, selected, onTap) => GlassMenuRow(
                      icon: _headerActionIcon(action),
                      label: _headerActionLabel(action, l),
                      selected: selected,
                      trailing: action == 'autosync' && autoSyncEnabled
                          ? Text(
                              l.dbOnlineSubscriptionAutoSyncOn,
                              style: AppText.meta(context),
                            )
                          : null,
                      onTap: onTap,
                    ),
                  ),
              ],
            ),
          HeaderActionButton(
            tooltip: l.dbOnlineSubscriptionSettings,
            icon: Icons.settings,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsPage(showBackButton: true),
              ),
            ),
          ),
        ],
      ),
      alignTrailingToPadding: true,
    );
  }

  Widget _capabilityNotice(
    DbOnlineSubscriptionCapabilities capabilities,
    AppL10n l, {
    required bool hasToolbar,
  }) {
    final missing = <String>[
      if (!capabilities.database) l.dbOnlineSubscriptionFeatureRequiresDatabase,
      if (!capabilities.onlineAccount)
        l.dbOnlineSubscriptionFeatureRequiresOnlineAccount,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        hasToolbar ? PageHeader.toolbarTopGap : PageHeader.aboveListGap,
      ),
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

  Widget _sectionPicker(List<(String, String, IconData)> sections) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        controller: _sectionPickerController,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final section = sections[index];
          return MediaSectionTab(
            key: _sectionKey(section.$1),
            icon: section.$3,
            label: section.$2,
            selected: section.$1 == _section,
            onTap: () {
              if (_section != section.$1) _blacklistSelection.exit();
              setState(() {
                _section = section.$1;
                _keyword = '';
                _searchController.clear();
              });
              _scrollSelectedSectionIntoView();
              _reloadForQuery();
            },
          );
        },
      ),
    );
  }

  IconData _headerActionIcon(String action) => switch (action) {
    'preset' => Icons.tune_rounded,
    'run' => Icons.play_arrow_rounded,
    'share' => Icons.ios_share_rounded,
    'fetch-list' => Icons.cloud_download_outlined,
    'sync-preset' => Icons.settings_suggest_outlined,
    'autosync' => Icons.schedule_rounded,
    'sync' => Icons.sync_rounded,
    'prefix' => Icons.playlist_add_rounded,
    'blacklist-test' => Icons.rule_rounded,
    'blacklist-add' => Icons.add_circle_outline_rounded,
    _ => Icons.more_horiz_rounded,
  };

  String _headerActionLabel(String action, AppL10n l) => switch (action) {
    'preset' => l.dbOnlineSubscriptionPreset,
    'run' => l.dbOnlineSubscriptionRun,
    'share' => l.dbOnlineSubscriptionShare,
    'fetch-list' => l.dbOnlineSubscriptionFetchList,
    'sync-preset' => l.dbOnlineSubscriptionSyncPreset,
    'autosync' => l.dbOnlineSubscriptionAutoSync,
    'sync' => l.dbOnlineSubscriptionSync,
    'prefix' => l.dbOnlineSubscriptionAddPrefix,
    'blacklist-test' => l.dbOnlineSubscriptionBlacklistTest,
    'blacklist-add' => l.dbOnlineSubscriptionBlacklistAdd,
    _ => action,
  };

  Widget _searchField(AppL10n l) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        PageHeader.toolbarTopGap,
        22,
        PageHeader.aboveListGap,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: colors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) {
                  final keyword = value.trim();
                  if (_keyword == keyword) return;
                  setState(() => _keyword = keyword);
                  _reloadForQuery();
                },
                decoration: InputDecoration(
                  hintText: l.dbOnlineSubscriptionSearch,
                  hintStyle: TextStyle(
                    color: colors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: 16, color: colors.muted),
                tooltip: l.dbOnlineSubscriptionCancel,
                onPressed: () {
                  setState(() {
                    _keyword = '';
                    _searchController.clear();
                  });
                  _reloadForQuery();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionRow(
    DbOnlineSubscriptionItem item,
    AppL10n l,
    ServerConfig? serverConfig, {
    bool selectedBlacklist = false,
    int blacklistIndex = 0,
  }) {
    final videoCount = int.tryParse(item.data['video_count']?.toString() ?? '');
    final pendingCount = int.tryParse(
      item.data['pending_count']?.toString() ?? '',
    );
    final completedCount = int.tryParse(
      item.data['completed_count']?.toString() ?? '',
    );
    final skippedCount = int.tryParse(
      item.data['skipped_count']?.toString() ?? '',
    );
    final isActor = _section == 'actor';
    final isEntitySubscription = isActor || _section == 'series';
    final isBlacklist = _section == 'blacklist';
    final privacyScope = isActor ? PrivacyScope.actor : PrivacyScope.movie;
    final privacyId = isActor
        ? item.id
        : 'dbo:subscription:$_section:${_itemKey(item)}';
    final revealedProvider = isActor
        ? revealedActorsProvider
        : revealedMoviesProvider;
    final hidden =
        ref.watch(privacyShieldProvider) &&
        !ref.watch(revealedProvider).contains(privacyId);
    final inactive = isEntitySubscription && !item.active;
    final data = item.data;
    final blacklistRule =
        data['video_code']?.toString().trim().isNotEmpty == true
        ? data['video_code'].toString().trim()
        : item.title;
    final blacklistReason = data['reason']?.toString().trim() ?? '';
    final blacklistCreatedAt = _formatBlacklistCreatedAt(
      data['created_at']?.toString() ?? '',
    );
    final blacklistIsWildcard = blacklistRule.contains('*');
    final imageUrl = _resolveSubscriptionImage(serverConfig, [
      data['actor_avatar'],
      data['avatar_url'],
    ]);
    final selectingBlacklist = _section == 'blacklist' && _selectingBlacklist;
    final blacklistItemCount = _pagingController.itemList?.length ?? 0;
    final rowRadius = isBlacklist
        ? BorderRadius.vertical(
            top: blacklistIndex == 0 ? const Radius.circular(16) : Radius.zero,
            bottom:
                _lastPageComplete && blacklistIndex == blacklistItemCount - 1
                ? const Radius.circular(16)
                : Radius.zero,
          )
        : BorderRadius.circular(16);
    final entries = _rowMenuEntries(l);
    final stats = <Widget>[
      if (pendingCount != null && pendingCount > 0)
        entityStat(
          l.dbOnlineSubscriptionPending,
          pendingCount,
          Icons.notifications_active_outlined,
          const Color(0xFFEAB308),
          iconOnly: isEntitySubscription,
        ),
      if (completedCount != null && completedCount > 0)
        entityStat(
          l.dbOnlineSubscriptionCompleted,
          completedCount,
          Icons.check_circle_outline_rounded,
          const Color(0xFF22C55E),
          iconOnly: isEntitySubscription,
        ),
      if (skippedCount != null && skippedCount > 0)
        entityStat(
          l.dbOnlineSubscriptionSkipped,
          skippedCount,
          Icons.skip_next_rounded,
          const Color(0xFFEF4444),
          iconOnly: isEntitySubscription,
        ),
      if (videoCount != null)
        entityStat(
          '',
          videoCount,
          Icons.movie_outlined,
          appColors(context).muted,
        ),
    ];
    final flags = <Widget>[
      if (data['pre_download_mode'] == true)
        _subscriptionBadge(
          l.dbOnlineSubscriptionPreDownloadShort,
          const Color(0xFF00C878),
        ),
      if (data['wash_mode'] == true)
        _subscriptionBadge(
          l.dbOnlineSubscriptionWashShort,
          const Color(0xFFA855F7),
        ),
      if (data['quality']?.toString().toLowerCase() == 'hd')
        _subscriptionBadge('HD', const Color(0xFF00CFE8)),
      if (data['quality']?.toString().toLowerCase() == 'uhd')
        _subscriptionBadge('UHD', const Color(0xFF4A9EFF)),
      if (data['require_sub'] == true)
        _subscriptionBadge(
          l.dbOnlineSubscriptionSubtitleShort,
          const Color(0xFFFFC107),
        ),
      if (data['require_uncensored'] == true ||
          (isActor && data['actor_uncensored'] == true))
        _subscriptionBadge(
          l.dbOnlineSubscriptionUncensoredShort,
          const Color(0xFFFF0050),
        ),
    ];
    final card = Opacity(
      opacity: inactive ? 0.8 : 1,
      child: Container(
        decoration: isBlacklist ? null : settingsCardDecoration(context),
        child: Material(
          color: isBlacklist
              ? selectedBlacklist
                    ? appColors(context).accent.withValues(alpha: 0.07)
                    : appColors(context).surface
              : Colors.transparent,
          borderRadius: rowRadius,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectingBlacklist) ...[
                      Icon(
                        selectedBlacklist
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selectedBlacklist
                            ? appColors(context).accent
                            : appColors(context).muted,
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (isActor) ...[
                      PrivacyMask(
                        movieId: privacyId,
                        scope: privacyScope,
                        radius: 28,
                        child: _SubscriptionCardArtwork(
                          imageUrl: imageUrl,
                          isActor: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrivacyText(
                            movieId: privacyId,
                            scope: privacyScope,
                            text: item.title.isEmpty ? item.id : item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle(context),
                          ),
                          if (isBlacklist) ...[
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                _subscriptionBadge(
                                  data['entry_type'] == 'category'
                                      ? l.dbOnlineSubscriptionBlacklistCategory
                                      : l.dbOnlineSubscriptionBlacklistVideoCode,
                                  const Color(0xFF4A9EFF),
                                ),
                                if (blacklistIsWildcard)
                                  Tooltip(
                                    message: l.dbOnlineSubscriptionWildcard,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFC107,
                                        ).withValues(alpha: 0.2),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFFC107,
                                          ).withValues(alpha: 0.4),
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Icon(
                                        Icons.bolt_rounded,
                                        color: Color(0xFFFFC107),
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            PrivacyText(
                              movieId: privacyId,
                              scope: privacyScope,
                              text:
                                  '${l.dbOnlineSubscriptionRemark}: ${blacklistReason.isEmpty ? '—' : blacklistReason}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.meta(context),
                            ),
                            if (blacklistCreatedAt.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 12,
                                    color: appColors(context).muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${l.detailCreatedAt}: $blacklistCreatedAt',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.meta(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          if (stats.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Wrap(spacing: 6, runSpacing: 5, children: stats),
                          ],
                          if (flags.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Wrap(spacing: 4, runSpacing: 4, children: flags),
                          ],
                        ],
                      ),
                    ),
                    if (isEntitySubscription) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: appColors(context).muted,
                      ),
                    ],
                    if (isBlacklist && !selectingBlacklist)
                      IconButton(
                        tooltip: l.dbOnlineSubscriptionDelete,
                        onPressed: () => _removeBlacklistItem(item),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: appColors(context).danger,
                        ),
                      ),
                  ],
                ),
              ),
              if (inactive)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.pause_circle_outline_rounded,
                          size: 28,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (hidden) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(revealedProvider.notifier).reveal(privacyId),
        child: IgnorePointer(child: card),
      );
    }
    if (selectingBlacklist) {
      return Material(
        color: Colors.transparent,
        borderRadius: rowRadius,
        child: InkWell(
          borderRadius: rowRadius,
          onTap: () => _blacklistSelection.toggle(_blacklistItemKey(item)),
          child: card,
        ),
      );
    }
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

  Widget entityStat(
    String label,
    int count,
    IconData icon,
    Color color, {
    bool iconOnly = false,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            iconOnly || label.isEmpty ? '$count' : '$label $count',
            style: AppText.meta(
              context,
            ).copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return iconOnly ? Tooltip(message: '$label $count', child: badge) : badge;
  }

  Widget _movieSubscriptionCard(
    DbOnlineSubscriptionItem item,
    AppL10n l,
    ServerConfig? serverConfig,
    MediaViewMode viewMode,
  ) {
    final onlineCode = item.kind == 'online'
        ? item.data['number']?.toString().trim()
        : null;
    final privacyId = _subscriptionMoviePrivacyId(item);
    final hidden =
        ref.watch(privacyShieldProvider) &&
        !ref.watch(revealedMoviesProvider).contains(privacyId);
    final entries = hidden
        ? const <GlassMenuEntry<String>>[]
        : _rowMenuEntries(l);
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = _subscriptionMovieTile(
          item,
          l,
          serverConfig: serverConfig,
          viewMode: viewMode,
          code: onlineCode?.isNotEmpty == true ? onlineCode : item.id,
          width: constraints.maxWidth,
          onTap: entries.isEmpty
              ? () => _openSubscriptionMovieDetail(context, ref, item)
              : null,
        );
        if (entries.isEmpty) return card;
        return GlassMenuAnchor<String>(
          width: 232,
          entries: entries,
          onSelected: (action) => _handleItemAction(action, item, l),
          onAnchorTap: () => _openSubscriptionMovieDetail(context, ref, item),
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
        privacyId: item.kind == 'actor'
            ? item.id
            : 'dbo:subscription:$kind:${_itemKey(item)}',
        pendingCount: int.tryParse(
          item.data['pending_count']?.toString() ?? '',
        ),
        completedCount: int.tryParse(
          item.data['completed_count']?.toString() ?? '',
        ),
        skippedCount: int.tryParse(
          item.data['skipped_count']?.toString() ?? '',
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  List<GlassMenuEntry<String>> _rowMenuEntries(AppL10n l) {
    final danger = appColors(context).danger;
    if (_section == 'blacklist' && _selectingBlacklist) return const [];
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
    if (_section == 'blacklist') return const [];
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
      case 'run':
        if (_section == 'actor') {
          await _perform(() => _api.runActorSubscriptions());
        } else if (_section == 'series') {
          await _handleSeriesRun();
        } else {
          await _runAllVideoSubscriptions();
        }
        return;
      case 'fetch-list':
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
    required DbOnlineSubscriptionItem item,
  }) async {
    final saved = await showGlassSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => DbOnlineSubscriptionEditor(
        kind: kind,
        initial: item.data,
        l: AppL10n.of(context),
        isEdit: true,
      ),
    );
    if (saved == null) return;
    final api = _api;
    await _perform(() async {
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
    });
  }

  Future<void> _deleteSubscription(
    DbOnlineSubscriptionItem item,
    AppL10n l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.dbOnlineSubscriptionDelete),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.dbOnlineSubscriptionDeleteConfirm),
            const SizedBox(height: 8),
            Text(
              item.title.isEmpty ? item.id : item.title,
              style: TextStyle(
                color: appColors(context).text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
    if (confirmed != true || !mounted) return;
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

  Future<void> _checkOne(DbOnlineSubscriptionItem item) async {
    await _perform(() async {
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
  }

  Future<void> _updateQueueStatus(String code, String status) async {
    await _perform(
      () => _api.updateSubscriptionVideoStatus({
        'source_type': 'video',
        'video_code': code,
        'status': status,
      }),
    );
  }

  Future<void> _removeBlacklistItem(DbOnlineSubscriptionItem item) async {
    await _perform(
      () => _api.removeFromBlacklist(
        item.id,
        entryType: item.data['entry_type']?.toString() ?? 'video_code',
      ),
    );
  }

  Future<void> _deleteSelectedBlacklistItems(AppL10n l) async {
    final selectedIds = _blacklistSelection.selectedIds;
    final selected =
        (_pagingController.itemList ?? const <DbOnlineSubscriptionItem>[])
            .where((item) => selectedIds.contains(_blacklistItemKey(item)))
            .toList(growable: false);
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.dbOnlineSubscriptionDelete),
        content: Text(l.dbOnlineSubscriptionDeleteBlacklistConfirm),
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
    if (confirmed != true || !mounted) return;

    final deleted = await _perform(() async {
      for (final item in selected) {
        await _api.removeFromBlacklist(
          item.id,
          entryType: item.data['entry_type']?.toString() ?? 'video_code',
        );
      }
    });
    if (deleted && mounted) _blacklistSelection.exit();
  }

  Future<void> _runAllVideoSubscriptions() async {
    await _perform(() => _api.runVideoSubscriptionChecks());
  }

  Future<void> _checkAllEntitySubscriptions() async {
    await _perform(() async {
      if (_section == 'actor') {
        await _api.batchCheckActorSubscriptions();
      } else if (_section == 'series') {
        await _api.batchCheckSeriesSubscriptions(subType: 'all');
      }
    });
  }

  Future<void> _handleSeriesRun() async {
    await _perform(() async {
      await _api.runSeriesSubscriptions(subType: 'all');
    });
  }

  Future<bool> _perform(Future<dynamic> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        await _refreshList();
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).dbOnlineSubscriptionActionCompleted,
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(AppL10n.of(context), error));
      return false;
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
      ref.invalidate(
        dbOnlineSubscriptionAutoSyncProvider(
          ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '',
        ),
      );
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
    final selection = await showGlassSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) =>
          DbOnlineSubscriptionShareExportSheet(l: AppL10n.of(context)),
    );
    if (!mounted || selection == null) return;
    final seriesTypes = List<String>.from(
      selection['types'] as List? ?? const <String>[],
    );
    try {
      final response = _payloadMap(
        await _api.exportSubscriptionShare({
          'include_video': selection['video'] == true,
          'include_actor': selection['actor'] == true,
          'include_series_sub_types': seriesTypes,
        }),
      );
      if (!mounted) return;
      await showGlassSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DbOnlineSubscriptionShareResultSheet(
          shareText: response['share_text']?.toString() ?? '',
          summary: _mapValue(response['summary']),
          video: selection['video'] == true,
          actor: selection['actor'] == true,
          seriesTypes: seriesTypes.toSet(),
        ),
      );
    } catch (error) {
      if (mounted) _notify(localizedErrorMessage(AppL10n.of(context), error));
    }
  }

  Future<void> _importShare() async {
    final l = AppL10n.of(context);
    final controller = TextEditingController();
    final shareText = await showGlassSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.file_download_outlined,
              title: l.dbOnlineSubscriptionImport,
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                child: TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: l.dbOnlineSubscriptionShareText,
                  ),
                ),
              ),
            ),
            SheetActionBar.buttons(
              buttons: [
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  style: sheetPrimaryButtonStyle(context),
                  child: Text(l.dbOnlineSubscriptionImport),
                ),
              ],
            ),
          ],
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
    // 不传类型选择时后端会导入分享码中的全部订阅，避免旧实现硬编码
    // series/prefix 静默丢弃其余综合订阅类型。
    await _perform(
      () => _api.importSubscriptionShare({'share_text': shareText}),
    );
  }

  Future<void> _addSeriesPrefixes() async {
    final l = AppL10n.of(context);
    final controller = TextEditingController();
    final text = await showGlassSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.add_rounded,
              title: l.dbOnlineSubscriptionSeries,
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                child: TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: l.dbOnlineSubscriptionCode,
                  ),
                ),
              ),
            ),
            SheetActionBar.buttons(
              buttons: [
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  style: sheetPrimaryButtonStyle(context),
                  child: Text(l.dbOnlineSubscriptionSave),
                ),
              ],
            ),
          ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.block_rounded,
                title: l.dbOnlineSubscriptionBlacklistAdd,
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: entryType,
                        decoration: InputDecoration(
                          labelText: l.dbOnlineSubscriptionType,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'video_code',
                            child: Text(
                              l.dbOnlineSubscriptionBlacklistVideoCode,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'category',
                            child: Text(
                              l.dbOnlineSubscriptionBlacklistCategory,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => entryType = value);
                          }
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
                    ],
                  ),
                ),
              ),
              SheetActionBar.buttons(
                buttons: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context, {
                      'entry_type': entryType,
                      'rules': rulesController.text,
                      'reason': reasonController.text,
                    }),
                    style: sheetPrimaryButtonStyle(context),
                    child: Text(l.dbOnlineSubscriptionSave),
                  ),
                ],
              ),
            ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.rule_rounded,
                title: l.dbOnlineSubscriptionBlacklistTest,
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: entryType,
                        decoration: InputDecoration(
                          labelText: l.dbOnlineSubscriptionType,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'video_code',
                            child: Text(
                              l.dbOnlineSubscriptionBlacklistVideoCode,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'category',
                            child: Text(
                              l.dbOnlineSubscriptionBlacklistCategory,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => entryType = value);
                          }
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
                    ],
                  ),
                ),
              ),
              SheetActionBar.buttons(
                buttons: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context, {
                      'entry_type': entryType,
                      'codes': codesController.text,
                      'category_rule': categoryRuleController.text,
                    }),
                    style: sheetPrimaryButtonStyle(context),
                    child: Text(l.dbOnlineSubscriptionCheck),
                  ),
                ],
              ),
            ],
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

  Future<void> _refresh() => _refreshList();

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

  DbOnlineSubscriptionApi get _api =>
      ref.read(dboSubscriptionRepositoryProvider).api;

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _subscriptionMoviePrivacyId(DbOnlineSubscriptionItem item) {
  final videoId = item.data['video_id']?.toString().trim() ?? '';
  if (videoId.isNotEmpty) return videoId;
  // 在线订阅的 id 是影片 ID；本地队列的 id 通常为番号。
  if (item.kind == 'online') {
    final id = item.data['id']?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;
    final number = item.data['number']?.toString().trim() ?? '';
    if (number.isNotEmpty) return number;
  }
  return item.id;
}

void _openSubscriptionMovieDetail(
  BuildContext context,
  WidgetRef ref,
  DbOnlineSubscriptionItem item,
) {
  final privacyId = _subscriptionMoviePrivacyId(item);
  if (ref.read(privacyShieldProvider) &&
      !ref.read(revealedMoviesProvider).contains(privacyId)) {
    ref.read(revealedMoviesProvider.notifier).reveal(privacyId);
    return;
  }
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

({Widget? status, Widget? filters}) _subscriptionMovieBadges(
  DbOnlineSubscriptionItem item,
  AppL10n l,
) {
  final data = item.data;
  final status = item.status;
  final overdue = data['overdue'] == true;
  final matchedFlags =
      int.tryParse(data['matched_flags']?.toString() ?? '') ?? 0;
  Widget? statusBadge;

  if (overdue || status == 'pending' || status == 'skipped') {
    // 与封面角标/详情按钮共用同一状态映射，避免图标配色漂移。
    final style = dbOnlineSubscriptionStatusStyle(
      l,
      subscribed: true,
      status: status,
      overdue: overdue,
    );
    statusBadge = DbOnlineSubscriptionStatusBadge(
      label: style.label,
      color: style.color!,
      icon: style.icon,
    );
  } else if (status == 'completed') {
    statusBadge = Semantics(
      container: true,
      label: l.dbOnlineSubscriptionCompleted,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

  final filters = <Widget>[];
  if (data['wash_mode'] == true) {
    filters.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionWashShort,
        const Color(0xFFA855F7),
        matched: status == 'completed',
      ),
    );
  }
  if (data['pre_download_mode'] == true) {
    filters.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionPreDownloadShort,
        const Color(0xFF00C878),
        matched: matchedFlags != 0,
      ),
    );
  }
  final quality = data['quality']?.toString().toLowerCase();
  if (quality == 'hd') {
    filters.add(
      _subscriptionBadge(
        'HD',
        const Color(0xFF00CFE8),
        matched: (matchedFlags & 2) != 0,
      ),
    );
  } else if (quality == 'uhd') {
    filters.add(
      _subscriptionBadge(
        'UHD',
        const Color(0xFF4A9EFF),
        matched: (matchedFlags & 4) != 0,
      ),
    );
  }
  if (data['require_sub'] == true) {
    filters.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionSubtitleShort,
        const Color(0xFFFFC107),
        matched: (matchedFlags & 8) != 0,
      ),
    );
  }
  if (data['require_uncensored'] == true) {
    filters.add(
      _subscriptionBadge(
        l.dbOnlineSubscriptionUncensoredShort,
        const Color(0xFFFF0050),
        matched: (matchedFlags & 16) != 0,
      ),
    );
  }
  return (
    status: statusBadge,
    filters: filters.isEmpty
        ? null
        : Wrap(spacing: 3, runSpacing: 3, children: filters),
  );
}

/// 按订阅管理统一的视图模式渲染订阅影片：竖版、横版或紧凑列表。
Widget _subscriptionMovieTile(
  DbOnlineSubscriptionItem item,
  AppL10n l, {
  required ServerConfig? serverConfig,
  required MediaViewMode viewMode,
  required String? code,
  required double width,
  VoidCallback? onTap,
}) {
  final landscape = viewMode == MediaViewMode.landscape;
  final imageUrl = _resolveSubscriptionImage(
    serverConfig,
    landscape
        ? [
            item.data['cover_url'],
            item.data['thumb_url'],
            item.data['image_url'],
          ]
        : [
            item.data['thumb_url'],
            item.data['cover_url'],
            item.data['image_url'],
          ],
  );
  final meta = item.data['release_date']?.toString().trim() ?? '';
  final privacyId = _subscriptionMoviePrivacyId(item);
  final overlays = _subscriptionMovieBadges(item, l);
  if (viewMode == MediaViewMode.list) {
    // 已完成的绿点放在标题前，其余订阅状态角标仍留在标题下方。
    final completed =
        item.status == 'completed' && item.data['overdue'] != true;
    final badges = [if (!completed) ?overlays.status, ?overlays.filters];
    return CatalogListMovieCard(
      title: item.title,
      code: code,
      imageUrl: imageUrl,
      meta: meta,
      width: width,
      privacyId: privacyId,
      onTap: onTap,
      titleLeading: completed ? overlays.status : null,
      additional: badges.isEmpty
          ? null
          : Wrap(
              spacing: 5,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: badges,
            ),
    );
  }
  return CatalogMovieCard(
    title: item.title,
    code: code,
    imageUrl: imageUrl,
    meta: meta,
    width: width,
    privacyId: privacyId,
    onTap: onTap,
    landscape: landscape,
    coverTopLeftOverlay: overlays.status,
    coverBottomLeftOverlay: overlays.filters,
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

String _scheduleText(Object? raw) => raw is List
    ? raw.map((item) => item.toString()).join(', ')
    : raw?.toString() ?? '';

String _formatBlacklistCreatedAt(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

Map<String, dynamic> _payloadMap(Object? raw) {
  final root = _mapValue(raw);
  final data = _mapValue(root['data']);
  return data.isEmpty ? root : data;
}

Map<String, dynamic> _mapValue(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

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
