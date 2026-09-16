part of 'file_browser_page.dart';

class _FileOperationOverlay extends StatelessWidget {
  const _FileOperationOverlay({required this.operation, this.onCancel});

  final FileOperation operation;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = operation.progress;
    final isRunning = operation.status == FileOperationStatus.running;
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = _operationProgress(operation);
    return Stack(
      children: [
        ModalBarrier(
          key: const ValueKey('file-operation-barrier'),
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.42),
        ),
        Center(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 320,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    key: const ValueKey('file-operation-dialog'),
                    color: colorScheme.surface,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 56,
                              child: isRunning
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox.square(
                                          dimension: 56,
                                          child: CircularProgressIndicator(
                                            value: ratio,
                                            strokeWidth: 4,
                                          ),
                                        ),
                                        if (ratio != null)
                                          Text('${(ratio * 100).round()}%'),
                                      ],
                                    )
                                  : Icon(
                                      _operationStatusIcon(operation.status),
                                      size: 48,
                                      color:
                                          operation.status ==
                                              FileOperationStatus.completed
                                          ? colorScheme.primary
                                          : colorScheme.error,
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _operationTitle(operation, AppL10n.of(context)),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (progress != null) ...[
                              const SizedBox(height: 8),
                              Text(_progressText(progress)),
                            ],
                            if (progress == null &&
                                operation.totalItems != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppL10n.of(context).fileOperationItemsProgress(
                                  operation.completedItems ?? 0,
                                  operation.totalItems!,
                                ),
                              ),
                            ],
                            if (!isRunning && operation.message != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                operation.message!,
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (isRunning && onCancel != null) ...[
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: onCancel,
                                child: Text(AppL10n.of(context).cancel),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

IconData _operationStatusIcon(FileOperationStatus status) => switch (status) {
  FileOperationStatus.completed => Icons.check_circle_outline,
  FileOperationStatus.canceled => Icons.cancel_outlined,
  _ => Icons.error_outline,
};

String _operationTitle(FileOperation operation, AppL10n l) {
  final action = switch (operation.kind) {
    FileOperationKind.upload => l.fileUploadAction,
    FileOperationKind.delete => l.delete,
    FileOperationKind.move => l.fileMove,
    FileOperationKind.rename => l.fileRename,
    FileOperationKind.createDirectory => l.fileCreateDirectory,
    _ => l.fileFileOperation,
  };
  return switch (operation.status) {
    FileOperationStatus.running => l.fileOperationRunning(action),
    FileOperationStatus.completed => l.fileOperationCompleted(action),
    FileOperationStatus.canceled => l.fileOperationCanceled(action),
    FileOperationStatus.failed => l.fileOperationFailed(action),
    FileOperationStatus.pending => l.fileOperationPending(action),
  };
}

double? _operationProgress(FileOperation operation) {
  final transferProgress = operation.progress?.ratio;
  if (transferProgress != null) return transferProgress;
  final totalItems = operation.totalItems;
  if (totalItems == null || totalItems <= 0) return null;
  return ((operation.completedItems ?? 0) / totalItems).clamp(0.0, 1.0);
}

String _progressText(FileTransferProgress progress) {
  final total = progress.total;
  if (total == null) return _formatBytes(progress.transferred);
  return '${_formatBytes(progress.transferred)} / ${_formatBytes(total)}';
}

/// 文件浏览页顶部的紧凑导航栏：返回、当前服务器名称、更多操作。
class _FileBrowserTopBar extends StatelessWidget {
  const _FileBrowserTopBar({
    required this.title,
    required this.backIcon,
    required this.backTooltip,
    required this.onBackPressed,
    required this.trailing,
  });

  final String title;
  final IconData backIcon;
  final String backTooltip;
  final VoidCallback? onBackPressed;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: backTooltip,
          onPressed: onBackPressed,
          icon: Icon(backIcon),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.cardTitle(
            context,
          ).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [trailing],
      ),
    );
  }
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
          FilledButton(
            onPressed: onRetry,
            child: Text(AppL10n.of(context).fileRetry),
          ),
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
      label: AppL10n.of(context).filePlaybackProgress,
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

/// 移动目标选择器。文件浏览和收藏目录共用一个底部导航，目录本身只负责
/// 浏览；右上角的「选择此目录」才会提交目标路径。
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

/// 列表行副标题：目录显示修改时间；文件显示「修改时间 · 大小」，时间缺失
/// 时退回 MIME 类型，两者都没有则留空（不占行高）。元信息使用弱化色，
/// 与文件名的主色区分开。
InlineSpan? _entryMetaSpan(FileEntry entry, BuildContext context) {
  final time = entry.modifiedAt ?? entry.createdAt;
  final colors = appColors(context);
  final metaStyle = AppText.meta(
    context,
  ).copyWith(fontWeight: FontWeight.normal);
  final separatorStyle = metaStyle.copyWith(color: colors.muted2);
  if (entry.isDirectory) {
    return time == null
        ? null
        : TextSpan(text: _formatDateTime(time), style: metaStyle);
  }

  final spans = <InlineSpan>[];
  if (time != null) {
    spans.add(TextSpan(text: _formatDateTime(time), style: metaStyle));
  }
  if (entry.size != null) {
    if (spans.isNotEmpty) {
      spans.add(TextSpan(text: ' · ', style: separatorStyle));
    }
    spans.add(TextSpan(text: _formatBytes(entry.size!), style: metaStyle));
  } else if (time == null && entry.mimeType != null) {
    if (spans.isNotEmpty) {
      spans.add(TextSpan(text: ' · ', style: separatorStyle));
    }
    spans.add(TextSpan(text: entry.mimeType!, style: metaStyle));
  }
  return spans.isEmpty ? null : TextSpan(children: spans);
}

String _formatDateTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
