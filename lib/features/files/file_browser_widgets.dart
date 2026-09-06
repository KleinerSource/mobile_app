part of 'file_browser_page.dart';

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
                      _operationTitle(operation, AppL10n.of(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isRunning)
                    IconButton(
                      tooltip: AppL10n.of(context).cancel,
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

String _operationTitle(FileOperation operation, AppL10n l) {
  final action = switch (operation.kind) {
    FileOperationKind.upload => l.fileUploadAction,
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
  final VoidCallback onBackPressed;
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
