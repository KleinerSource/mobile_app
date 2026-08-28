import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/common/source_exception.dart';
import 'file_browser_page.dart';
import '../settings/server_selection_page.dart';

/// 文件列表页。文件服务器选中后直接进入根目录，不再展示来源 URL 列表。
class FileSourcesPage extends ConsumerWidget {
  const FileSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final serverId = config?.activeServerId;
    final server = config?.activeServer;
    if (serverId == null || server?.project?.isFileSource != true) {
      return _NoFileServer(onSelectServer: () => _openServerSelector(context));
    }

    final sources = ref.watch(fileSourceDescriptorsProvider(serverId));
    return sources.when(
      data: (items) => items.length == 1
          ? FileBrowserPage(
              key: ValueKey('$serverId:${items.single.id}'),
              serverId: serverId,
              sourceId: items.single.id,
            )
          : _MissingFileSource(
              onRetry: () =>
                  ref.invalidate(fileSourceDescriptorsProvider(serverId)),
              onConfigure: () => _openServerSelector(context),
            ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('文件列表')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _FileError(
        message: error is SourceException ? error.message : error.toString(),
        onRetry: () => ref.invalidate(fileSourceDescriptorsProvider(serverId)),
        onConfigure: () => _openServerSelector(context),
      ),
    );
  }

  Future<void> _openServerSelector(BuildContext context) async {
    ServerSelectionPage.requestReturn(context);
  }
}

class _NoFileServer extends StatelessWidget {
  const _NoFileServer({required this.onSelectServer});

  final VoidCallback onSelectServer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件列表')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('当前服务器不是文件服务器'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onSelectServer,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('选择文件服务器'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingFileSource extends StatelessWidget {
  const _MissingFileSource({required this.onRetry, required this.onConfigure});

  final VoidCallback onRetry;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件列表')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('当前服务器没有可用的文件来源'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: onRetry, child: const Text('重试')),
                  FilledButton(
                    onPressed: onConfigure,
                    child: const Text('返回服务器选择'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileError extends StatelessWidget {
  const _FileError({
    required this.message,
    required this.onRetry,
    required this.onConfigure,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: onRetry, child: const Text('重试')),
                FilledButton(
                  onPressed: onConfigure,
                  child: const Text('管理服务器'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
