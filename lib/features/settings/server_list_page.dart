import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/config/server_line_probe.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/swipe_actions.dart';
import 'server_lines_page.dart';
import 'settings_common.dart';

class ServerListPage extends ConsumerStatefulWidget {
  const ServerListPage({super.key});

  @override
  ConsumerState<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends ConsumerState<ServerListPage> {
  /// 当前左滑展开的服务器行，同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    final servers = config?.servers ?? const <ServerProfile>[];
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: '服务器',
              title: '服务器列表',
              subtitle: '每台服务器可单独配置线路，启动时选择服务器。',
              trailing: SettingsAddButton(onPressed: () => _showServerEditor()),
            ),
            // 服务器数量少且有界：合并为设置页式分组卡，行间细分隔线。
            body: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              children: [
                if (servers.isNotEmpty)
                  Container(
                    decoration: settingsCardDecoration(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          for (var i = 0; i < servers.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: colors.divider),
                            SwipeActionCell(
                              group: _openSwipe,
                              cellKey: servers[i].id,
                              enabled: true,
                              actions: _serverSwipeActions(
                                colors,
                                servers[i],
                                servers.length,
                              ),
                              child: _ServerListCard(
                                server: servers[i],
                                active: servers[i].id == config?.activeServerId,
                                onTap: () => _openLines(servers[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 单个服务器的左滑操作集：仅剩一台服务器时不可删除。
  List<SwipeActionData> _serverSwipeActions(
    AppColors colors,
    ServerProfile server,
    int count,
  ) {
    return [
      SwipeActionData(
        icon: Icons.edit_outlined,
        label: '编辑名称',
        color: colors.accent,
        onPressed: () => _showServerEditor(existing: server),
      ),
      SwipeActionData(
        icon: Icons.alt_route_outlined,
        label: '管理线路',
        color: AppHues.top(AppHues.sky),
        onPressed: () => _openLines(server),
      ),
      if (count > 1)
        SwipeActionData(
          icon: Icons.delete_outline,
          label: '删除',
          color: colors.danger,
          onPressed: () => _deleteServer(server),
        ),
    ];
  }

  void _openLines(ServerProfile server) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServerLinesPage(serverId: server.id)),
    );
  }

  Future<void> _showServerEditor({ServerProfile? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServerEditorDialog(
        existing: existing,
        onSave: (draft) => _saveServerDraft(existing, draft),
      ),
    );
    if (saved != true || !mounted) return;
    AppHaptics.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '服务器已添加' : '服务器已更新')),
    );
  }

  Future<String?> _saveServerDraft(
    ServerProfile? existing,
    _ServerDraft draft,
  ) async {
    final project = draft.project;
    if (project == null) return '请选择服务器类型';
    final line =
        existing?.activeLine ??
        ServerLine(
          id: 'main-${DateTime.now().microsecondsSinceEpoch}',
          name: '主线路',
          baseUrl: draft.baseUrl,
        );
    ServerLineProbeResult? probe;
    if (existing == null) {
      probe = await ref
          .read(serverLineProbeCoordinatorProvider)
          .probe(line, expectedProjectName: project.projectName);
      if (!probe.success || probe.versionInfo == null) {
        return '连接失败：${probe.message.isEmpty ? '服务器版本检测失败' : probe.message}';
      }
    }
    final server = ServerProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      lines: existing?.lines ?? [line],
      activeLineId: existing?.activeLineId ?? line.id,
      avatarUrl: existing?.avatarUrl,
      projectName: existing?.projectName ?? project.projectName,
      serverVersion: existing?.serverVersion ?? probe?.versionInfo?.version,
    );
    try {
      await ref.read(serverConfigProvider.notifier).saveServer(server);
      return null;
    } catch (error) {
      return '保存失败：$error';
    }
  }

  Future<void> _deleteServer(ServerProfile server) async {
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(serverConfigProvider.notifier).deleteServer(server.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }
}

class _ServerListCard extends StatelessWidget {
  const _ServerListCard({
    required this.server,
    required this.active,
    required this.onTap,
  });

  final ServerProfile server;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    // 分组连排行：透明背景，由外层分组容器提供表面，沿用设置页行布局。
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        splashColor: colors.accent.withValues(alpha: 0.14),
        highlightColor: colors.accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.dns_outlined, color: colors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      server.name,
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${server.lines.length} 条线路',
                        if (server.project != null)
                          server.project!.displayName
                        else if (server.projectName?.isNotEmpty == true)
                          server.projectName!,
                        if (server.serverVersion?.isNotEmpty == true)
                          server.serverVersion!,
                      ].join(' · '),
                      style: AppText.meta(context),
                    ),
                  ],
                ),
              ),
              if (active)
                _ActiveChip(color: colors.accent)
              else
                Icon(Icons.chevron_right, color: colors.muted),
            ],
          ),
        ),
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
  const _ServerDraft({
    required this.name,
    required this.baseUrl,
    required this.project,
  });

  final String name;
  final String baseUrl;
  final ServerProject? project;
}

class _ServerEditorDialog extends StatefulWidget {
  const _ServerEditorDialog({this.existing, required this.onSave});

  final ServerProfile? existing;
  final Future<String?> Function(_ServerDraft draft) onSave;

  @override
  State<_ServerEditorDialog> createState() => _ServerEditorDialogState();
}

class _ServerEditorDialogState extends State<_ServerEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  ServerProject? _project;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _baseUrl = TextEditingController(
      text: widget.existing?.activeLine?.baseUrl ?? 'http://',
    );
    _project = widget.existing?.project ?? ServerProject.ohMyMedia;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _ServerDraft(
      name: _name.text.trim(),
      baseUrl: ServerConfig.normalize(_baseUrl.text),
      project: _project,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final error = await widget.onSave(draft);
      if (!mounted) return;
      if (error != null && error.trim().isNotEmpty) {
        setState(() {
          _saving = false;
          _error = error;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$error';
      });
    }
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
            DropdownButtonFormField<ServerProject>(
              initialValue: _project,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '服务器类型',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              items: [
                for (final project in ServerProject.values)
                  DropdownMenuItem<ServerProject>(
                    value: project,
                    child: Text(_projectLabel(project)),
                  ),
              ],
              onChanged: widget.existing == null
                  ? (project) {
                      if (project != null && project != _project) {
                        AppHaptics.selection();
                        setState(() => _project = project);
                      }
                    }
                  : null,
              validator: (value) => value == null ? '请选择服务器类型' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
              validator: (value) =>
                  value?.trim().isEmpty == true ? '请输入服务器名称' : null,
            ),
            const SizedBox(height: 12),
            if (widget.existing == null)
              TextFormField(
                controller: _baseUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  labelText: '初始线路地址',
                  hintText: 'http://192.168.1.10:8001',
                  prefixIcon: Icon(Icons.link),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

String _projectLabel(ServerProject project) {
  return switch (project) {
    ServerProject.ohMyMedia => 'Oh-My-Media',
    ServerProject.dbOnline => 'DB Online',
  };
}
