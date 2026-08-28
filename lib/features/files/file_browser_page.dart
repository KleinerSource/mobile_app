import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/sources/common/source_exception.dart';
import '../../core/sources/common/source_id.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_operation.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/files/file_source_repository.dart';
import '../../shared/drag_selection.dart';
import '../../shared/edge_swipe_back.dart';
import '../../shared/swipe_actions.dart';
import '../settings/server_selection_page.dart';

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

class FileBrowserPage extends ConsumerStatefulWidget {
  const FileBrowserPage({
    super.key,
    required this.serverId,
    required this.sourceId,
    this.initialPath = '',
  });

  final String serverId;
  final SourceId sourceId;
  final String initialPath;

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  late String _path = widget.initialPath;
  late final FileOperationTracker _tracker;
  final ScrollController _scrollController = ScrollController();
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  final Set<String> _selectedKeys = <String>{};
  StreamSubscription<FileOperation>? _operationSubscription;
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

  bool get _isAtRoot => _path.isEmpty || _path == '/';

  @override
  void initState() {
    super.initState();
    _tracker = FileOperationTracker(sourceId: widget.sourceId);
    _scrollController.addListener(_closeSwipeOnScroll);
    _operationSubscription = _tracker.events.listen((operation) {
      if (mounted) setState(() => _operation = operation);
    });
  }

  @override
  void dispose() {
    unawaited(_operationSubscription?.cancel());
    _scrollController.removeListener(_closeSwipeOnScroll);
    _scrollController.dispose();
    _openSwipe.dispose();
    unawaited(_tracker.dispose());
    super.dispose();
  }

  Future<void> _handleEdgeSwipeBack() async {
    if (_selectionMode) {
      _exitSelection();
      return;
    }
    if (_isAtRoot) {
      await ServerSelectionPage.openForReturn(context);
      return;
    }
    await _popToParent();
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(fileDirectoryProvider(_request));
    final source = ref.watch(fileSourceProvider(widget.sourceId.value));
    final currentDirectoryPath = listing.hasValue
        ? listing.requireValue.currentPath
        : FilePath(sourceId: widget.sourceId, value: _path);
    final visibleEntries = listing.hasValue
        ? _visibleEntries(listing.requireValue)
        : const <FileEntry>[];

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelection();
      },
      child: EdgeSwipeBack(
        onTriggered: () => unawaited(_handleEdgeSwipeBack()),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: _selectionMode
                  ? '退出选择'
                  : _isAtRoot
                  ? '返回服务器选择'
                  : '返回上一级',
              onPressed: _selectionMode ? _exitSelection : _handleBack,
              icon: Icon(_selectionMode ? Icons.close : Icons.arrow_back),
            ),
            title: source.when(
              data: (value) => Text(
                _selectionMode
                    ? '已选 ${_selectedKeys.length} 项'
                    : (value?.descriptor.name ?? '文件列表'),
              ),
              loading: () => const Text('文件列表'),
              error: (_, __) => const Text('文件列表'),
            ),
            actions: [
              PopupMenuButton<_BrowserMenuAction>(
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
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: listing.when(
                  data: _buildListing,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _BrowserError(
                    message: error is SourceException
                        ? error.message
                        : error.toString(),
                    onRetry: () => unawaited(_refresh()),
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
          bottomNavigationBar: _selectionMode
              ? _FileSelectionToolbar(
                  selectedCount: _selectedKeys.length,
                  totalCount: visibleEntries.length,
                  allSelected:
                      visibleEntries.isNotEmpty &&
                      visibleEntries.every(
                        (entry) => _selectedKeys.contains(entry.stableKey),
                      ),
                  onSelectAll: () => _toggleSelectAll(visibleEntries),
                  onDelete: () => _deleteSelected(visibleEntries),
                  onClose: _exitSelection,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _returnToServerSelector() async {
    await ServerSelectionPage.openForReturn(context);
  }

  void _handleBack() {
    if (_isAtRoot) {
      unawaited(_returnToServerSelector());
    } else {
      unawaited(_popToParent());
    }
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: _routeName(path)),
        builder: (_) => FileBrowserPage(
          serverId: widget.serverId,
          sourceId: widget.sourceId,
          initialPath: path,
        ),
      ),
    );
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
    if (path.isEmpty) {
      navigator.popUntil((route) => route.isFirst);
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

  void _toggleSelectAll(List<FileEntry> entries) {
    if (entries.isEmpty) return;
    final allSelected = entries.every(
      (entry) => _selectedKeys.contains(entry.stableKey),
    );
    if (allSelected) {
      _exitSelection();
      return;
    }
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

  Widget _buildListing(DirectoryListing listing) {
    final entries = _visibleEntries(listing);
    return Column(
      children: [
        if (listing.breadcrumbs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                for (var i = 0; i < listing.breadcrumbs.length; i++) ...[
                  if (i > 0) const Icon(Icons.chevron_right, size: 18),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _popToPath(listing.breadcrumbs[i].value),
                          ),
                    child: Text(
                      i == 0 ? '根目录' : _pathName(listing.breadcrumbs[i].value),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (listing.parentPath != null)
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('上一级'),
            onTap: _busy ? null : () => unawaited(_popToParent()),
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
                      children: const [
                        SizedBox(height: 140),
                        Center(child: Text('此目录为空')),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _entryTile(entries[index], index),
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

  Widget _entryTile(FileEntry entry, int index) {
    final colors = Theme.of(context).colorScheme;
    return SwipeActionCell(
      group: _openSwipe,
      cellKey: entry.stableKey,
      enabled: !_busy && !_selectionMode,
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
              : Icon(
                  entry.isDirectory ? Icons.folder_outlined : _fileIcon(entry),
                ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: entry.isDirectory ? null : Text(_entryMeta(entry)),
          trailing: PopupMenuButton<String>(
            tooltip: '文件操作',
            enabled: !_busy,
            onSelected: (action) => _handleEntryAction(entry, action),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'detail', child: Text('详情')),
              if (!entry.isDirectory)
                const PopupMenuItem(value: 'download', child: Text('下载')),
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              const PopupMenuItem(value: 'move', child: Text('移动')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
          onTap: _busy
              ? null
              : _selectionMode
              ? () => _toggleSelect(entry)
              : entry.isDirectory
              ? () => unawaited(_openDirectory(entry.path.value))
              : () => _showDetails(entry),
        ),
      ),
    );
  }

  Future<void> _handleEntryAction(FileEntry entry, String action) async {
    switch (action) {
      case 'detail':
        await _showDetails(entry);
      case 'download':
        await _download(entry);
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

  Future<void> _download(FileEntry entry) async {
    final targetDirectory = await getApplicationDocumentsDirectory();
    final target = File(
      '${targetDirectory.path}${Platform.pathSeparator}${entry.name}',
    );
    final overwrite = await _confirmLocalOverwrite(target);
    if (overwrite != true) return;
    await _run('下载失败', () => _downloadWithTracking(entry, target));
  }

  Future<void> _downloadWithTracking(FileEntry entry, File target) async {
    final repo = await _repository();
    final operationId = _tracker.start(
      FileOperationKind.download,
      source: entry.path,
    );
    final cancellation = _tracker.cancellation(operationId)!;
    final output = target.openWrite(mode: FileMode.write);
    var outputClosed = false;
    try {
      await for (final chunk in repo.download(
        entry.path,
        options: FileTransferOptions(
          cancellation: cancellation,
          onProgress: (progress) => _tracker.progress(operationId, progress),
        ),
      )) {
        output.add(chunk);
      }
      if (cancellation.isCancelled) {
        throw const FileSourceException('下载已取消', code: 'canceled');
      }
      await output.close();
      outputClosed = true;
      _tracker.complete(operationId, FileOperationKind.download);
      _message('已下载到 ${target.path}');
    } catch (error) {
      _tracker.fail(operationId, FileOperationKind.download, error);
      if (cancellation.isCancelled || _isCanceled(error)) {
        _message('下载已取消');
        return;
      }
      rethrow;
    } finally {
      if (!outputClosed) {
        try {
          await output.close();
        } catch (_) {}
      }
    }
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
    final destinationPath = await _askText(
      '移动',
      '目标完整路径',
      initial: entry.path.value,
    );
    if (destinationPath == null ||
        destinationPath.trim().isEmpty ||
        destinationPath.trim() == entry.path.value) {
      return;
    }
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: destinationPath.trim(),
    );
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('路径：${entry.path.value}'),
              if (entry.size != null) Text('大小：${_formatBytes(entry.size!)}'),
              if (entry.mimeType != null) Text('类型：${entry.mimeType}'),
              if (entry.modifiedAt != null) Text('修改时间：${entry.modifiedAt}'),
            ],
          ),
        ),
      ),
    );
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

  Future<bool?> _confirmLocalOverwrite(File file) async {
    if (!await file.exists()) return true;
    if (!mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本地文件已存在'),
        content: Text('是否覆盖“${file.path}”？'),
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

class _FileSelectionToolbar extends StatelessWidget {
  const _FileSelectionToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDelete,
    required this.onClose,
  });

  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: '退出选择',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
            Expanded(child: Text('已选 $selectedCount 项')),
            TextButton(
              onPressed: totalCount == 0 ? null : onSelectAll,
              child: Text(allSelected ? '取消全选' : '全选'),
            ),
            IconButton(
              tooltip: '删除所选',
              onPressed: selectedCount == 0 ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
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
  FileOperationKind.download => Icons.download_outlined,
  _ => Icons.sync,
};

String _operationTitle(FileOperation operation) {
  final action = switch (operation.kind) {
    FileOperationKind.upload => '上传',
    FileOperationKind.download => '下载',
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

IconData _fileIcon(FileEntry entry) {
  final type = entry.mimeType?.toLowerCase() ?? '';
  if (type.startsWith('video/')) return Icons.movie_outlined;
  if (type.startsWith('audio/')) return Icons.music_note_outlined;
  if (type.startsWith('image/')) return Icons.image_outlined;
  return Icons.insert_drive_file_outlined;
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
