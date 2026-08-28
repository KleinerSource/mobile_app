import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/sources/common/source_descriptor.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/common/source_exception.dart';
import 'file_browser_page.dart';
import 'file_source_settings_page.dart';

/// 文件列表来源入口。媒体库来源不会出现在这里，避免把 OMM/DBO 当成
/// 通用文件系统使用。
class FileSourcesPage extends ConsumerWidget {
  const FileSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
    final sources = ref.watch(fileSourceDescriptorsProvider(serverId));
    return Scaffold(
      appBar: AppBar(title: const Text('文件列表')),
      body: sources.when(
        data: (items) => items.isEmpty
            ? _EmptyFiles(onConfigure: () => _openSettings(context))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '选择一个文件来源',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final source in items)
                    _SourceTile(
                      source: source,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FileBrowserPage(sourceId: source.id),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('管理文件来源'),
                  ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FileError(
          message: error is SourceException ? error.message : error.toString(),
          onRetry: () =>
              ref.invalidate(fileSourceDescriptorsProvider(serverId)),
          onConfigure: () => _openSettings(context),
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FileSourceSettingsPage()));
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.onTap});

  final SourceDescriptor source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = source.kind == SourceKind.smb
        ? Icons.lan_outlined
        : Icons.cloud_outlined;
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(source.name),
        subtitle: Text(source.endpoint ?? source.kind.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  const _EmptyFiles({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('还没有连接文件来源'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onConfigure,
              icon: const Icon(Icons.add),
              label: const Text('添加文件来源'),
            ),
          ],
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
                FilledButton(onPressed: onConfigure, child: const Text('管理来源')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
