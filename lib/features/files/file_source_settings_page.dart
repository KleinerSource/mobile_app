import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/sources/files/file_source_config.dart';
import '../../core/sources/files/file_source_providers.dart';

class FileSourceSettingsPage extends ConsumerWidget {
  const FileSourceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(fileSourceConfigsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件来源设置'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _FileSourceEditor()),
              );
              ref.invalidate(fileSourceRegistryProvider);
            },
            icon: const Icon(Icons.add),
            tooltip: '添加来源',
          ),
        ],
      ),
      body: configs.isEmpty
          ? const Center(child: Text('暂无文件来源'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: configs.length,
              itemBuilder: (context, index) {
                final config = configs[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      config.protocol == FileSourceProtocol.smb
                          ? Icons.lan_outlined
                          : Icons.cloud_outlined,
                    ),
                    title: Text(config.name),
                    subtitle: Text(_endpoint(config)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  _FileSourceEditor(initial: config),
                            ),
                          );
                        } else if (value == 'delete') {
                          final confirmed = await _confirmDelete(
                            context,
                            config.name,
                          );
                          if (confirmed == true) {
                            await ref
                                .read(fileSourceConfigRepositoryProvider)
                                .delete(config.id);
                            final reference =
                                config.credentialRef?.trim().isNotEmpty == true
                                ? config.credentialRef!
                                : config.id;
                            await ref
                                .read(fileSourceCredentialsRepositoryProvider)
                                .delete(reference);
                          }
                        }
                        ref.invalidate(fileSourceConfigsProvider);
                        ref.invalidate(fileSourceRegistryProvider);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const _FileSourceEditor()));
          ref.invalidate(fileSourceConfigsProvider);
          ref.invalidate(fileSourceRegistryProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FileSourceEditor extends ConsumerStatefulWidget {
  const _FileSourceEditor({this.initial});

  final FileSourceConfig? initial;

  @override
  ConsumerState<_FileSourceEditor> createState() => _FileSourceEditorState();
}

class _FileSourceEditorState extends ConsumerState<_FileSourceEditor> {
  late final _id = TextEditingController(text: widget.initial?.id);
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _host = TextEditingController(text: widget.initial?.host);
  late final _share = TextEditingController(text: widget.initial?.share);
  late final _uri = TextEditingController(text: widget.initial?.uri);
  late final _user = TextEditingController();
  late final _password = TextEditingController();
  late FileSourceProtocol _protocol =
      widget.initial?.protocol ?? FileSourceProtocol.smb;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _host,
      _share,
      _uri,
      _user,
      _password,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smb = _protocol == FileSourceProtocol.smb;
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? '添加文件来源' : '编辑文件来源')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _id,
            enabled: widget.initial == null,
            decoration: const InputDecoration(labelText: '来源 ID'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '显示名称'),
          ),
          DropdownButtonFormField<FileSourceProtocol>(
            initialValue: _protocol,
            decoration: const InputDecoration(labelText: '协议'),
            items: const [
              DropdownMenuItem(
                value: FileSourceProtocol.smb,
                child: Text('SMB'),
              ),
              DropdownMenuItem(
                value: FileSourceProtocol.webDav,
                child: Text('WebDAV'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _protocol = value ?? _protocol),
          ),
          if (smb) ...[
            TextField(
              controller: _host,
              decoration: const InputDecoration(labelText: '主机'),
            ),
            TextField(
              controller: _share,
              decoration: const InputDecoration(labelText: '共享名'),
            ),
          ] else
            TextField(
              controller: _uri,
              decoration: const InputDecoration(labelText: 'WebDAV 地址'),
            ),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: '用户名（可选）'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码（可选）'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : const Text('保存并连接'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final serverId = ref.read(serverConfigProvider)?.activeServerId;
    final id = _id.text.trim();
    final config = _protocol == FileSourceProtocol.smb
        ? FileSourceConfig.smb(
            id: id,
            name: _name.text.trim(),
            host: _host.text.trim(),
            share: _share.text.trim(),
            serverId: serverId,
          )
        : FileSourceConfig.webDav(
            id: id,
            name: _name.text.trim(),
            uri: _uri.text.trim(),
            serverId: serverId,
          );
    if (!config.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请完整填写有效配置')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(fileSourceConfigRepositoryProvider).save(config);
      if (_user.text.trim().isNotEmpty || _password.text.isNotEmpty) {
        await ref
            .read(fileSourceCredentialsRepositoryProvider)
            .save(
              config.credentialRef ?? config.id,
              FileSourceCredentials(
                user: _user.text.trim(),
                password: _password.text,
              ),
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }
}

String _endpoint(FileSourceConfig config) =>
    config.protocol == FileSourceProtocol.smb
    ? 'smb://${config.host}/${config.share}'
    : config.uri ?? '';

Future<bool?> _confirmDelete(BuildContext context, String name) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除文件来源？'),
      content: Text('将移除“$name”的连接配置，不会删除远程文件。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}
