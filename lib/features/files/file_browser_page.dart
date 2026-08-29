import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_log_store.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/common/source_descriptor.dart';
import '../../core/sources/common/source_exception.dart';
import '../../core/sources/common/source_id.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_operation.dart';
import '../../core/sources/files/file_playback_progress.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/files/file_source_repository.dart';
import '../../shared/drag_selection.dart';
import '../../shared/entity_batch_toolbar.dart';
import '../../shared/edge_swipe_back.dart';
import '../../shared/floating_tab_bar.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import '../../shared/sheet_controls.dart';
import '../../shared/swipe_actions.dart';
import '../player/playback_engine.dart';
import '../player/player_engine_picker.dart';
import '../player/player_page.dart';
import '../player/player_session_factory.dart';
import '../player/player_settings.dart';
import '../oh_my_media/movie_detail/movie_detail_page.dart'
    show showImageLightbox;
import '../settings/server_selection_page.dart';
import '../settings/settings_common.dart';
import 'file_navigation.dart';
import 'file_image_preview_settings.dart';
import 'file_playback_engine.dart';
import 'file_playback_proxy.dart';

enum _FileSortField { name, date, size, category }

enum _BrowserMenuAction {
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

enum _FileDetailsAction { preview }

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
  });

  final String serverId;
  final SourceId sourceId;
  final String initialPath;
  final bool directoryPicker;

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  late String _path = widget.initialPath;
  late final FileOperationTracker _tracker;
  late final FilePlaybackProgressRepository _filePlaybackProgress;
  final ScrollController _scrollController = ScrollController();
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  final Set<String> _selectedKeys = <String>{};
  final Map<String, Future<Uint8List>> _imagePreviewFutures = {};
  StreamSubscription<FileOperation>? _operationSubscription;
  Timer? _operationDismissTimer;
  FileOperation? _operation;
  bool _busy = false;
  bool _selectionMode = false;
  bool _showHiddenFiles = false;
  _FileSortField _sortField = _FileSortField.name;
  bool _sortAscending = true;

  FileDirectoryRequest get _request => FileDirectoryRequest(
    serverId: widget.serverId,
    sourceId: widget.sourceId,
    path: _path,
  );

  bool get _isAtRoot => isRootFilePath(_path);

  @override
  void initState() {
    super.initState();
    _tracker = FileOperationTracker(sourceId: widget.sourceId);
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
    _imagePreviewFutures.clear();
    unawaited(_tracker.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(fileDirectoryProvider(_request));
    final source = ref.watch(fileSourceProvider(widget.sourceId.value));
    final imagePreviewEnabled = ref.watch(fileImagePreviewProvider);
    final currentDirectoryPath = listing.hasValue
        ? listing.requireValue.currentPath
        : FilePath(sourceId: widget.sourceId, value: _path);
    final visibleEntries = listing.hasValue
        ? _visibleEntries(listing.requireValue)
        : const <FileEntry>[];
    final batchActions = _batchActions(visibleEntries);

    // 与偏好设置一致的固定头部：眉标题(协议) + 主标题 + 返回/右侧操作。
    final descriptor = source.asData?.value?.descriptor;
    final headerEyebrow = switch (descriptor?.kind) {
      SourceKind.smb => 'SMB',
      SourceKind.webDav => 'WEBDAV',
      _ => '文件',
    };
    final headerTitle = widget.directoryPicker
        ? '选择目标目录'
        : _selectionMode
        ? '已选 ${_selectedKeys.length} 项'
        : (descriptor?.name ?? '文件列表');
    final headerTrailing = widget.directoryPicker
        ? IconButton(
            tooltip: '选择此目录',
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(currentDirectoryPath),
            icon: const Icon(Icons.check),
          )
        : _selectionMode
        ? PopupMenuButton<int>(
            tooltip: '批量操作',
            onSelected: (index) => batchActions[index].onTap?.call(),
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
            tooltip: '更多',
            onSelected: (action) =>
                _handleMenuAction(action, currentDirectoryPath),
            itemBuilder: (_) => [
              _menuItem(
                _BrowserMenuAction.createDirectory,
                Icons.create_new_folder_outlined,
                '新建文件夹',
              ),
              _menuItem(
                _BrowserMenuAction.upload,
                Icons.upload_file_outlined,
                '上传文件',
              ),
              _menuItem(
                _BrowserMenuAction.enterSelection,
                Icons.checklist_outlined,
                '选择',
              ),
              CheckedPopupMenuItem<_BrowserMenuAction>(
                value: _BrowserMenuAction.toggleHidden,
                checked: _showHiddenFiles,
                child: const Text('显示隐藏文件'),
              ),
              CheckedPopupMenuItem<_BrowserMenuAction>(
                value: _BrowserMenuAction.sortName,
                checked: _sortField == _FileSortField.name,
                child: Text(_sortMenuLabel('名称', _FileSortField.name)),
              ),
              CheckedPopupMenuItem<_BrowserMenuAction>(
                value: _BrowserMenuAction.sortDate,
                checked: _sortField == _FileSortField.date,
                child: Text(_sortMenuLabel('日期', _FileSortField.date)),
              ),
              CheckedPopupMenuItem<_BrowserMenuAction>(
                value: _BrowserMenuAction.sortSize,
                checked: _sortField == _FileSortField.size,
                child: Text(_sortMenuLabel('大小', _FileSortField.size)),
              ),
              CheckedPopupMenuItem<_BrowserMenuAction>(
                value: _BrowserMenuAction.sortCategory,
                checked: _sortField == _FileSortField.category,
                child: Text(_sortMenuLabel('类别', _FileSortField.category)),
              ),
            ],
          );

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
              header: SettingsSubPageHeader(
                eyebrow: headerEyebrow,
                title: headerTitle,
                titleMaxLines: 1,
                backIcon: _selectionMode ? Icons.close : Icons.arrow_back,
                backTooltip: _selectionMode
                    ? '退出选择'
                    : widget.directoryPicker
                    ? (_isAtRoot ? '取消选择' : '返回上一级')
                    : (_isAtRoot ? '返回服务器选择' : '返回上一级'),
                onBackPressed: _selectionMode
                    ? _exitSelection
                    : widget.directoryPicker
                    ? _cancelDirectoryPicker
                    : _handleBack,
                trailing: headerTrailing,
              ),
              body: Column(
                children: [
                  Expanded(
                    child: listing.when(
                      data: (value) =>
                          _buildListing(value, imagePreviewEnabled),
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
                          message: error is SourceException
                              ? error.message
                              : error.toString(),
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
    unawaited(Navigator.of(context).maybePop());
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
      setState(() {
        _path = parent;
        _selectionMode = false;
        _selectedKeys.clear();
      });
    }
  }

  Future<void> _popToPath(String path) async {
    _openSwipe.value = null;
    if (path == _path) return;
    final navigator = Navigator.of(context);
    if (isRootFilePath(path)) {
      final rootRouteName = _routeName('');
      navigator.popUntil(
        (route) => widget.directoryPicker
            ? route.settings.name == rootRouteName
            : route.settings.name == fileManagerRootRouteName ||
                  (!ServerNavigationScope.of(context) && route.isFirst),
      );
      return;
    }
    final target = _routeName(path);
    navigator.popUntil((route) => route.settings.name == target);
  }

  void _startSelectionSweep(String key, bool selected) {
    setState(() {
      _selectionMode = true;
      _setSelectionValue(key, selected);
    });
  }

  void _applySelectionSweep(String key, bool selected) {
    if (_selectedKeys.contains(key) == selected) return;
    setState(() => _setSelectionValue(key, selected));
  }

  void _finishSelectionSweep() {
    if (_selectionMode && _selectedKeys.isEmpty) _exitSelection();
  }

  void _setSelectionValue(String key, bool selected) {
    if (selected) {
      _selectedKeys.add(key);
    } else {
      _selectedKeys.remove(key);
    }
  }

  void _toggleSelect(FileEntry entry) {
    setState(() {
      if (_selectedKeys.remove(entry.stableKey)) {
        if (_selectedKeys.isEmpty) _selectionMode = false;
      } else {
        _selectedKeys.add(entry.stableKey);
      }
    });
  }

  void _enterSelectionMode() {
    if (_busy || _selectionMode) return;
    setState(() => _selectionMode = true);
  }

  void _exitSelection() {
    _openSwipe.value = null;
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedKeys.clear();
    });
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() => _selectedKeys.clear());
  }

  void _selectAllVisible(List<FileEntry> entries) {
    if (entries.isEmpty) return;
    setState(() {
      _selectionMode = true;
      _selectedKeys
        ..clear()
        ..addAll(entries.map((entry) => entry.stableKey));
    });
  }

  Future<void> _handleMenuAction(
    _BrowserMenuAction action,
    FilePath currentPath,
  ) async {
    switch (action) {
      case _BrowserMenuAction.createDirectory:
        await _createDirectory(currentPath);
      case _BrowserMenuAction.upload:
        await _upload(currentPath);
      case _BrowserMenuAction.enterSelection:
        _enterSelectionMode();
      case _BrowserMenuAction.toggleHidden:
        if (_selectionMode) _exitSelection();
        if (mounted) setState(() => _showHiddenFiles = !_showHiddenFiles);
      case _BrowserMenuAction.sortName:
        _setSort(_FileSortField.name);
      case _BrowserMenuAction.sortDate:
        _setSort(_FileSortField.date);
      case _BrowserMenuAction.sortSize:
        _setSort(_FileSortField.size);
      case _BrowserMenuAction.sortCategory:
        _setSort(_FileSortField.category);
    }
  }

  void _setSort(_FileSortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  String _sortMenuLabel(String label, _FileSortField field) {
    if (_sortField != field) return '$label排序';
    return '$label排序 ${_sortAscending ? '↑' : '↓'}';
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
      _FileSortField.name => _compareNames(a.name, b.name),
      _FileSortField.date => _compareDates(
        a.modifiedAt ?? a.createdAt,
        b.modifiedAt ?? b.createdAt,
      ),
      _FileSortField.size => (a.size ?? -1).compareTo(b.size ?? -1),
      _FileSortField.category => _entryCategory(a).compareTo(_entryCategory(b)),
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

  Widget _buildListing(DirectoryListing listing, bool imagePreviewEnabled) {
    final entries = _visibleEntries(listing);
    return Column(
      children: [
        if (listing.breadcrumbs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                              ? '根目录'
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
                      children: const [
                        SizedBox(height: 140),
                        Center(child: Text('此目录为空')),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: floatingTabBarContentBottomInset(context),
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) => _entryTile(
                        entries[index],
                        index,
                        imagePreviewEnabled,
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

  Widget _entryTile(FileEntry entry, int index, bool imagePreviewEnabled) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final playbackProgress = !entry.isDirectory && _isVideoEntry(entry)
        ? _filePlaybackProgress.load(entry.name)
        : null;
    return SwipeActionCell(
      group: _openSwipe,
      cellKey: entry.stableKey,
      enabled: !_busy && !_selectionMode && !widget.directoryPicker,
      actions: [
        SwipeActionData(
          icon: Icons.delete_outline,
          label: '删除',
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
          leading: _selectionMode
              ? SizedBox(
                  width: 40,
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedKeys.contains(entry.stableKey)
                            ? colors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _selectedKeys.contains(entry.stableKey)
                              ? colors.primary
                              : colors.outline,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _selectedKeys.contains(entry.stableKey)
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
                )
              : imagePreviewEnabled &&
                    !entry.isDirectory &&
                    _isImageEntry(entry)
              ? _FileImageThumbnail(
                  bytes: _imagePreviewFuture(entry),
                  fallbackIcon: _fileIcon(entry),
                  fallbackColor: _fileIconColor(entry, theme.brightness),
                )
              : Icon(
                  entry.isDirectory ? Icons.folder_outlined : _fileIcon(entry),
                  color: entry.isDirectory
                      ? colors.primary
                      : _fileIconColor(entry, theme.brightness),
                ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: entry.isDirectory ? null : _entrySubtitle(entry),
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
                      tooltip: '文件操作',
                      enabled: !_busy,
                      onSelected: (action) => _handleEntryAction(entry, action),
                      itemBuilder: (_) => [
                        if (entry.isDirectory || !_canPreview(entry))
                          const PopupMenuItem(
                            value: 'detail',
                            child: _FileMenuItem(
                              icon: Icons.info_outline,
                              label: '详情',
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: _FileMenuItem(
                            icon: Icons.drive_file_rename_outline,
                            label: '重命名',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'move',
                          child: _FileMenuItem(
                            icon: Icons.drive_file_move_outlined,
                            label: '移动',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: _FileMenuItem(
                            icon: Icons.delete_outline,
                            label: '删除',
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

  Widget _entrySubtitle(FileEntry entry) {
    final metadata = _entryMeta(entry);
    return Text(metadata);
  }

  List<EntityBatchAction> _batchActions(List<FileEntry> entries) {
    final error = Theme.of(context).colorScheme.error;
    return [
      EntityBatchAction(
        icon: Icons.select_all,
        label: '全选',
        onTap: entries.isEmpty ? null : () => _selectAllVisible(entries),
      ),
      EntityBatchAction(
        icon: Icons.remove_done,
        label: '清空',
        onTap: _selectedKeys.isEmpty ? null : _clearSelection,
      ),
      EntityBatchAction(
        icon: Icons.drive_file_move_outlined,
        label: '移动',
        onTap: _selectedKeys.isEmpty ? null : () => _moveSelected(entries),
      ),
      EntityBatchAction(
        icon: Icons.drive_file_rename_outline,
        label: '重命名',
        onTap: _selectedKeys.isEmpty ? null : () => _renameSelected(entries),
      ),
      EntityBatchAction(
        icon: Icons.delete_outline,
        label: '删除',
        tooltip: '删除所选',
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
      case 'detail':
        await _showDetails(entry);
      case 'rename':
        await _rename(entry);
      case 'move':
        await _move(entry);
      case 'delete':
        await _delete(entry);
    }
  }

  Future<void> _createDirectory(FilePath parent) async {
    final name = await _askText('新建文件夹', '文件夹名称');
    if (name == null || name.trim().isEmpty) return;
    await _run('创建目录失败', () async {
      final repo = await _repository();
      await repo.createDirectory(parent, name.trim());
      await _refresh();
    });
  }

  Future<void> _upload(FilePath parent) async {
    final localPath = await _askText('上传文件', '本地文件路径');
    if (localPath == null || localPath.trim().isEmpty) return;
    final file = File(localPath.trim());
    if (!await file.exists()) {
      _message('本地文件不存在');
      return;
    }
    final name = _pathName(file.path);
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: _join(parent.value, name),
    );
    final overwrite = await _confirmOverwrite(destination);
    if (overwrite != true) return;
    await _run('上传失败', () async {
      final repo = await _repository();
      final operationId = _tracker.start(
        FileOperationKind.upload,
        destination: destination,
      );
      final cancellation = _tracker.cancellation(operationId)!;
      try {
        await repo.upload(
          FileUploadRequest(
            destination: destination,
            data: file.openRead(),
            length: await file.length(),
            options: FileTransferOptions(
              overwrite: overwrite == true,
              cancellation: cancellation,
              onProgress: (progress) =>
                  _tracker.progress(operationId, progress),
            ),
          ),
        );
        if (cancellation.isCancelled) {
          throw const FileSourceException('上传已取消', code: 'canceled');
        }
        _tracker.complete(operationId, FileOperationKind.upload);
        _message('上传完成');
        await _refresh();
      } catch (error) {
        _tracker.fail(operationId, FileOperationKind.upload, error);
        if (cancellation.isCancelled || _isCanceled(error)) {
          _message('上传已取消');
          return;
        }
        rethrow;
      }
    });
  }

  Future<void> _rename(FileEntry entry) async {
    final name = await _askText('重命名', '新名称', initial: entry.name);
    if (name == null || name.trim().isEmpty || name.trim() == entry.name) {
      return;
    }
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: _join(_parent(entry.path.value), name.trim()),
    );
    if (await _confirmOverwrite(destination) != true) return;
    await _run('重命名失败', () async {
      await (await _repository()).rename(
        entry.path,
        name.trim(),
        overwrite: true,
      );
      await _refresh();
    });
  }

  Future<void> _move(FileEntry entry) async {
    final directory = await _pickDirectory();
    if (directory == null) return;
    if (_isInvalidMoveTarget(entry, directory)) return;
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: _join(directory.value, entry.name),
    );
    if (destination == entry.path) return;
    if (await _confirmOverwrite(destination) != true) return;
    await _run('移动失败', () async {
      await (await _repository()).move(
        entry.path,
        destination,
        overwrite: true,
      );
      await _refresh();
    });
  }

  Future<FilePath?> _pickDirectory() {
    return Navigator.of(context).push<FilePath>(
      MaterialPageRoute<FilePath>(
        settings: RouteSettings(name: _routeName('')),
        allowSnapshotting: false,
        builder: (_) => FileBrowserPage(
          serverId: widget.serverId,
          sourceId: widget.sourceId,
          directoryPicker: true,
        ),
      ),
    );
  }

  bool _isInvalidMoveTarget(FileEntry entry, FilePath directory) {
    if (!entry.isDirectory) return false;
    final sourcePath = entry.path.value.replaceAll(RegExp(r'/+$'), '');
    final targetPath = directory.value.replaceAll(RegExp(r'/+$'), '');
    if (targetPath == sourcePath ||
        (sourcePath.isNotEmpty && targetPath.startsWith('$sourcePath/'))) {
      _message('不能将目录移动到自身或其子目录');
      return true;
    }
    return false;
  }

  Future<void> _moveSelected(List<FileEntry> entries) async {
    final selected = entries
        .where((entry) => _selectedKeys.contains(entry.stableKey))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final directory = await _pickDirectory();
    if (directory == null || !mounted) return;
    if (selected.any((entry) => _isInvalidMoveTarget(entry, directory))) {
      return;
    }

    final moves = selected
        .map(
          (entry) => (
            entry: entry,
            destination: FilePath(
              sourceId: widget.sourceId,
              value: _join(directory.value, entry.name),
            ),
          ),
        )
        .where((move) => move.destination != move.entry.path)
        .toList(growable: false);
    if (moves.isEmpty) return;

    await _run('批量移动失败', () async {
      final repo = await _repository();
      var conflictCount = 0;
      for (final move in moves) {
        if (await repo.exists(move.destination)) conflictCount++;
      }
      if (conflictCount > 0 &&
          await _confirmBatchOverwrite(conflictCount, '移动') != true) {
        return;
      }
      for (final move in moves) {
        await repo.move(move.entry.path, move.destination, overwrite: true);
      }
      _exitSelection();
      await _refresh();
    });
  }

  Future<bool?> _confirmBatchOverwrite(int count, String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目标已存在'),
        content: Text('$count 个目标已存在，是否覆盖后继续$action？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSelected(List<FileEntry> entries) async {
    final selected = entries
        .where((entry) => _selectedKeys.contains(entry.stableKey))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final draft = await _showBatchRenameSheet(selected);
    if (draft == null || !mounted) return;

    final planned = selected
        .map(
          (entry) => (entry: entry, name: _batchRenameName(entry.name, draft)),
        )
        .where((item) => item.name.isNotEmpty && item.name != item.entry.name)
        .toList(growable: false);
    if (planned.isEmpty) {
      _message('没有可应用的名称变化');
      return;
    }

    final plannedPaths = <String>{};
    final selectedPaths = selected.map((entry) => entry.path.value).toSet();
    for (final item in planned) {
      final path = _join(_parent(item.entry.path.value), item.name);
      if (!plannedPaths.add(path)) {
        _message('预览结果包含重复名称，请调整重命名规则');
        return;
      }
      if (path != item.entry.path.value && selectedPaths.contains(path)) {
        _message('不能批量重命名为其他已选项的现有名称');
        return;
      }
    }

    await _run('批量重命名失败', () async {
      final repo = await _repository();
      var conflictCount = 0;
      for (final item in planned) {
        final destination = FilePath(
          sourceId: widget.sourceId,
          value: _join(_parent(item.entry.path.value), item.name),
        );
        if (destination.value != item.entry.path.value &&
            !selectedPaths.contains(destination.value) &&
            await repo.exists(destination)) {
          conflictCount++;
        }
      }
      if (conflictCount > 0 &&
          await _confirmBatchOverwrite(conflictCount, '重命名') != true) {
        return;
      }
      for (final item in planned) {
        await repo.rename(item.entry.path, item.name, overwrite: true);
      }
      _exitSelection();
      await _refresh();
    });
  }

  Future<_BatchRenameDraft?> _showBatchRenameSheet(
    List<FileEntry> entries,
  ) async {
    return showGlassSheet<_BatchRenameDraft>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _BatchRenameSheet(entries: entries),
    );
  }

  String _batchRenameName(String name, _BatchRenameDraft draft) {
    return _applyBatchRenameName(name, draft);
  }

  Future<void> _delete(FileEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除？'),
        content: Text('将从远程文件来源删除“${entry.name}”，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run('删除失败', () async {
      await (await _repository()).delete(
        entry.path,
        options: FileDeleteOptions(recursive: entry.isDirectory),
      );
      if (_selectionMode) _exitSelection();
      await _refresh();
    });
  }

  Future<void> _deleteSelected(List<FileEntry> entries) async {
    final selected = entries
        .where((entry) => _selectedKeys.contains(entry.stableKey))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认批量删除？'),
        content: Text('将从远程文件来源删除已选择的 ${selected.length} 项，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run('批量删除失败', () async {
      final repo = await _repository();
      for (final entry in selected) {
        await repo.delete(
          entry.path,
          options: FileDeleteOptions(recursive: entry.isDirectory),
        );
      }
      _exitSelection();
      await _refresh();
    });
  }

  Future<void> _showDetails(FileEntry entry) async {
    final action = await showGlassSheet<_FileDetailsAction>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              icon: entry.isDirectory
                  ? Icons.folder_outlined
                  : _fileIcon(entry),
              title: entry.name,
              subtitle: entry.isDirectory ? '目录详情' : '文件详情',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('路径：${entry.path.value}'),
                  if (entry.size != null)
                    Text('大小：${_formatBytes(entry.size!)}'),
                  if (entry.mimeType != null) Text('类型：${entry.mimeType}'),
                  if (entry.modifiedAt != null)
                    Text('修改时间：${entry.modifiedAt}'),
                ],
              ),
            ),
            if (!entry.isDirectory && _canPreview(entry))
              ListTile(
                leading: Icon(_previewIcon(entry)),
                title: Text(_previewLabel(entry)),
                subtitle: const Text('在应用内查看文件内容'),
                onTap: () =>
                    Navigator.of(context).pop(_FileDetailsAction.preview),
              ),
          ],
        ),
      ),
    );
    if (action == _FileDetailsAction.preview && mounted) {
      await _preview(entry);
    }
  }

  Future<void> _openFile(FileEntry entry) async {
    if (_canPreview(entry)) {
      await _preview(entry);
      return;
    }
    await _showDetails(entry);
  }

  Future<void> _preview(FileEntry entry) async {
    if (_isVideoEntry(entry)) {
      await _previewVideo(entry);
    } else if (_isImageEntry(entry)) {
      await _previewImage(entry);
    } else if (_isSubtitleEntry(entry)) {
      await _previewText(entry);
    } else if (_isTextEntry(entry)) {
      await _previewText(entry);
    }
  }

  Future<void> _previewVideo(FileEntry entry) async {
    PlaybackEngineKind? engineKind;
    final playerSettings = ref.read(playerSettingsProvider);
    if (playerSettings.debugMode) {
      final engineKinds = availablePlaybackEngineKinds();
      engineKind = await showPlaybackEnginePicker(
        context,
        engineKinds: engineKinds,
        defaultEngineKind: playerSettings.iosEngine,
      );
      if (!mounted || engineKind == null) return;
    }

    FilePlaybackProxy? proxy;
    setState(() => _busy = true);
    try {
      final repository = await _repository();
      final sourceKind = repository.source.descriptor.kind;
      final selectedEngineKind = filePlaybackEngineKind(
        sourceKind: sourceKind,
        isIOS: Platform.isIOS,
        requested: engineKind,
      );
      appLog(
        '[FileBrowser] 视频来源: kind=${sourceKind.name} '
        'source=${repository.source.descriptor.id.value}',
      );

      // WebDAV 本质是 HTTP(S) 文件服务，直接把文件 URL 和认证头交给
      // 播放器，保留播放器自身的 Range/seek 能力，不经过回环代理。
      if (sourceKind == SourceKind.webDav) {
        final access = await repository.resolveAccess(entry.path);
        if (!mounted) return;
        final directUri = access.uri;
        if (directUri == null) {
          throw const FileSourceException(
            'WebDAV 未提供 HTTP 直连地址，已停止播放（不会回退到本机代理）',
            code: 'webdav_direct_url_missing',
          );
        }
        final playbackUrl = directUri.toString();
        appLog(
          '[FileBrowser] 使用 WebDAV HTTP 直连播放: '
          'engine=${selectedEngineKind?.value ?? 'default'} '
          'url=$playbackUrl headers=${access.headers.isNotEmpty}',
        );
        await PlayerPage.openDirect(
          context,
          title: entry.name,
          directUrl: playbackUrl,
          directHeaders: access.headers,
          directFormatHint: _pathExtension(entry.name),
          engineKind: selectedEngineKind,
          directPlaybackFileName: entry.name,
          directPreferFfmpegForHls: true,
          useRootNavigator: true,
        );
        return;
      }

      proxy = await FilePlaybackProxy.start(
        repository: repository,
        path: entry.path,
        size: entry.size,
        mimeType: entry.mimeType,
        pathExtension: _pathExtension(entry.name),
      );
      if (!mounted) return;
      // SMB 没有可供 iOS AVPlayer 使用的 HTTP URL，继续使用回环 HTTP
      // 代理按需读取；代理本身会透传可用的 Range。
      final playbackUrl = proxy.uri.toString();
      appLog(
        '[FileBrowser] 使用流式代理播放: '
        'engine=${selectedEngineKind?.value ?? 'default'} url=$playbackUrl',
      );
      await PlayerPage.openDirect(
        context,
        title: entry.name,
        directUrl: playbackUrl,
        engineKind: selectedEngineKind,
        directPlaybackFileName: entry.name,
        directPreferFfmpegForHls: true,
        useRootNavigator: true,
      );
    } catch (error, stackTrace) {
      appLog('[FileBrowser] 视频预览失败: $error\n$stackTrace');
      if (mounted) {
        _message('视频预览失败：${error is SourceException ? error.message : error}');
      }
    } finally {
      try {
        await proxy?.close();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewImage(FileEntry entry) async {
    try {
      final listing = ref.read(fileDirectoryProvider(_request)).valueOrNull;
      final entries = listing == null
          ? <FileEntry>[entry]
          : _visibleEntries(listing).where(_isImageEntry).toList();
      if (!entries.any((item) => item.stableKey == entry.stableKey)) {
        entries.insert(0, entry);
      }
      final initialIndex = entries.indexWhere(
        (item) => item.stableKey == entry.stableKey,
      );
      if (!mounted) return;
      await showImageLightbox(
        context,
        itemCount: entries.length,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        loadBytes: (index) => _readFileBytes(entries[index]),
        useRootNavigator: true,
      );
    } catch (error) {
      if (mounted) _message('图片预览失败：$error');
    }
  }

  Future<void> _previewText(FileEntry entry) async {
    try {
      final bytes = await _readFileBytes(entry);
      if (!mounted) return;
      final text = _decodeTextPreview(entry, bytes);
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          allowSnapshotting: false,
          builder: (_) => _FileTextViewerPage(title: entry.name, text: text),
        ),
      );
    } catch (error) {
      if (mounted) _message('文本预览失败：$error');
    }
  }

  Future<Uint8List> _readFileBytes(FileEntry entry) async {
    final access = await (await _repository()).resolveAccess(entry.path);
    final stream = await access.open();
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<Uint8List> _imagePreviewFuture(FileEntry entry) {
    return _imagePreviewFutures.putIfAbsent(
      entry.stableKey,
      () => _readFileBytes(entry),
    );
  }

  bool _canPreview(FileEntry entry) =>
      _isVideoEntry(entry) ||
      _isImageEntry(entry) ||
      _isSubtitleEntry(entry) ||
      _isTextEntry(entry);

  String _previewLabel(FileEntry entry) {
    if (_isVideoEntry(entry)) return '播放视频';
    if (_isImageEntry(entry)) return '查看图片';
    if (_isSubtitleEntry(entry)) return '查看字幕';
    return '查看文本';
  }

  IconData _previewIcon(FileEntry entry) {
    if (_isVideoEntry(entry)) return Icons.play_circle_outline;
    if (_isImageEntry(entry)) return Icons.image_outlined;
    if (_isSubtitleEntry(entry)) return Icons.closed_caption_outlined;
    return Icons.description_outlined;
  }

  bool _isVideoEntry(FileEntry entry) => _fileTypeFor(entry) == _FileType.video;

  bool _isImageEntry(FileEntry entry) => _fileTypeFor(entry) == _FileType.image;

  bool _isSubtitleEntry(FileEntry entry) =>
      _fileTypeFor(entry) == _FileType.subtitle;

  bool _isTextEntry(FileEntry entry) => _fileTypeFor(entry) == _FileType.text;

  String? _pathExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1);
  }

  String _decodeTextPreview(FileEntry entry, List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final mime = entry.mimeType?.toLowerCase() ?? '';
    final isJson =
        mime == 'application/json' || _fileExtensionFor(entry.name) == 'json';
    if (!isJson) return text;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } catch (_) {
      return text;
    }
  }

  Future<FileSourceRepository> _repository() async {
    return ref.read(fileSourceRepositoryProvider(widget.sourceId.value).future);
  }

  void _cancelOperation() {
    final operation = _operation;
    if (operation == null || operation.status != FileOperationStatus.running) {
      return;
    }
    _tracker.cancel(operation.id);
  }

  void _handleOperationEvent(FileOperation operation) {
    _operationDismissTimer?.cancel();
    _operationDismissTimer = null;
    if (!mounted) return;
    setState(() => _operation = operation);
    if (operation.status == FileOperationStatus.running) return;

    final operationId = operation.id;
    _operationDismissTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _operation?.id != operationId) return;
      setState(() => _operation = null);
      _operationDismissTimer = null;
    });
  }

  bool _isCanceled(Object error) =>
      error is SourceException && error.code == 'canceled';

  Future<void> _run(String errorPrefix, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(
          '$errorPrefix：${error is SourceException ? error.message : error}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askText(
    String title,
    String label, {
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool?> _confirmOverwrite(FilePath path) async {
    try {
      final exists = await (await _repository()).exists(path);
      if (!exists) return true;
    } catch (_) {
      return null;
    }
    if (!mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目标已存在'),
        content: Text('是否覆盖“${path.value}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    _imagePreviewFutures.clear();
    final provider = fileDirectoryProvider(_request);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // 错误由页面上的 AsyncValue 错误态展示，刷新指示器本身应正常收起。
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _routeName(String path) =>
      'file-browser:${widget.serverId}:${widget.sourceId.value}:$path';
}

class _FileImageThumbnail extends StatelessWidget {
  const _FileImageThumbnail({
    required this.bytes,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  static const _width = 64.0;
  static const _height = 36.0;

  final Future<Uint8List> bytes;
  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return _frame(
            Image.memory(
              data,
              width: _width,
              height: _height,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
          );
        }
        return _frame(_fallback());
      },
    );
  }

  Widget _frame(Widget child) {
    return SizedBox(
      width: _width,
      height: _height,
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: fallbackColor.withValues(alpha: 0.12),
      child: Center(child: Icon(fallbackIcon, color: fallbackColor, size: 22)),
    );
  }
}

class _BatchRenameSheet extends StatefulWidget {
  const _BatchRenameSheet({required this.entries});

  final List<FileEntry> entries;

  @override
  State<_BatchRenameSheet> createState() => _BatchRenameSheetState();
}

class _BatchRenameSheetState extends State<_BatchRenameSheet> {
  final _searchController = TextEditingController();
  final _replacementController = TextEditingController();
  final _addController = TextEditingController();
  var _mode = _BatchRenameMode.replace;
  var _addBefore = true;

  @override
  void dispose() {
    _searchController.dispose();
    _replacementController.dispose();
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _BatchRenameDraft(
      mode: _mode,
      search: _searchController.text,
      replacement: _replacementController.text,
      addText: _addController.text,
      addBefore: _addBefore,
    );
    final previews = widget.entries
        .map(
          (entry) => (
            original: entry.name,
            renamed: _applyBatchRenameName(entry.name, draft),
          ),
        )
        .toList(growable: false);
    final canSubmit = _mode == _BatchRenameMode.replace
        ? _searchController.text.isNotEmpty
        : _addController.text.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              icon: Icons.drive_file_rename_outline,
              title: '批量重命名',
              subtitle: '选择规则并查看实时预览',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: DropdownButtonFormField<_BatchRenameMode>(
                initialValue: _mode,
                decoration: sheetInputDecoration(context, labelText: '重命名模式'),
                items: const [
                  DropdownMenuItem(
                    value: _BatchRenameMode.replace,
                    child: Text('替换文本'),
                  ),
                  DropdownMenuItem(
                    value: _BatchRenameMode.add,
                    child: Text('添加文本'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mode = value);
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_mode == _BatchRenameMode.replace) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  controller: _searchController,
                  decoration: sheetInputDecoration(context, labelText: '查询'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  controller: _replacementController,
                  decoration: sheetInputDecoration(context, labelText: '替换为'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  controller: _addController,
                  decoration: sheetInputDecoration(context, labelText: '添加文本'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: DropdownButtonFormField<bool>(
                  initialValue: _addBefore,
                  decoration: sheetInputDecoration(context, labelText: '添加位置'),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('在名字之前')),
                    DropdownMenuItem(value: false, child: Text('在名字之后')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _addBefore = value);
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Text('预览', style: Theme.of(context).textTheme.titleMedium),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                itemCount: previews.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final preview = previews[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      preview.renamed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: preview.original == preview.renamed
                        ? null
                        : Text(
                            preview.original,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  );
                },
              ),
            ),
            SheetActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: sheetSecondaryButtonStyle(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSubmit
                          ? () => Navigator.of(context).pop(draft)
                          : null,
                      style: sheetPrimaryButtonStyle(context),
                      child: const Text('应用'),
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

String _applyBatchRenameName(String name, _BatchRenameDraft draft) {
  return switch (draft.mode) {
    _BatchRenameMode.replace =>
      draft.search.isEmpty
          ? name
          : name.replaceAllMapped(
              RegExp(RegExp.escape(draft.search), caseSensitive: false),
              (_) => draft.replacement,
            ),
    _BatchRenameMode.add =>
      draft.addBefore ? '${draft.addText}$name' : '$name${draft.addText}',
  };
}

class _FileOperationBanner extends StatelessWidget {
  const _FileOperationBanner({required this.operation, required this.onCancel});

  final FileOperation operation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = operation.progress;
    final isRunning = operation.status == FileOperationStatus.running;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_operationIcon(operation.kind), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _operationTitle(operation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isRunning)
                    IconButton(
                      tooltip: '取消',
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (isRunning) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: progress?.ratio),
              ],
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_progressText(progress)),
                ),
              if (!isRunning && operation.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(operation.message!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _operationIcon(FileOperationKind kind) => switch (kind) {
  FileOperationKind.upload => Icons.upload_outlined,
  _ => Icons.sync,
};

String _operationTitle(FileOperation operation) {
  final action = switch (operation.kind) {
    FileOperationKind.upload => '上传',
    _ => '文件操作',
  };
  return switch (operation.status) {
    FileOperationStatus.running => '$action进行中',
    FileOperationStatus.completed => '$action完成',
    FileOperationStatus.canceled => '$action已取消',
    FileOperationStatus.failed => '$action失败',
    FileOperationStatus.pending => '$action等待中',
  };
}

String _progressText(FileTransferProgress progress) {
  final total = progress.total;
  if (total == null) return _formatBytes(progress.transferred);
  return '${_formatBytes(progress.transferred)} / ${_formatBytes(total)}';
}

class _BrowserError extends StatelessWidget {
  const _BrowserError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class _FilePlaybackProgressIndicator extends StatelessWidget {
  const _FilePlaybackProgressIndicator({required this.progress});

  final FilePlaybackProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '播放进度',
      value: '${progress.percentage}%',
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: progress.ratio,
          strokeWidth: 2.5,
          color: colors.primary,
          backgroundColor: colors.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _FileMenuItem extends StatelessWidget {
  const _FileMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}

class _FileTextViewerPage extends StatelessWidget {
  const _FileTextViewerPage({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: '文件',
              title: title,
              titleMaxLines: 1,
            ),
            body: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _pathName(String path) {
  final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty || normalized == '/') return '';
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

String _parent(String path) {
  final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? '' : normalized.substring(0, index);
}

String _join(String parent, String child) {
  final left = parent.replaceAll(RegExp(r'/+$'), '');
  final right = child.replaceAll(RegExp(r'^/+'), '');
  if (left.isEmpty) return right;
  return '$left/$right';
}

enum _FileType { text, video, image, subtitle, other }

const _videoFileExtensions = <String>{
  'mp4',
  'mkv',
  'webm',
  'mov',
  'avi',
  'm4v',
  'ts',
  'm2ts',
  'm3u8',
};

const _imageFileExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};

const _subtitleFileExtensions = <String>{
  'srt',
  'vtt',
  'ass',
  'ssa',
  'sub',
  'idx',
  'sup',
  'smi',
  'sami',
  'ttml',
};

const _textFileExtensions = <String>{
  'txt',
  'json',
  'csv',
  'xml',
  'html',
  'htm',
  'css',
  'js',
  'ts',
  'yaml',
  'yml',
  'md',
  'log',
};

_FileType _fileTypeFor(FileEntry entry) {
  final mime = entry.mimeType?.trim().toLowerCase() ?? '';
  final extension = _fileExtensionFor(entry.name);

  if (_isSubtitleMimeType(mime) ||
      _subtitleFileExtensions.contains(extension)) {
    return _FileType.subtitle;
  }
  if (mime.startsWith('video/') || _videoFileExtensions.contains(extension)) {
    return _FileType.video;
  }
  if (mime.startsWith('image/') || _imageFileExtensions.contains(extension)) {
    return _FileType.image;
  }
  if (mime.startsWith('text/') ||
      mime == 'application/json' ||
      mime == 'application/xml' ||
      mime == 'application/javascript' ||
      _textFileExtensions.contains(extension)) {
    return _FileType.text;
  }
  return _FileType.other;
}

bool _isSubtitleMimeType(String mime) =>
    mime == 'text/vtt' ||
    mime == 'application/x-subrip' ||
    mime == 'application/ttml+xml' ||
    mime == 'application/ass' ||
    mime == 'application/x-ass' ||
    mime == 'text/x-ssa';

String? _fileExtensionFor(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

IconData _fileIcon(FileEntry entry) {
  return switch (_fileTypeFor(entry)) {
    _FileType.text => Icons.description_outlined,
    _FileType.video => Icons.movie_outlined,
    _FileType.image => Icons.image_outlined,
    _FileType.subtitle => Icons.closed_caption_outlined,
    _FileType.other =>
      (entry.mimeType?.trim().toLowerCase().startsWith('audio/') ?? false)
          ? Icons.music_note_outlined
          : Icons.insert_drive_file_outlined,
  };
}

Color _fileIconColor(FileEntry entry, Brightness brightness) {
  final hue = switch (_fileTypeFor(entry)) {
    _FileType.text => AppHues.sky,
    _FileType.video => AppHues.coral,
    _FileType.image => AppHues.mint,
    _FileType.subtitle => AppHues.solar,
    _FileType.other => AppHues.lavender,
  };
  return AppHues.chipText(hue, brightness);
}

String _entryMeta(FileEntry entry) {
  final parts = <String>[];
  if (entry.size != null) parts.add(_formatBytes(entry.size!));
  if (entry.mimeType != null) parts.add(entry.mimeType!);
  return parts.join(' · ');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
