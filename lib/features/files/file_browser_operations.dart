part of 'file_browser_page.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _FileBrowserOperations on _FileBrowserPageState {
  Future<void> _createDirectory(FilePath parent) async {
    final l = _l10n;
    final name = await _askText(l.fileCreateDirectory, l.fileFolderNameLabel);
    if (name == null || name.trim().isEmpty) return;
    await _run(l.fileCreateDirectoryFailed, () async {
      final repo = await _repository();
      await repo.createDirectory(parent, name.trim());
      await _refresh();
    });
  }

  Future<void> _upload(FilePath parent) async {
    final l = _l10n;
    final localPath = await _askText(l.fileUpload, l.fileLocalPathLabel);
    if (localPath == null || localPath.trim().isEmpty) return;
    final file = File(localPath.trim());
    if (!await file.exists()) {
      _message(l.fileLocalFileMissing);
      return;
    }
    final name = _pathName(file.path);
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: _join(parent.value, name),
    );
    final overwrite = await _confirmOverwrite(destination);
    if (overwrite != true) return;
    await _run(l.fileUploadFailed, () async {
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
          throw FileSourceException(l.fileUploadCanceled, code: 'canceled');
        }
        _tracker.complete(operationId, FileOperationKind.upload);
        _message(l.fileUploadDone);
        await _refresh();
      } catch (error) {
        _tracker.fail(operationId, FileOperationKind.upload, error);
        if (cancellation.isCancelled || _isCanceled(error)) {
          _message(l.fileUploadCanceled);
          return;
        }
        rethrow;
      }
    });
  }

  Future<void> _rename(FileEntry entry) async {
    final l = _l10n;
    final name = await _askText(
      l.fileRename,
      l.fileNewNameLabel,
      initial: entry.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == entry.name) {
      return;
    }
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: _join(_parent(entry.path.value), name.trim()),
    );
    if (await _confirmOverwrite(destination) != true) return;
    await _run(l.fileRenameFailed, () async {
      await (await _repository()).rename(
        entry.path,
        name.trim(),
        overwrite: true,
      );
      if (_selectionMode) _exitSelection();
      await _refresh();
    });
  }

  Future<void> _move(FileEntry entry) async {
    final l = _l10n;
    final directory = await _pickDirectory();
    if (directory == null) return;
    if (_isInvalidMoveTarget(entry, directory)) return;
    final destination = FilePath(
      sourceId: widget.sourceId,
      value: _join(directory.value, entry.name),
    );
    if (destination == entry.path) return;
    if (await _confirmOverwrite(destination) != true) return;
    await _run(l.fileMoveFailed, () async {
      await (await _repository()).move(
        entry.path,
        destination,
        overwrite: true,
      );
      if (_selectionMode) _exitSelection();
      await _refresh();
    });
  }

  Future<FilePath?> _pickDirectory() async {
    // 「移动文件起始位置」设置：默认从根目录选择；选择「当前目录」时
    // 从移动操作发起的目录开始，省去逐层下钻。栈底路由名保持为根形式，
    // 作为选择器的固定回退目标。
    final startLocation = ref.read(fileMoveStartProvider);
    final startPath = startLocation == FileMoveStartLocation.current
        ? _path
        : '';
    final moveTargetTab = FileManagerNavigationScope.moveTargetTabOf(context);
    if (moveTargetTab != null) moveTargetTab.value = 0;
    try {
      return await Navigator.of(context).push<FilePath>(
        MaterialPageRoute<FilePath>(
          settings: RouteSettings(name: _routeName('')),
          allowSnapshotting: false,
          builder: (_) => FileMoveDestinationPage(
            serverId: widget.serverId,
            sourceId: widget.sourceId,
            initialPath: startPath,
          ),
        ),
      );
    } finally {
      if (mounted) {
        final moveTargetTab = FileManagerNavigationScope.moveTargetTabOf(
          context,
        );
        if (moveTargetTab != null) moveTargetTab.value = null;
      }
    }
  }

  bool _isInvalidMoveTarget(FileEntry entry, FilePath directory) {
    if (!entry.isDirectory) return false;
    final sourcePath = entry.path.value.replaceAll(RegExp(r'/+$'), '');
    final targetPath = directory.value.replaceAll(RegExp(r'/+$'), '');
    if (targetPath == sourcePath ||
        (sourcePath.isNotEmpty && targetPath.startsWith('$sourcePath/'))) {
      _message(_l10n.fileInvalidMoveTarget);
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

    await _run(_l10n.fileBatchMoveFailed, () async {
      final repo = await _repository();
      var conflictCount = 0;
      for (final move in moves) {
        if (await repo.exists(move.destination)) conflictCount++;
      }
      if (conflictCount > 0 &&
          await _confirmBatchOverwrite(conflictCount, _l10n.fileMove) != true) {
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
    final l = _l10n;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.fileTargetExists),
        content: Text(l.fileBatchOverwritePrompt(count, action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.fileOverwrite),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSelected(List<FileEntry> entries) async {
    final l = _l10n;
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
      _message(l.fileNoRenameChanges);
      return;
    }

    final plannedPaths = <String>{};
    final selectedPaths = selected.map((entry) => entry.path.value).toSet();
    for (final item in planned) {
      final path = _join(_parent(item.entry.path.value), item.name);
      if (!plannedPaths.add(path)) {
        _message(l.fileRenameDuplicatePreview);
        return;
      }
      if (path != item.entry.path.value && selectedPaths.contains(path)) {
        _message(l.fileRenameCollision);
        return;
      }
    }

    await _run(l.fileBatchRenameFailed, () async {
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
          await _confirmBatchOverwrite(conflictCount, l.fileRename) != true) {
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
    final l = _l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.fileDeleteConfirmTitle),
        content: Text(l.fileDeleteConfirmBody(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(l.fileDeleteFailed, () async {
      await (await _repository()).delete(
        entry.path,
        options: FileDeleteOptions(recursive: entry.isDirectory),
      );
      if (_selectionMode) _exitSelection();
      await _refresh();
    });
  }

  Future<void> _deleteSelected(List<FileEntry> entries) async {
    final l = _l10n;
    final selected = entries
        .where((entry) => _selectedKeys.contains(entry.stableKey))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.fileBatchDeleteConfirmTitle),
        content: Text(l.fileBatchDeleteConfirmBody(selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors(context).danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(l.fileBatchDeleteFailed, () async {
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
    _updateViewState(() => _operation = operation);
    if (operation.status == FileOperationStatus.running) return;

    final operationId = operation.id;
    _operationDismissTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _operation?.id != operationId) return;
      _updateViewState(() => _operation = null);
      _operationDismissTimer = null;
    });
  }

  bool _isCanceled(Object error) =>
      error is SourceException && error.code == 'canceled';

  Future<void> _run(String errorPrefix, Future<void> Function() action) async {
    _updateViewState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(
          '$errorPrefix：${localizedErrorMessage(_l10n, error)}',
        );
      }
    } finally {
      if (mounted) _updateViewState(() => _busy = false);
    }
  }

  Future<String?> _askText(
    String title,
    String label, {
    String? initial,
  }) async {
    final l = _l10n;
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
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool?> _confirmOverwrite(FilePath path) async {
    final l = _l10n;
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
        title: Text(l.fileTargetExists),
        content: Text(l.fileOverwritePrompt(path.value)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.fileOverwrite),
          ),
        ],
      ),
    );
  }
}
