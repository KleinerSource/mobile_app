import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'server_lines_page.dart';
import 'settings_common.dart';

class ServerListPage extends ConsumerWidget {
  const ServerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: '服务器',
              title: '服务器列表',
              subtitle: '每台服务器可单独配置线路，启动时选择服务器。',
              trailing: SettingsAddButton(
                onPressed: () => _showServerEditor(context, ref),
              ),
            ),
            body: ListView.separated(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              itemCount: servers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final server = servers[index];
                return _ServerListCard(
                  server: server,
                  active: server.id == config?.activeServerId,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerLinesPage(serverId: server.id),
                    ),
                  ),
                  onEdit: () => _showServerEditor(
                    context,
                    ref,
                    existing: server,
                  ),
                  onDelete: servers.length <= 1
                      ? null
                      : () => _deleteServer(context, ref, server),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showServerEditor(
    BuildContext context,
    WidgetRef ref, {
    ServerProfile? existing,
  }) async {
    final draft = await showDialog<_ServerDraft>(
      context: context,
      builder: (_) => _ServerEditorDialog(existing: existing),
    );
    if (draft == null || !context.mounted) return;
    final server = ServerProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      lines: existing?.lines ?? [
        ServerLine(
          id: 'main-${DateTime.now().microsecondsSinceEpoch}',
          name: '主线路',
          baseUrl: draft.baseUrl,
        ),
      ],
      activeLineId: existing?.activeLineId,
    );
    try {
      await ref.read(serverConfigProvider.notifier).saveServer(server);
      if (context.mounted) {
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? '服务器已添加' : '服务器已更新')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$error')),
        );
      }
    }
  }

  Future<void> _deleteServer(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除“${server.name}”及其线路吗？'),
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(serverConfigProvider.notifier).deleteServer(server.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$error')),
        );
      }
    }
  }
}

class _ServerListCard extends StatelessWidget {
  const _ServerListCard({
    required this.server,
    required this.active,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ServerProfile server;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          SettingsTile(
            title: server.name,
            subtitle: '${server.lines.length} 条线路',
            leadingIcon: Icons.dns_outlined,
            trailing: active
                ? _ActiveChip(color: colors.accent)
                : Icon(Icons.chevron_right, color: colors.muted),
            onTap: onTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('编辑名称'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.alt_route_outlined, size: 17),
                    label: const Text('管理线路'),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '删除服务器',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: colors.danger),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '当前',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ServerDraft {
  const _ServerDraft({required this.name, required this.baseUrl});

  final String name;
  final String baseUrl;
}

class _ServerEditorDialog extends StatefulWidget {
  const _ServerEditorDialog({this.existing});

  final ServerProfile? existing;

  @override
  State<_ServerEditorDialog> createState() => _ServerEditorDialogState();
}

class _ServerEditorDialogState extends State<_ServerEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _baseUrl = TextEditingController(
      text: widget.existing?.activeLine?.baseUrl ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加服务器' : '编辑服务器'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '服务器名称'),
              validator: (value) =>
                  value?.trim().isEmpty == true ? '请输入服务器名称' : null,
            ),
            const SizedBox(height: 12),
            if (widget.existing == null)
              TextFormField(
                controller: _baseUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '初始线路地址',
                  hintText: 'http://192.168.1.10:8001',
                ),
                validator: (value) {
                  final normalized = ServerConfig.normalize(value ?? '');
                  if (normalized.isEmpty) return '请输入线路地址';
                  if (!normalized.startsWith('http://') &&
                      !normalized.startsWith('https://')) {
                    return '地址必须以 http:// 或 https:// 开头';
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ServerDraft(
                name: _name.text.trim(),
                baseUrl: ServerConfig.normalize(_baseUrl.text),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
