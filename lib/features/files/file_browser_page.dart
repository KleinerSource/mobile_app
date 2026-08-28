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
import '../settings/server_selection_page.dart';

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
  StreamSubscription<FileOperation>? _operationSubscription;
  FileOperation? _operation;
  bool _busy = false;

  FileDirectoryRequest get _request => FileDirectoryRequest(
    serverId: widget.serverId,
    sourceId: widget.sourceId,
    path: _path,
  );

  @override
  void initState() {
    super.initState();
    _tracker = FileOperationTracker(sourceId: widget.sourceId);
    _operationSubscription = _tracker.events.listen((operation) {
      if (mounted) setState(() => _operation = operation);
    });
  }

  @override
  void dispose() {
    unawaited(_operationSubscription?.cancel());
    unawaited(_tracker.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(fileDirectoryProvider(_request));
    final source = ref.watch(fileSourceProvider(widget.sourceId.value));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回服务器选择',
          onPressed: _returnToServerSelector,
          icon: const Icon(Icons.arrow_back),
        ),
        title: source.when(
          data: (value) => Text(value?.descriptor.name ?? '文件列表'),
          loading: () => const Text('文件列表'),
          error: (_, __) => const Text('文件列表'),
        ),
        actions: [
          IconButton(
            onPressed: _busy
                ? null
                : () => ref.invalidate(fileDirectoryProvider(_request)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: listing.when(
              data: _buildListing,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _BrowserError(
                message: error is SourceException
                    ? error.message
                    : error.toString(),
                onRetry: () => ref.invalidate(fileDirectoryProvider(_request)),
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
      floatingActionButton: listing.hasValue
          ? FloatingActionButton(
              onPressed: _busy
                  ? null
                  : () => _showActions(listing.requireValue),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _returnToServerSelector() async {
    await ServerSelectionPage.openForReturn(context);
  }

  Widget _buildListing(DirectoryListing listing) {
    final entries = [...listing.entries]
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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
                        : () => setState(
                            () => _path = listing.breadcrumbs[i].value,
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
            onTap: _busy
                ? null
                : () => setState(() => _path = listing.parentPath!.value),
          ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('此目录为空'))
              : ListView.separated(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _entryTile(entries[index]),
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                ),
        ),
      ],
    );
  }

  Widget _entryTile(FileEntry entry) {
    return ListTile(
      leading: Icon(
        entry.isDirectory ? Icons.folder_outlined : _fileIcon(entry),
      ),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.isDirectory ? null : Text(_entryMeta(entry)),
      trailing: PopupMenuButton<String>(
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
          : entry.isDirectory
          ? () => setState(() => _path = entry.path.value)
          : () => _showDetails(entry),
    );
  }

  Future<void> _showActions(DirectoryListing listing) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建目录'),
              onTap: () => Navigator.pop(context, 'mkdir'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('上传文件'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'mkdir') await _createDirectory(listing.currentPath);
    if (action == 'upload') await _upload(listing.currentPath);
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
    final name = await _askText('新建目录', '目录名称');
    if (name == null || name.trim().isEmpty) return;
    await _run('创建目录失败', () async {
      final repo = await _repository();
      await repo.createDirectory(parent, name.trim());
      _refresh();
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
        _refresh();
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
      _refresh();
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
      _refresh();
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
      _refresh();
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

  void _refresh() => ref.invalidate(fileDirectoryProvider(_request));

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
