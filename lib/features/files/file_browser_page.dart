import 'file_image_thumbnail.dart';
import 'file_thumbnail_loader.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_codes.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_log_store.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/common/source_descriptor.dart';
import '../../core/sources/common/source_exception.dart';
import '../../core/sources/common/source_id.dart';
import '../../core/sources/files/file_capabilities.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_operation.dart';
import '../../core/sources/files/file_playback_progress.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/files/file_source_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/drag_selection.dart';
import '../../shared/entity_batch_toolbar.dart';
import '../../shared/edge_swipe_back.dart';
import '../../shared/floating_tab_bar.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import '../../shared/selection_controller.dart';
import '../../shared/sheet_controls.dart';
import '../../shared/swipe_actions.dart';
import '../../shared/single_flight_gate.dart';
import '../../shared/localized_error_message.dart';
import '../player/common/playback_engine.dart';
import '../player/audio/audio_player_page.dart';
import '../player/video/player_engine_picker.dart';
import '../player/video/video_player_page.dart';
import '../player/common/player_queue.dart';
import '../player/video/video_player_session_factory.dart';
import '../player/common/player_settings.dart';
import '../oh_my_media/movie_detail/movie_detail_media_viewers.dart'
    show showImageLightbox;
import '../settings/server_selection_page.dart';
import '../settings/settings_common.dart';
import '../cache/music_cache.dart';
import '../text_editor/text_editor_page.dart';
import 'file_navigation.dart';
import 'file_browser_preferences.dart';
import 'file_entry_icons.dart';
import 'file_favorites.dart';
import 'file_favorites_page.dart';
import 'file_move_start_settings.dart';
import 'file_image_preview_settings.dart';
import '../player/audio/file_audio_metadata_session.dart';
import 'file_playback_engine.dart';
import 'file_playback_proxy.dart';
import 'file_playback_queue_builder.dart';

part 'file_batch_rename_sheet.dart';

part 'file_browser_widgets.dart';
part 'file_move_destination_page.dart';

part 'file_browser_operations.dart';

part 'file_browser_preview.dart';

const _maxFallbackTextBytes = 5 * 1024 * 1024;

enum _BrowserMenuAction {
  forceRefresh,
  createDirectory,
  upload,
  enterSelection,
  toggleHidden,
  sortName,
  sortDate,
  sortSize,
  sortCategory,
}

enum _BatchRenameMode { replace, add }

class _BatchRenameDraft {
  const _BatchRenameDraft({
    required this.mode,
    required this.search,
    required this.replacement,
    required this.addText,
    required this.addBefore,
  });

  final _BatchRenameMode mode;
  final String search;
  final String replacement;
  final String addText;
  final bool addBefore;
}

class FileBrowserPage extends ConsumerStatefulWidget {
  const FileBrowserPage({
    super.key,
    required this.serverId,
    required this.sourceId,
    this.initialPath = '',
    this.directoryPicker = false,
    this.autoOpenFile,
    this.onDirectorySubmitted,
    this.onDirectoryPickerCancelled,
  });

  final String serverId;
  final SourceId sourceId;
  final String initialPath;

  /// 目录选择器模式：只选目录，用于移动文件等场景。
  final bool directoryPicker;

  /// 首次目录加载完成后自动打开的文件（从收藏列表跳转打开时使用）。
  final FileEntry? autoOpenFile;

  /// 目录选择器提交目录时的回调。传入后由外层选择器负责关闭页面。
  final ValueChanged<FilePath>? onDirectorySubmitted;

  /// 目录选择器根页面取消时的回调。用于嵌套在带底部导航的选择器中。
  final VoidCallback? onDirectoryPickerCancelled;

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  void _updateViewState(VoidCallback update) => setState(update);

  late String _path = widget.initialPath;
  late final FileOperationTracker _tracker;
  late final FilePlaybackProgressRepository _filePlaybackProgress;
  late final SelectionController<String> _selection;
  final ScrollController _scrollController = ScrollController();
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  FileThumbnailLoader _thumbnailLoader = FileThumbnailLoader();
  StreamSubscription<FileOperation>? _operationSubscription;
  Timer? _operationDismissTimer;
  FileOperation? _operation;
  bool _busy = false;
  final _fileOpenGate = SingleFlightGate();
  FileEntry? _pendingAutoOpen;

  AppL10n get _l10n => AppL10n.of(context);

  FileBrowserPreferences get _browserPreferences =>
      ref.read(fileBrowserPreferencesProvider(widget.serverId));

  bool get _showHiddenFiles => _browserPreferences.showHiddenFiles;
  FileBrowserSortField get _sortField => _browserPreferences.sortField;
  bool get _sortAscending => _browserPreferences.sortAscending;
  bool get _selectionMode => _selection.isActive;
  Set<String> get _selectedKeys => _selection.selected;

  FileDirectoryRequest get _request => FileDirectoryRequest(
    serverId: widget.serverId,
    sourceId: widget.sourceId,
    path: _path,
  );

  bool get _isAtRoot => isRootFilePath(_path);

  @override
  void initState() {
    super.initState();
    _pendingAutoOpen = widget.autoOpenFile;
    _tracker = FileOperationTracker(sourceId: widget.sourceId);
    _selection = SelectionController<String>();
    _selection.activeListenable.addListener(_handleSelectionModeChanged);
    _filePlaybackProgress = FilePlaybackProgressRepository(
      ref.read(sharedPrefsProvider),
    );
    _scrollController.addListener(_closeSwipeOnScroll);
    _operationSubscription = _tracker.events.listen(_handleOperationEvent);
  }

  @override
  void dispose() {
    _operationDismissTimer?.cancel();
    unawaited(_operationSubscription?.cancel());
    _scrollController.removeListener(_closeSwipeOnScroll);
    _scrollController.dispose();
    _openSwipe.dispose();
    _selection.dispose();
    _thumbnailLoader.dispose();
    unawaited(_tracker.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(fileDirectoryProvider(_request));
    final source = ref.watch(fileSourceProvider(widget.sourceId.value));
    final browserPreferences = ref.watch(
      fileBrowserPreferencesProvider(widget.serverId),
    );
    final imagePreviewEnabled = ref.watch(fileImagePreviewProvider);
    final favorites = ref.watch(fileFavoritesProvider(widget.serverId));
    final currentDirectoryPath = listing.hasValue
        ? listing.requireValue.currentPath
        : FilePath(sourceId: widget.sourceId, value: _path);
    final visibleEntries = listing.hasValue
        ? _visibleEntries(listing.requireValue)
        : const <FileEntry>[];
    // 文件浏览页使用紧凑导航栏，把垂直空间留给文件列表。
    final l = _l10n;
    final descriptor = source.asData?.value?.descriptor;
    final config = ref.watch(serverConfigProvider);
    String? serverName;
    for (final server in config?.servers ?? const []) {
      if (server.id == widget.serverId) {
        serverName = server.name;
        break;
      }
    }
    final page = PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: appColors(context).bg,
        body: GlowBackground(
          child: SafeArea(
            bottom: false,
            child: SettingsFixedHeaderLayout(
              scrollController: _scrollController,
              header: ValueListenableBuilder<Set<String>>(
                valueListenable: _selection.selectedListenable,
                builder: (context, selectedKeys, _) {
                  final batchActions = _batchActions(visibleEntries);
                  final headerTitle = widget.directoryPicker
                      ? l.fileSelectTargetDirectory
                      : _selectionMode
                      ? l.fileSelectedItems(selectedKeys.length)
                      : (serverName ?? descriptor?.name ?? l.fileListTitle);
                  final headerTrailing = widget.directoryPicker
                      ? IconButton(
                          tooltip: l.fileSelectThisDirectory,
                          onPressed: _busy
                              ? null
                              : () => _submitDirectory(currentDirectoryPath),
                          icon: const Icon(Icons.check),
                        )
                      : _selectionMode
                      ? PopupMenuButton<int>(
                          tooltip: l.fileBatchActions,
                          onSelected: (index) =>
                              batchActions[index].onTap?.call(),
                          itemBuilder: (_) => [
                            for (var i = 0; i < batchActions.length; i++)
                              PopupMenuItem<int>(
                                value: i,
                                enabled: batchActions[i].onTap != null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(batchActions[i].icon, size: 20),
                                    const SizedBox(width: 12),
                                    Text(batchActions[i].label),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : PopupMenuButton<_BrowserMenuAction>(
                          enabled: !_busy,
                          tooltip: l.fileMoreActions,
                          onSelected: (action) =>
                              _handleMenuAction(action, currentDirectoryPath),
                          itemBuilder: (_) => [
                            // 强制刷新只对 OpenList 有意义：其服务端有目录缓存需要
                            // 绕过；SMB/WebDAV 每次列目录都是实时读取，无需该入口。
                            if (descriptor?.kind == SourceKind.openList)
                              _menuItem(
                                _BrowserMenuAction.forceRefresh,
                                Icons.refresh,
                                l.fileForceRefresh,
                              ),
                            _menuItem(
                              _BrowserMenuAction.createDirectory,
                              Icons.create_new_folder_outlined,
                              l.fileCreateDirectory,
                            ),
                            _menuItem(
                              _BrowserMenuAction.upload,
                              Icons.upload_file_outlined,
                              l.fileUpload,
                            ),
                            _menuItem(
                              _BrowserMenuAction.enterSelection,
                              Icons.checklist_outlined,
                              l.fileSelect,
                            ),
                            CheckedPopupMenuItem<_BrowserMenuAction>(
                              value: _BrowserMenuAction.toggleHidden,
                              checked: browserPreferences.showHiddenFiles,
                              child: Text(l.fileShowHidden),
                            ),
                            CheckedPopupMenuItem<_BrowserMenuAction>(
                              value: _BrowserMenuAction.sortName,
                              checked:
                                  browserPreferences.sortField ==
                                  FileBrowserSortField.name,
                              child: Text(
                                _sortMenuLabel(
                                  l.fileSortName,
                                  FileBrowserSortField.name,
                                ),
                              ),
                            ),
                            CheckedPopupMenuItem<_BrowserMenuAction>(
                              value: _BrowserMenuAction.sortDate,
                              checked:
                                  browserPreferences.sortField ==
                                  FileBrowserSortField.date,
                              child: Text(
                                _sortMenuLabel(
                                  l.fileSortDate,
                                  FileBrowserSortField.date,
                                ),
                              ),
                            ),
                            CheckedPopupMenuItem<_BrowserMenuAction>(
                              value: _BrowserMenuAction.sortSize,
                              checked:
                                  browserPreferences.sortField ==
                                  FileBrowserSortField.size,
                              child: Text(
                                _sortMenuLabel(
                                  l.fileSortSize,
                                  FileBrowserSortField.size,
                                ),
                              ),
                            ),
                            CheckedPopupMenuItem<_BrowserMenuAction>(
                              value: _BrowserMenuAction.sortCategory,
                              checked:
                                  browserPreferences.sortField ==
                                  FileBrowserSortField.category,
                              child: Text(
                                _sortMenuLabel(
                                  l.fileSortCategory,
                                  FileBrowserSortField.category,
                                ),
                              ),
                            ),
                          ],
                        );
                  return _FileBrowserTopBar(
                    title: headerTitle,
                    backIcon: _selectionMode ? Icons.close : Icons.arrow_back,
                    backTooltip: _selectionMode
                        ? l.fileExitSelection
                        : widget.directoryPicker
                        ? (_isAtRoot ? l.fileCancelPicker : l.fileBackToParent)
                        : (_isAtRoot
                              ? l.fileBackToServers
                              : l.fileBackToParent),
                    onBackPressed: _selectionMode
                        ? _exitSelection
                        : widget.directoryPicker
                        ? _cancelDirectoryPicker
                        : _handleBack,
                    trailing: headerTrailing,
                  );
                },
              ),
              body: Column(
                children: [
                  Expanded(
                    child: listing.when(
                      data: (value) =>
                          _buildListing(value, imagePreviewEnabled, favorites),
                      loading: () => Padding(
                        padding: EdgeInsets.only(
                          bottom: floatingTabBarContentBottomInset(context),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: EdgeInsets.only(
                          bottom: floatingTabBarContentBottomInset(context),
                        ),
                        child: _BrowserError(
                          message: localizedErrorMessage(_l10n, error),
                          onRetry: () => unawaited(_refresh()),
                        ),
                      ),
                    ),
                  ),
                  if (_operation != null)
                    _FileOperationBanner(
                      operation: _operation!,
                      onCancel: _cancelOperation,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // 正常应用入口由上层服务器 MaterialPage 提供 OMM 相同的自适应 pop。
    // 直接作为独立 home 使用时没有父页面，只保留兼容手势以避免该嵌入
    // 场景完全失去返回能力；它不会参与应用内服务器/目录页面的手势。
    if (ServerNavigationScope.of(context)) return page;
    return EdgeSwipeBack(
      onTriggered: () => unawaited(_handleLegacyEdgeSwipeBack()),
      child: page,
    );
  }

  Future<void> _returnToServerSelector() async {
    if (FileManagerNavigationScope.requestServerSelection(context)) return;
    ServerSelectionPage.requestReturn(context);
  }

  void _handleBack() {
    if (widget.directoryPicker) {
      _cancelDirectoryPicker();
      return;
    }
    if (_isAtRoot) {
      unawaited(_returnToServerSelector());
    } else {
      unawaited(_popToParent());
    }
  }

  void _cancelDirectoryPicker() {
    final onCancelled = widget.onDirectoryPickerCancelled;
    if (onCancelled != null) {
      onCancelled();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  void _submitDirectory(FilePath path) {
    final onSubmitted = widget.onDirectorySubmitted;
    if (onSubmitted != null) {
      onSubmitted(path);
      return;
    }
    Navigator.of(context).pop(path);
  }

  PopupMenuItem<_BrowserMenuAction> _menuItem(
    _BrowserMenuAction action,
    IconData icon,
    String label,
  ) => PopupMenuItem<_BrowserMenuAction>(
    value: action,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    ),
  );

  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  void _handleSelectionModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openDirectory(String path) async {
    _openSwipe.value = null;
    final selectedPath = await Navigator.of(context).push<FilePath>(
      MaterialPageRoute<FilePath>(
        settings: RouteSettings(name: _routeName(path)),
        allowSnapshotting: false,
        builder: (_) => FileBrowserPage(
          serverId: widget.serverId,
          sourceId: widget.sourceId,
          initialPath: path,
          directoryPicker: widget.directoryPicker,
          onDirectorySubmitted: widget.onDirectorySubmitted,
        ),
      ),
    );
    if (mounted && widget.directoryPicker && selectedPath != null) {
      Navigator.of(context).pop(selectedPath);
    }
  }

  Future<void> _popToParent() async {
    _openSwipe.value = null;
    if (await Navigator.of(context).maybePop()) return;
    // 兼容直接作为根路由打开的深层页面；正常入口始终走上面的页面栈。
    final parent = _parent(_path);
    if (parent == _path) return;
    if (mounted) {
      setState(() => _path = parent);
      _selection.exit();
    }
  }

  /// 面包屑跳转。目标层级可能不在当前导航栈中（目录选择器从当前目录
  /// 开始时，点起始目录之上的层级；或独立嵌入的深层页面），popUntil
  /// 一路弹到栈底兜底（isFirst / 文件管理根 / 选择器栈底），避免把
  /// 导航栈弹空。
  Future<void> _popToPath(String path) async {
    _openSwipe.value = null;
    if (path == _path) return;
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context);
    final rootRouteName = _routeName('');
    if (isRootFilePath(path)) {
      if (widget.directoryPicker) {
        if (currentRoute != null &&
            currentRoute.isFirst &&
            currentRoute.settings.name == rootRouteName) {
          setState(() => _path = '');
          _selection.exit();
          return;
        }
        // 选择器从当前目录开始时，选择器首页本身就叫根路由名，需排除
        // 当前页，「根目录」才能退出选择器回到浏览根页。
        navigator.popUntil(
          (route) =>
              (route.settings.name == rootRouteName &&
                  !identical(route, currentRoute)) ||
              route.isFirst,
        );
        return;
      }
      navigator.popUntil(
        (route) =>
            route.settings.name == fileManagerRootRouteName || route.isFirst,
      );
      return;
    }
    final target = _routeName(path);
    navigator.popUntil(
      (route) =>
          route.settings.name == target ||
          route.settings.name == fileManagerRootRouteName ||
          route.isFirst,
    );
  }

  void _startSelectionSweep(String key, bool selected) {
    _selection.enter();
    _selection.setSelected(key, selected);
  }

  void _applySelectionSweep(String key, bool selected) {
    _selection.setSelected(key, selected);
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedKeys.isEmpty) _exitSelection();
  }

  void _toggleSelect(FileEntry entry) => _selection.toggle(entry.stableKey);

  void _enterSelectionMode() {
    if (_busy || _selectionMode) return;
    _selection.enter();
  }

  void _exitSelection() {
    _openSwipe.value = null;
    if (!mounted) return;
    _selection.exit();
  }

  void _clearSelection() => _selection.clear();

  void _selectAllVisible(List<FileEntry> entries) {
    if (entries.isEmpty) return;
    _selection.selectAll(entries.map((entry) => entry.stableKey));
  }

  Future<void> _handleMenuAction(
    _BrowserMenuAction action,
    FilePath currentPath,
  ) async {
    switch (action) {
      case _BrowserMenuAction.forceRefresh:
        setState(() => _busy = true);
        try {
          await _refresh(force: true);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case _BrowserMenuAction.createDirectory:
        await _createDirectory(currentPath);
      case _BrowserMenuAction.upload:
        await _upload(currentPath);
      case _BrowserMenuAction.enterSelection:
        _enterSelectionMode();
      case _BrowserMenuAction.toggleHidden:
        if (_selectionMode) _exitSelection();
        ref
            .read(fileBrowserPreferencesProvider(widget.serverId).notifier)
            .toggleHiddenFiles();
      case _BrowserMenuAction.sortName:
        _setSort(FileBrowserSortField.name);
      case _BrowserMenuAction.sortDate:
        _setSort(FileBrowserSortField.date);
      case _BrowserMenuAction.sortSize:
        _setSort(FileBrowserSortField.size);
      case _BrowserMenuAction.sortCategory:
        _setSort(FileBrowserSortField.category);
    }
  }

  void _setSort(FileBrowserSortField field) {
    ref
        .read(fileBrowserPreferencesProvider(widget.serverId).notifier)
        .setSort(field);
  }

  String _sortMenuLabel(String label, FileBrowserSortField field) {
    final l = _l10n;
    if (_sortField != field) return l.fileSortBy(label);
    return _sortAscending ? l.fileSortByAsc(label) : l.fileSortByDesc(label);
  }

  List<FileEntry> _visibleEntries(DirectoryListing listing) {
    final entries = listing.entries
        .where((entry) => _showHiddenFiles || !_isHiddenEntry(entry))
        .toList();
    entries.sort(_compareEntries);
    return entries;
  }

  int _compareEntries(FileEntry a, FileEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;

    final result = switch (_sortField) {
      FileBrowserSortField.name => _compareNames(a.name, b.name),
      FileBrowserSortField.date => _compareDates(
        a.modifiedAt ?? a.createdAt,
        b.modifiedAt ?? b.createdAt,
      ),
      FileBrowserSortField.size => (a.size ?? -1).compareTo(b.size ?? -1),
      FileBrowserSortField.category => _entryCategory(
        a,
      ).compareTo(_entryCategory(b)),
    };
    if (result != 0) return _sortAscending ? result : -result;
    return _compareNames(a.name, b.name);
  }

  int _compareNames(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  String _entryCategory(FileEntry entry) {
    final mimeType = entry.mimeType?.trim().toLowerCase();
    if (mimeType != null && mimeType.isNotEmpty) return mimeType;
    final dot = entry.name.lastIndexOf('.');
    return dot > 0 ? entry.name.substring(dot + 1).toLowerCase() : '';
  }

  bool _isHiddenEntry(FileEntry entry) =>
      entry.isHidden || entry.name.startsWith('.');

  Widget _buildListing(
    DirectoryListing listing,
    bool imagePreviewEnabled,
    List<FileFavorite> favorites,
  ) {
    _scheduleAutoOpenOnce(listing);
    final entries = _visibleEntries(listing);
    final favoriteKeys = favorites
        .map((favorite) => favorite.stableKey)
        .toSet();
    return Column(
      children: [
        if (listing.breadcrumbs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // reverse 让初始位置落在内容末尾：路径过长时默认展示最新的
            // 最深层级，无需用户手动滑动。
            reverse: true,
            padding: const EdgeInsets.fromLTRB(22, 2, 22, 2),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width - 44,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < listing.breadcrumbs.length; i++) ...[
                      if (i > 0) const Icon(Icons.chevron_right, size: 18),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _busy
                            ? null
                            : () => unawaited(
                                _popToPath(listing.breadcrumbs[i].value),
                              ),
                        child: Text(
                          i == 0
                              ? _l10n.fileRootDirectory
                              : _pathName(listing.breadcrumbs[i].value),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: DragSelectionScope<String>(
              scrollController: _scrollController,
              selectionLayout: DragSelectionLayout.list,
              isSelected: _selectedKeys.contains,
              onSelectionStart: _startSelectionSweep,
              onSelectionChanged: _applySelectionSweep,
              onSelectionEnd: _finishSelectionSweep,
              selectionMode: _selectionMode,
              enabled: !_busy,
              child: entries.isEmpty
                  ? ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: floatingTabBarContentBottomInset(context),
                      ),
                      children: [
                        const SizedBox(height: 140),
                        Center(child: Text(_l10n.fileEmptyDirectory)),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: floatingTabBarContentBottomInset(context),
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: _selection.selectedListenable,
                            builder: (_, __, ___) => _entryTile(
                              entries[index],
                              index,
                              imagePreviewEnabled,
                              favoriteKeys,
                            ),
                          ),
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleFavorite(FileEntry entry) {
    final l = _l10n;
    final added = ref
        .read(fileFavoritesProvider(widget.serverId).notifier)
        .toggle(entry);
    _message(
      added
          ? l.fileFavoriteAdded(entry.name)
          : l.fileFavoriteRemoved(entry.name),
    );
  }

  /// 从收藏列表跳转打开文件：所在目录首次加载完成后自动触发一次打开。
  /// 按收藏键优先匹配列表条目，路径键对不上时退回按名称匹配。
  void _scheduleAutoOpenOnce(DirectoryListing listing) {
    final pending = _pendingAutoOpen;
    if (pending == null) return;
    FileEntry? match;
    for (final entry in listing.entries) {
      if (entry.stableKey == pending.stableKey) {
        match = entry;
        break;
      }
    }
    if (match == null) {
      for (final entry in listing.entries) {
        if (entry.name == pending.name) {
          match = entry;
          break;
        }
      }
    }
    // 目录还没加载出目标时保留待打开状态，等下一次加载再试。
    if (match == null) return;
    _pendingAutoOpen = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _busy || _selectionMode) return;
      unawaited(_openFile(match!));
    });
  }

  Widget _entryTile(
    FileEntry entry,
    int index,
    bool imagePreviewEnabled,
    Set<String> favoriteKeys,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l = _l10n;
    final isFavorite = favoriteKeys.contains(entry.stableKey);
    final meta = _entryMetaSpan(entry, context);
    final playbackProgress = !entry.isDirectory && _isVideoEntry(entry)
        ? _filePlaybackProgress.load(entry.name)
        : null;
    final Widget leading;
    if (_selectionMode) {
      leading = SizedBox(
        width: 40,
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _selectedKeys.contains(entry.stableKey)
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              border: Border.all(
                color: _selectedKeys.contains(entry.stableKey)
                    ? colors.primary
                    : colors.outline,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: _selectedKeys.contains(entry.stableKey)
                ? const Icon(Icons.check, color: Colors.white, size: 15)
                : null,
          ),
        ),
      );
    } else {
      final hasImagePreview =
          imagePreviewEnabled && !entry.isDirectory && _isImageEntry(entry);
      final previewFrame = imagePreviewEnabled;
      leading = FileEntryIconBadge(
        entry: entry,
        isFavorite: isFavorite,
        width: previewFrame ? fileEntryPreviewIconWidth : 44,
        height: previewFrame ? fileEntryPreviewIconHeight : 44,
        child: hasImagePreview
            ? FileImageThumbnail(
                loader: _thumbnailLoader,
                download: (cancellation) async {
                  final repository = await _repository();
                  return repository.download(
                    entry.path,
                    options: FileTransferOptions(cancellation: cancellation),
                  );
                },
                entry: entry,
              )
            : previewFrame
            ? FileEntryIconPlaceholder(entry: entry)
            : FileEntryIconAsset(
                assetPath: fileIconAssetWhenPreviewDisabledFor(entry),
              ),
      );
    }
    return SwipeActionCell(
      group: _openSwipe,
      cellKey: entry.stableKey,
      enabled: !_busy && !_selectionMode && !widget.directoryPicker,
      actions: [
        SwipeActionData(
          icon: Icons.delete_outline,
          label: l.delete,
          color: colors.error,
          onPressed: () => _delete(entry),
        ),
      ],
      child: DragSelectionTarget<String>(
        key: ValueKey(entry.stableKey),
        id: entry.stableKey,
        selectionIndex: index,
        selectionHandleAlignment: Alignment.centerLeft,
        child: ListTile(
          leading: leading,
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: meta == null
              ? null
              : Text.rich(meta, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: widget.directoryPicker
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playbackProgress != null) ...[
                      _FilePlaybackProgressIndicator(
                        progress: playbackProgress,
                      ),
                      const SizedBox(width: 4),
                    ],
                    PopupMenuButton<String>(
                      tooltip: l.fileEntryActions,
                      enabled: !_busy,
                      icon: const Icon(Icons.more_horiz_rounded),
                      iconSize: 21,
                      onSelected: (action) => _handleEntryAction(entry, action),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'favorite',
                          child: _FileMenuItem(
                            icon: isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            label: isFavorite
                                ? l.fileUnfavorite
                                : l.fileFavorite,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'detail',
                          child: _FileMenuItem(
                            icon: Icons.info_outline,
                            label: l.fileDetails,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          child: _FileMenuItem(
                            icon: Icons.drive_file_rename_outline,
                            label: l.fileRename,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          child: _FileMenuItem(
                            icon: Icons.drive_file_move_outlined,
                            label: l.fileMove,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _FileMenuItem(
                            icon: Icons.delete_outline,
                            label: l.delete,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          onTap: _busy
              ? null
              : widget.directoryPicker
              ? entry.isDirectory
                    ? () => unawaited(_openDirectory(entry.path.value))
                    : null
              : _selectionMode
              ? () => _toggleSelect(entry)
              : entry.isDirectory
              ? () => unawaited(_openDirectory(entry.path.value))
              : () => unawaited(_openFile(entry)),
        ),
      ),
    );
  }

  List<EntityBatchAction> _batchActions(List<FileEntry> entries) {
    final l = _l10n;
    final error = Theme.of(context).colorScheme.error;
    return [
      EntityBatchAction(
        icon: Icons.select_all,
        label: l.fileSelectAll,
        onTap: entries.isEmpty ? null : () => _selectAllVisible(entries),
      ),
      EntityBatchAction(
        icon: Icons.remove_done,
        label: l.fileClearSelection,
        onTap: _selectedKeys.isEmpty ? null : _clearSelection,
      ),
      EntityBatchAction(
        icon: Icons.drive_file_move_outlined,
        label: l.fileMove,
        onTap: _selectedKeys.isEmpty ? null : () => _moveSelected(entries),
      ),
      EntityBatchAction(
        icon: Icons.drive_file_rename_outline,
        label: l.fileRename,
        onTap: _selectedKeys.isEmpty ? null : () => _renameSelected(entries),
      ),
      EntityBatchAction(
        icon: Icons.delete_outline,
        label: l.delete,
        tooltip: l.fileDeleteSelected,
        color: error,
        onTap: _selectedKeys.isEmpty ? null : () => _deleteSelected(entries),
      ),
    ];
  }

  Future<void> _handleLegacyEdgeSwipeBack() async {
    if (_selectionMode) {
      _exitSelection();
      return;
    }
    if (widget.directoryPicker) {
      await Navigator.of(context).maybePop();
      return;
    }
    if (_isAtRoot) {
      if (FileManagerNavigationScope.requestServerSelection(context)) return;
      ServerSelectionPage.requestReturn(context);
      return;
    }
    await _popToParent();
  }

  Future<void> _handleEntryAction(FileEntry entry, String action) async {
    switch (action) {
      case 'favorite':
        _toggleFavorite(entry);
      case 'detail':
        await _runFileOpen(() async {
          await _showDetailsAndMaybeOpenAsText(entry);
        });
      case 'rename':
        await _rename(entry);
      case 'move':
        await _move(entry);
      case 'delete':
        await _delete(entry);
    }
  }

  Future<FileSourceRepository> _repository() async {
    return ref.read(fileSourceRepositoryProvider(widget.sourceId.value).future);
  }

  /// 普通刷新（下拉、重试、写操作后）直接重新列目录；[force] 为 true 时
  /// （右上角菜单「强制刷新」）额外置位来源级标志，让 OpenList 等带服务端
  /// 目录缓存的来源绕过缓存重读后端存储。
  Future<void> _refresh({bool force = false}) async {
    _thumbnailLoader.dispose();
    _thumbnailLoader = FileThumbnailLoader();
    if (force) {
      ref
              .read(
                fileDirectoryForceRefreshProvider(
                  widget.sourceId.value,
                ).notifier,
              )
              .state =
          true;
    }
    final provider = fileDirectoryProvider(_request);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // 错误由页面上的 AsyncValue 错误态展示，刷新指示器本身应正常收起。
    } finally {
      if (force) {
        ref
                .read(
                  fileDirectoryForceRefreshProvider(
                    widget.sourceId.value,
                  ).notifier,
                )
                .state =
            false;
      }
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _routeName(String path) => fileBrowserRouteName(
    serverId: widget.serverId,
    sourceId: widget.sourceId.value,
    path: path,
  );
}
