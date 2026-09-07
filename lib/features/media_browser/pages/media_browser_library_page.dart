import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/media_models.dart' as media_models;
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/media_browser/widgets/media_browser_selection.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/features/oh_my_media/movie_detail/entity_picker_sheet.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/preview/preview_player.dart';
import 'package:omm/shared/preview/preview_visibility.dart';
import 'package:omm/shared/drag_selection.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/paged_selection.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';

/// MediaBrowser 媒体库。
///
/// 顶部按 MediaBrowser Views（媒体库）切换，高级筛选支持类型、标签和年份；
/// 排序沿用 MediaBrowser 的 SortBy 语义，升降序切换与 DBO 影片库一致。
/// 长按进入拖选多选（与 OMM 影片库同构），批量收藏/已看标记。
class MediaBrowserLibraryPage extends ConsumerStatefulWidget {
  const MediaBrowserLibraryPage({
    super.key,
    this.initialViewId,
    this.personId,
    this.personName,
    this.genreId,
    this.genreName,
    this.tagId,
    this.tagName,
  });

  /// 从首页媒体库卡片进入时预选的库；null 保持默认的“全部库”模式。
  final String? initialViewId;

  /// 演员作品模式：按 PersonIds 过滤（Emby/Jellyfin），标题显示演员名。
  final String? personId;
  final String? personName;

  /// Emby/Jellyfin 类型作品模式：按 GenreIds 过滤，标题显示类型名。
  final String? genreId;
  final String? genreName;

  /// Stash 标签作品模式：按标签 ID 过滤，标题显示标签名。
  final String? tagId;
  final String? tagName;

  @override
  ConsumerState<MediaBrowserLibraryPage> createState() =>
      _MediaBrowserLibraryPageState();
}

class _MediaBrowserLibraryPageState
    extends ConsumerState<MediaBrowserLibraryPage> {
  static const _pageSize = 24;
  static const _viewModeKey = 'media_browser.library.view_mode.v1';
  static final _videoTypeOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'Movie', label: (l) => l.mediaBrowserTypeMovies),
      ];
  static final _musicTypeOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'MusicAlbum', label: (l) => l.mediaBrowserTypeAlbums),
        (value: 'Audio', label: (l) => l.mediaBrowserTypeSongs),
      ];
  static final _sortOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'DateCreated', label: (l) => l.mediaBrowserSortRecent),
        (value: 'SortName', label: (l) => l.mediaBrowserSortName),
        (value: 'ProductionYear', label: (l) => l.mediaBrowserSortYear),
        (value: 'CommunityRating', label: (l) => l.mediaBrowserSortRating),
      ];
  static final _feiniuSortOptions =
      <({String value, String Function(AppL10n l) label})>[
        (value: 'DateCreated', label: (l) => l.mediaBrowserSortRecent),
        (value: 'PremiereDate', label: (l) => l.sortByReleaseDate),
        (value: 'SortName', label: (l) => l.sortByTitle),
        (value: 'CommunityRating', label: (l) => l.sortByRating),
      ];

  final _requests = PagedRequestCoordinator();
  final _controller = PagingController<int, MediaBrowserItem>(firstPageKey: 0);
  final _scrollController = ScrollController();
  late final PagedSelectionController<MediaBrowserItem> _selection;
  Completer<void>? _refreshCompleter;
  String? _parentId;
  String? _collectionType;
  String _includeItemTypes = 'Movie';
  List<String> _genreFilter = const [];
  List<String> _tagFilter = const [];
  List<String> _yearFilter = const [];
  String _sortBy = 'DateCreated';
  String _sortOrder = 'Descending';
  MediaViewMode _viewMode = MediaViewMode.portrait;
  int _requestSerial = 0;
  bool _pageRequestTriggeredByRefresh = false;
  bool _batchBusy = false;
  String? _autoPreviewId;
  Timer? _autoPreviewDebounce;
  final _listViewportKey = GlobalKey();
  final _itemKeys = <String, GlobalKey>{};

  static List<({String value, String Function(AppL10n l) label})>
  _typeOptionsFor(String? collectionType) =>
      _isMusicCollectionType(collectionType)
      ? _musicTypeOptions
      : _videoTypeOptions;

  static bool _isMusicCollectionType(String? collectionType) =>
      (collectionType ?? '').trim().toLowerCase() == 'music';

  bool get _isMusicGrid => _isMusicCollectionType(_collectionType);

  bool get _isPersonMode => widget.personId?.trim().isNotEmpty == true;

  bool get _isGenreMode => widget.genreId?.trim().isNotEmpty == true;

  bool get _isTagMode => widget.tagId?.trim().isNotEmpty == true;

  bool get _isStash =>
      ref.read(mediaBrowserConfigProvider)?.project == ServerProject.stash;

  bool get _isFeiniu =>
      ref.read(mediaBrowserConfigProvider)?.project == ServerProject.feiniu;

  List<({String value, String Function(AppL10n l) label})>
  get _availableSortOptions => _isFeiniu ? _feiniuSortOptions : _sortOptions;

  String get _requestIncludeItemTypes => _isStash ? 'Movie' : _includeItemTypes;

  @override
  void initState() {
    super.initState();
    _parentId = widget.initialViewId;
    _selection = createMediaBrowserItemSelection();
    _selection.addModeListener(_onSelectionModeChanged);
    _viewMode = mediaViewModeFromPreference(
      ref.read(sharedPrefsProvider).getString(_viewModeKey),
    );
    _controller.addPageRequestListener(_fetchPage);
    _scrollController.addListener(_scheduleAutoPreviewUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAutoPreviewUpdate();
    });
  }

  @override
  void dispose() {
    _completeRefresh();
    _autoPreviewDebounce?.cancel();
    _requests.dispose();
    _controller.dispose();
    _scrollController.removeListener(_scheduleAutoPreviewUpdate);
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _onSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setViewMode(MediaViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(sharedPrefsProvider).setString(_viewModeKey, mode.name);
  }

  Future<void> _fetchPage(int startIndex) async {
    final pageRequest = _requests.begin(startIndex);
    if (pageRequest == null) return;
    final requestSerial = _requestSerial;
    try {
      if (startIndex == _controller.firstPageKey) {
        _pageRequestTriggeredByRefresh = true;
      }
      final result = await readMediaBrowserItemPage(
        ref,
        MediaBrowserItemPageRequest(
          serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
          query: media_models.MediaQuery(
            offset: startIndex,
            limit: _pageSize,
            sortBy: _sortBy,
            orderBy: _sortOrder == 'Ascending' ? 'asc' : 'desc',
            filters: {
              'parentId': _parentId,
              'includeItemTypes': _requestIncludeItemTypes,
              'recursive': true,
              if (_isPersonMode) 'personIds': widget.personId,
              if (_isGenreMode) 'genreIds': widget.genreId,
              if (_isTagMode) 'tagIds': widget.tagId,
              if (_genreFilter.isNotEmpty) 'genres': _genreFilter.join(','),
              if (_tagFilter.isNotEmpty) 'tags': _tagFilter.join(','),
              if (_yearFilter.isNotEmpty) 'years': _yearFilter.join(','),
            },
          ),
        ),
      );
      if (!pageRequest.isCurrent) return;
      if (!mounted || requestSerial != _requestSerial) return;

      final current = _controller.itemList ?? const <MediaBrowserItem>[];
      final seen = <String>{for (final item in current) item.id};
      final items = result.items
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      final isLastPage =
          !result.hasMore || result.items.length < _pageSize || items.isEmpty;
      if (isLastPage) {
        _controller.appendLastPage(items);
      } else {
        _controller.appendPage(items, startIndex + _pageSize);
      }
      _scheduleAutoPreviewUpdate();
      if (startIndex == 0) _completeRefresh();
    } catch (error) {
      if (!pageRequest.isCurrent) return;
      if (!mounted || requestSerial != _requestSerial) return;
      _controller.error = toApiException(error).message;
      if (startIndex == 0) _completeRefresh();
    } finally {
      pageRequest.finish();
    }
  }

  Future<void> _refresh() {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _refreshCompleter = completer;
    _requestSerial++;
    _refreshController();
    return completer.future;
  }

  void _refreshController() {
    _pageRequestTriggeredByRefresh = false;
    _requests.invalidate();
    refreshPagedController(
      controller: _controller,
      requests: _requests,
      loadPage: _fetchPage,
    );
    if (!_pageRequestTriggeredByRefresh) {
      unawaited(_fetchPage(_controller.firstPageKey));
    }
  }

  void _completeRefresh() {
    final completer = _refreshCompleter;
    _refreshCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _reloadWith({
    String? parentId,
    bool clearParent = false,
    String? includeItemTypes,
    List<String>? genres,
    List<String>? tags,
    List<String>? years,
    String? sortBy,
    String? sortOrder,
  }) {
    final nextParent = clearParent ? null : parentId ?? _parentId;
    final parentChanged = nextParent != _parentId;
    final nextCollectionType = _collectionTypeOf(nextParent);
    final nextTypeOptions = _typeOptionsFor(nextCollectionType);
    final nextTypes =
        includeItemTypes ??
        (_collectionTypeOf(_parentId) == nextCollectionType
            ? _includeItemTypes
            : nextTypeOptions.first.value);
    final nextTags = _normalizeFilterValues(
      tags ?? (parentChanged ? const [] : _tagFilter),
    );
    final nextGenres = _normalizeFilterValues(
      genres ?? (parentChanged ? const [] : _genreFilter),
    );
    final nextYears = _normalizeFilterValues(
      years ?? (parentChanged ? const [] : _yearFilter),
    );
    final nextSortBy = sortBy ?? _sortBy;
    final nextSortOrder = sortOrder ?? _sortOrder;
    if (nextParent == _parentId &&
        nextTypes == _includeItemTypes &&
        _sameFilterValues(nextGenres, _genreFilter) &&
        _sameFilterValues(nextTags, _tagFilter) &&
        _sameFilterValues(nextYears, _yearFilter) &&
        nextSortBy == _sortBy &&
        nextSortOrder == _sortOrder) {
      return;
    }
    setState(() {
      _parentId = nextParent;
      _collectionType = nextCollectionType;
      _includeItemTypes = nextTypes;
      _genreFilter = nextGenres;
      _tagFilter = nextTags;
      _yearFilter = nextYears;
      _sortBy = nextSortBy;
      _sortOrder = nextSortOrder;
      _autoPreviewId = null;
    });
    _autoPreviewDebounce?.cancel();
    _autoPreviewDebounce = null;
    _selection.exit();
    _requestSerial++;
    _refreshController();
  }

  void _scheduleAutoPreviewUpdate() {
    _autoPreviewDebounce?.cancel();
    _autoPreviewDebounce = Timer(const Duration(milliseconds: 240), () {
      _autoPreviewDebounce = null;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final next = _nextAutoPreviewId();
        if (next != _autoPreviewId) setState(() => _autoPreviewId = next);
      });
    });
  }

  String? _nextAutoPreviewId() {
    if (!_isStash) return null;
    final items = _controller.itemList ?? const <MediaBrowserItem>[];
    if (items.isEmpty) return null;
    final width = (MediaQuery.sizeOf(context).width - 44).clamp(
      1.0,
      double.infinity,
    );
    final coverHeight = width * 9 / 16;
    final actualIndex = previewItemIndexForViewportKeys(
      itemKeys: items.map((item) => _itemKeys[item.id]),
      viewportKey: _listViewportKey,
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
        );
    return index == null ? null : items[index].id;
  }

  /// 从已加载的 Views 里解析选中库的 collectionType；「全部库」为 null。
  String? _collectionTypeOf(String? parentId) {
    if (parentId == null) return null;
    final views = ref.read(mediaBrowserViewsProvider).value;
    for (final view in views ?? const <MediaBrowserItem>[]) {
      if (view.id == parentId) return view.collectionType;
    }
    return null;
  }

  /// Views 异步到达后补齐选中库的类型（如从首页音乐库卡片直接进入），
  /// 类型过滤不匹配时切到该库的默认选项。
  void _syncCollectionType(List<MediaBrowserItem> views) {
    if (_isPersonMode || _isGenreMode || _isTagMode) return;
    final next = _collectionTypeOf(_parentId);
    if (next == _collectionType) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || next != _collectionTypeOf(_parentId)) return;
      final options = _typeOptionsFor(next);
      final typesChanged = !options.any(
        (option) => option.value == _includeItemTypes,
      );
      setState(() {
        _collectionType = next;
        if (typesChanged) {
          _includeItemTypes = options.first.value;
        }
      });
      if (!typesChanged) return;
      _selection.exit();
      _requestSerial++;
      _refreshController();
    });
  }

  Future<void> _openItem(MediaBrowserItem item) async {
    await openMediaBrowserItem(context, ref, item);
    if (!mounted) return;
    // 详情页内可能切换了收藏/已看，返回时后台刷新已加载条目并保持滚动位置。
    await _refreshLoadedInBackground();
  }

  Future<void> _refreshLoadedInBackground() async {
    final parentId = _parentId;
    final includeItemTypes = _includeItemTypes;
    final sortBy = _sortBy;
    final sortOrder = _sortOrder;
    final genreFilter = _genreFilter;
    final tagFilter = _tagFilter;
    final yearFilter = _yearFilter;
    final refreshed = await refreshPagedListInBackground<MediaBrowserItem>(
      controller: _controller,
      requests: _requests,
      loadFirstPage: (limit) async {
        final result = await readMediaBrowserItemPage(
          ref,
          MediaBrowserItemPageRequest(
            serverId: ref.read(serverConfigProvider)?.activeServerId ?? '',
            query: media_models.MediaQuery(
              limit: limit,
              sortBy: sortBy,
              orderBy: sortOrder == 'Ascending' ? 'asc' : 'desc',
              filters: {
                'parentId': parentId,
                'includeItemTypes': _isStash ? 'Movie' : includeItemTypes,
                'recursive': true,
                if (_isPersonMode) 'personIds': widget.personId,
                if (_isGenreMode) 'genreIds': widget.genreId,
                if (_isTagMode) 'tagIds': widget.tagId,
                if (genreFilter.isNotEmpty) 'genres': genreFilter.join(','),
                if (tagFilter.isNotEmpty) 'tags': tagFilter.join(','),
                if (yearFilter.isNotEmpty) 'years': yearFilter.join(','),
              },
            ),
          ),
        );
        return PagedResult(
          items: result.items,
          totalCount: result.total,
          limit: limit,
          offset: 0,
        );
      },
    );
    if (mounted && refreshed) setState(() {});
  }

  /// 批量收藏/已看标记：循环/提示/退出选择由通用执行器处理，
  /// 页面只提供 busy 状态与原位刷新回调。
  Future<void> _applySelection({bool? favorite, bool? played}) {
    if (_batchBusy) return Future.value();
    return runMediaBrowserSelectionBatch(
      context: context,
      ref: ref,
      selection: _selection,
      refreshLoaded: _refreshLoadedInBackground,
      onBusyChanged: (busy) {
        if (mounted) setState(() => _batchBusy = busy);
      },
      favorite: favorite,
      played: played,
    );
  }

  Future<void> _openSortMenu(BuildContext context) async {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.sort_rounded,
                title: l.mediaBrowserSort,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                trailing: _LibraryOrderButton(
                  ascending: _sortOrder == 'Ascending',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(
                      sortOrder: _sortOrder == 'Ascending'
                          ? 'Descending'
                          : 'Ascending',
                    );
                  },
                ),
              ),
              for (final option in _availableSortOptions)
                ListTile(
                  dense: true,
                  title: Text(option.label(l)),
                  trailing: option.value == _sortBy
                      ? Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reloadWith(sortBy: option.value);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAdvancedFilter(BuildContext context) async {
    final localGenreOptions = _filterOptions(
      _controller.itemList?.expand((item) => item.genres) ?? const [],
      selected: _genreFilter,
    );
    var genreOptions = localGenreOptions;
    try {
      final remoteGenres = await ref
          .read(mediaBrowserMediaRepositoryProvider)
          .genres();
      if (remoteGenres.isNotEmpty) {
        genreOptions = _filterOptions(remoteGenres, selected: _genreFilter);
      }
    } catch (_) {
      // 服务端类型接口不可用时，仍允许使用当前已加载条目的类型筛选。
    }
    if (!context.mounted) return;

    final result = await showGlassSheet<_MediaBrowserAdvancedFilter>(
      context: context,
      builder: (_) => _MediaBrowserAdvancedFilterSheet(
        initial: _MediaBrowserAdvancedFilter(
          genres: _genreFilter,
          tags: _tagFilter,
          years: _yearFilter,
        ),
        genreOptions: genreOptions,
        tagOptions: _filterOptions(
          _controller.itemList?.expand((item) => item.tags) ?? const [],
          selected: _tagFilter,
        ),
        yearOptions: _yearOptions(selected: _yearFilter),
      ),
    );
    if (!mounted || result == null) return;
    _reloadWith(genres: result.genres, tags: result.tags, years: result.years);
  }

  List<String> _filterOptions(
    Iterable<String> values, {
    required Iterable<String> selected,
  }) {
    final options = <String>{
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim(),
    };
    for (final value in selected) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) options.add(normalized);
    }
    final sorted = options.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  List<String> _yearOptions({required Iterable<String> selected}) {
    final options = <int>{
      for (final item in _controller.itemList ?? const <MediaBrowserItem>[])
        if (item.productionYear != null && item.productionYear! > 0)
          item.productionYear!,
    };
    for (final value in selected) {
      final selectedValue = int.tryParse(value.trim());
      if (selectedValue != null && selectedValue > 0) {
        options.add(selectedValue);
      }
    }
    final sorted = options.toList()..sort((a, b) => b.compareTo(a));
    return [for (final year in sorted) '$year'];
  }

  List<String> _normalizeFilterValues(Iterable<String> values) {
    return <String>{
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim(),
    }.toList(growable: false);
  }

  bool _sameFilterValues(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final project = ref.watch(mediaBrowserConfigProvider)?.project;
    final isStash = project == ServerProject.stash;
    final isFeiniu = project == ServerProject.feiniu;
    final views = ref.watch(mediaBrowserViewsProvider);
    final urls = ref.watch(mediaBrowserServerUrlsProvider);
    views.maybeWhen(data: _syncCollectionType, orElse: () {});
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 6
        : width >= 820
        ? 5
        : width >= 600
        ? 4
        : 3;
    const horizontalPadding = 44.0;
    const spacing = 10.0;
    final itemWidth =
        ((width - horizontalPadding) - spacing * (crossAxisCount - 1)) /
        crossAxisCount;
    // 影视海报 2:3 + 双行文字；音乐方形封面按实际卡片高度反推比例。
    final cardAspectRatio = _isMusicGrid
        ? itemWidth / (itemWidth + 62)
        : MediaCardTemplate.gridChildAspectRatio;
    final isPortrait = _viewMode == MediaViewMode.portrait;
    final isLandscape = _viewMode == MediaViewMode.landscape;

    // 独立路由进入时页面自身就是 Material 根：无 Scaffold 会让 debug
    // 构建的文本出现黄色双下划线。底色由 FrostedBase 自绘，保持透明。
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PreviewScope(
        child: PagedSelectionPopScope<MediaBrowserItem>(
          selection: _selection,
          child: GlowBackground(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref
                                            .watch(mediaBrowserConfigProvider)
                                            ?.brandLabel ??
                                        '',
                                    style: AppText.eyebrow(context),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _isGenreMode
                                        ? (widget.genreName
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? widget.genreName!.trim()
                                              : AppL10n.of(
                                                  context,
                                                ).mediaBrowserGenres)
                                        : _isTagMode
                                        ? (widget.tagName?.trim().isNotEmpty ==
                                                  true
                                              ? widget.tagName!.trim()
                                              : AppL10n.of(
                                                  context,
                                                ).movieEditorTag)
                                        : _isPersonMode
                                        ? (widget.personName
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? widget.personName!.trim()
                                              : AppL10n.of(
                                                  context,
                                                ).mediaBrowserActorWorks)
                                        : AppL10n.of(
                                            context,
                                          ).mediaBrowserLibrariesTitle,
                                    style: AppText.pageTitle(context),
                                  ),
                                ],
                              ),
                            ),
                            _LibrarySortButton(
                              ascending: _sortOrder == 'Ascending',
                              onTap: () => _openSortMenu(context),
                            ),
                            const SizedBox(width: 8),
                            if (!isStash && !isFeiniu)
                              _LibraryFilterButton(
                                active:
                                    _genreFilter.isNotEmpty ||
                                    _tagFilter.isNotEmpty ||
                                    _yearFilter.isNotEmpty,
                                onTap: () => _openAdvancedFilter(context),
                              ),
                            if (!isStash) ...[
                              const SizedBox(width: 8),
                              MediaViewModeToggle(
                                mode: _viewMode,
                                onChanged: (mode) =>
                                    unawaited(_setViewMode(mode)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      views.maybeWhen(
                        data: (list) =>
                            _isPersonMode ||
                                _isTagMode ||
                                isStash ||
                                isFeiniu ||
                                list.isEmpty
                            ? const SizedBox.shrink()
                            : SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: list.length + 2,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _ViewChip(
                                        key: const ValueKey(
                                          'media-browser-all-libraries',
                                        ),
                                        privacyId: null,
                                        label: AppL10n.of(context).filterAll,
                                        selected:
                                            _parentId == null &&
                                            _includeItemTypes != 'BoxSet',
                                        onTap: () => _reloadWith(
                                          clearParent: true,
                                          includeItemTypes: 'Movie',
                                        ),
                                      );
                                    }
                                    if (index == list.length + 1) {
                                      return _ViewChip(
                                        key: const ValueKey(
                                          'media-browser-collections',
                                        ),
                                        privacyId: null,
                                        label: AppL10n.of(
                                          context,
                                        ).mediaBrowserTypeCollections,
                                        selected:
                                            _parentId == null &&
                                            _includeItemTypes == 'BoxSet',
                                        onTap: () => _reloadWith(
                                          clearParent: true,
                                          includeItemTypes: 'BoxSet',
                                        ),
                                      );
                                    }
                                    final view = list[index - 1];
                                    final selected =
                                        _includeItemTypes != 'BoxSet' &&
                                        view.id == _parentId;
                                    return _ViewChip(
                                      privacyId: view.id,
                                      label: view.name,
                                      selected: selected,
                                      onTap: () =>
                                          _reloadWith(parentId: view.id),
                                    );
                                  },
                                ),
                              ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: StatusBarScrollToTop(
                          scrollController: _scrollController,
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(mediaBrowserViewsProvider);
                              await _refresh();
                            },
                            child: PagedSelectionScope<MediaBrowserItem>(
                              selection: _selection,
                              scrollController: _scrollController,
                              layout: isStash || !isPortrait
                                  ? DragSelectionLayout.list
                                  : DragSelectionLayout.grid,
                              child: CustomScrollView(
                                key: _listViewportKey,
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                    ),
                                    sliver: urls.maybeWhen(
                                      data: (value) {
                                        final delegate = PagedChildBuilderDelegate<MediaBrowserItem>(
                                          itemBuilder: (context, item, index) =>
                                              isStash
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 14,
                                                      ),
                                                  child: StashSceneCard(
                                                    key: _itemKeys.putIfAbsent(
                                                      item.id,
                                                      GlobalKey.new,
                                                    ),
                                                    item: item,
                                                    urls: value,
                                                    width: width - 44,
                                                    autoPlayPreview:
                                                        item.id ==
                                                        _autoPreviewId,
                                                    onTap: () => unawaited(
                                                      _openItem(item),
                                                    ),
                                                  ),
                                                )
                                              : isLandscape
                                              ? mediaBrowserSelectableLandscapeItem(
                                                  selection: _selection,
                                                  item: item,
                                                  urls: value,
                                                  width: width - 44,
                                                  showFavoriteBadge: true,
                                                  selectionEnabled: true,
                                                  onOpen: _openItem,
                                                )
                                              : !isPortrait
                                              ? mediaBrowserSelectableListItem(
                                                  selection: _selection,
                                                  item: item,
                                                  urls: value,
                                                  onOpen: _openItem,
                                                )
                                              : mediaBrowserSelectableGridItem(
                                                  selection: _selection,
                                                  item: item,
                                                  urls: value,
                                                  width: itemWidth,
                                                  index: index,
                                                  square: _isMusicGrid,
                                                  showFavoriteBadge: true,
                                                  selectionEnabled: true,
                                                  onOpen: _openItem,
                                                ),
                                          firstPageProgressIndicatorBuilder:
                                              (_) => Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 56,
                                                ),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: colors.accent,
                                                      ),
                                                ),
                                              ),
                                          newPageProgressIndicatorBuilder:
                                              (_) => const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 18,
                                                ),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),
                                          firstPageErrorIndicatorBuilder: (_) =>
                                              ErrorView.list(
                                                retryLabel: AppL10n.of(
                                                  context,
                                                ).mediaBrowserRetry,
                                                message:
                                                    _controller.error
                                                        ?.toString() ??
                                                    AppL10n.of(
                                                      context,
                                                    ).loadFailed,
                                                onRetry: _controller
                                                    .retryLastFailedRequest,
                                              ),
                                          newPageErrorIndicatorBuilder: (_) =>
                                              PaginationRetry(
                                                onRetry: _controller
                                                    .retryLastFailedRequest,
                                              ),
                                          noItemsFoundIndicatorBuilder: (_) =>
                                              MediaBrowserEmptyPlaceholder(
                                                text: AppL10n.of(
                                                  context,
                                                ).mediaBrowserNoMatchingItems,
                                              ),
                                          noMoreItemsIndicatorBuilder: (_) =>
                                              const NoMoreContent(),
                                        );
                                        if (isStash) {
                                          return PagedSliverList<
                                            int,
                                            MediaBrowserItem
                                          >(
                                            pagingController: _controller,
                                            builderDelegate: delegate,
                                          );
                                        }
                                        if (!isPortrait) {
                                          return PagedSliverList<
                                            int,
                                            MediaBrowserItem
                                          >(
                                            pagingController: _controller,
                                            builderDelegate: delegate,
                                          );
                                        }
                                        return PagedSliverGrid<
                                          int,
                                          MediaBrowserItem
                                        >(
                                          pagingController: _controller,
                                          // 与 OMM 影片库一致：尾部提示整行跨列渲染，
                                          // 否则「没有更多内容」会被塞进单个网格单元。
                                          showNoMoreItemsIndicatorAsGridChild:
                                              false,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                childAspectRatio:
                                                    cardAspectRatio,
                                                mainAxisSpacing: 14,
                                                crossAxisSpacing: spacing,
                                              ),
                                          builderDelegate: delegate,
                                        );
                                      },
                                      loading: () => const SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      error: (error, _) => SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: ErrorView.list(
                                          retryLabel: AppL10n.of(
                                            context,
                                          ).mediaBrowserRetry,
                                          message: toApiException(
                                            error,
                                          ).message,
                                          onRetry: () => ref.invalidate(
                                            mediaBrowserServerUrlsProvider,
                                          ),
                                        ),
                                      ),
                                      orElse: () => const SliverToBoxAdapter(
                                        child: SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 120),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isStash)
                    PagedSelectionToolbar<MediaBrowserItem>(
                      selection: _selection,
                      onSelectAll: () => _selection.selectAll(
                        _controller.itemList ?? const <MediaBrowserItem>[],
                      ),
                      actionsBuilder: (selected) => [
                        EntityBatchAction(
                          icon: Icons.favorite_rounded,
                          label: AppL10n.of(context).mediaBrowserFavoriteAction,
                          onTap: selected.isEmpty || _batchBusy
                              ? null
                              : () =>
                                    unawaited(_applySelection(favorite: true)),
                        ),
                        EntityBatchAction(
                          icon: Icons.favorite_border_rounded,
                          label: AppL10n.of(
                            context,
                          ).mediaBrowserUnfavoriteAction,
                          color: colors.danger,
                          onTap: selected.isEmpty || _batchBusy
                              ? null
                              : () =>
                                    unawaited(_applySelection(favorite: false)),
                        ),
                        EntityBatchAction(
                          icon: Icons.task_alt_rounded,
                          label: AppL10n.of(context).mediaBrowserMarkWatched,
                          onTap: selected.isEmpty || _batchBusy
                              ? null
                              : () => unawaited(_applySelection(played: true)),
                        ),
                        EntityBatchAction(
                          icon: Icons.check_circle_outline_rounded,
                          label: AppL10n.of(context).mediaBrowserUnmarkWatched,
                          onTap: selected.isEmpty || _batchBusy
                              ? null
                              : () => unawaited(_applySelection(played: false)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    super.key,
    required this.privacyId,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 库 id · 隐私模式下库名按 PrivacyScope.library 域遮罩/揭开
  final String? privacyId;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : colors.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colors.accent.withValues(alpha: 0.5)
                : colors.cardBorder,
          ),
        ),
        child: privacyId == null
            ? Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? colors.accent : colors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            : PrivacyText(
                movieId: privacyId!,
                scope: PrivacyScope.library,
                text: label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? colors.accent : colors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _MediaBrowserAdvancedFilter {
  const _MediaBrowserAdvancedFilter({
    required this.genres,
    required this.tags,
    required this.years,
  });

  final List<String> genres;
  final List<String> tags;
  final List<String> years;
}

class _MediaBrowserAdvancedFilterSheet extends StatefulWidget {
  const _MediaBrowserAdvancedFilterSheet({
    required this.initial,
    required this.genreOptions,
    required this.tagOptions,
    required this.yearOptions,
  });

  final _MediaBrowserAdvancedFilter initial;
  final List<String> genreOptions;
  final List<String> tagOptions;
  final List<String> yearOptions;

  @override
  State<_MediaBrowserAdvancedFilterSheet> createState() =>
      _MediaBrowserAdvancedFilterSheetState();
}

class _MediaBrowserAdvancedFilterSheetState
    extends State<_MediaBrowserAdvancedFilterSheet> {
  late List<String> _selectedGenres;
  late List<String> _selectedTags;
  late List<String> _selectedYears;

  @override
  void initState() {
    super.initState();
    _selectedGenres = [...widget.initial.genres];
    _selectedTags = [...widget.initial.tags];
    _selectedYears = [...widget.initial.years];
  }

  void _reset() {
    setState(() {
      _selectedGenres = [];
      _selectedTags = [];
      _selectedYears = [];
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      _MediaBrowserAdvancedFilter(
        genres: [..._selectedGenres],
        tags: [..._selectedTags],
        years: [..._selectedYears],
      ),
    );
  }

  Future<List<String>?> _pickFilterValues({
    required String title,
    required IconData icon,
    required List<String> items,
    required List<String> selected,
  }) {
    return EntityPickerSheet.pickMultiOptions(
      context: context,
      title: title,
      icon: icon,
      options: items,
      selected: selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.filter_alt_outlined,
              title: l.mediaBrowserAdvancedFilter,
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              trailing: TextButton(onPressed: _reset, child: Text(l.reset)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MediaBrowserDropdownField(
                    key: const ValueKey('media-browser-filter-genre'),
                    values: _selectedGenres,
                    hint: l.mediaBrowserFilterGenresHint,
                    icon: Icons.category_outlined,
                    onTap: () async {
                      final values = await _pickFilterValues(
                        title: l.mediaBrowserFilterType,
                        icon: Icons.category_outlined,
                        items: widget.genreOptions,
                        selected: _selectedGenres,
                      );
                      if (mounted && values != null) {
                        setState(() => _selectedGenres = values);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _MediaBrowserDropdownField(
                    key: const ValueKey('media-browser-filter-tag'),
                    values: _selectedTags,
                    hint: l.mediaBrowserFilterTagsHint,
                    icon: Icons.label_outline_rounded,
                    onTap: () async {
                      final values = await _pickFilterValues(
                        title: l.movieEditorTag,
                        icon: Icons.label_outline_rounded,
                        items: widget.tagOptions,
                        selected: _selectedTags,
                      );
                      if (mounted && values != null) {
                        setState(() => _selectedTags = values);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _MediaBrowserDropdownField(
                    key: const ValueKey('media-browser-filter-year'),
                    values: _selectedYears,
                    hint: l.mediaBrowserFilterYearHint,
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      final values = await _pickFilterValues(
                        title: l.mediaBrowserFilterYear,
                        icon: Icons.calendar_today_outlined,
                        items: widget.yearOptions,
                        selected: _selectedYears,
                      );
                      if (mounted && values != null) {
                        setState(() => _selectedYears = values);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(l.confirm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaBrowserDropdownField extends StatelessWidget {
  const _MediaBrowserDropdownField({
    super.key,
    required this.values,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final List<String> values;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final hasValue = values.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: sheetInputDecoration(
          context,
          isDense: true,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more_rounded),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: hasValue
            ? Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final value in values.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: colors.accent,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  if (values.length > 3)
                    Text(
                      '+${values.length - 3}',
                      style: TextStyle(
                        color: colors.muted,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              )
            : Text(hint, style: TextStyle(color: colors.muted)),
      ),
    );
  }
}

class _LibraryFilterButton extends StatelessWidget {
  const _LibraryFilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.accent.withValues(alpha: 0.15) : colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? colors.accent.withValues(alpha: 0.5)
                : colors.cardBorder,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          size: 15,
          color: active ? colors.accent : colors.muted,
        ),
      ),
    );
  }
}

class _LibrarySortButton extends StatelessWidget {
  const _LibrarySortButton({required this.ascending, required this.onTap});

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 15, color: colors.muted),
            const SizedBox(width: 5),
            Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: colors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryOrderButton extends StatelessWidget {
  const _LibraryOrderButton({required this.ascending, required this.onTap});

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: colors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              ascending
                  ? AppL10n.of(context).mediaBrowserAscending
                  : AppL10n.of(context).mediaBrowserDescending,
              style: TextStyle(
                color: colors.accent,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
