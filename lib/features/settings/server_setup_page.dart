import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({super.key, this.editing = false, this.serverId});

  final bool editing;
  final String? serverId;

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  final _controller = TextEditingController();
  ServerConfig? _savedConfig;
  String? _editingServerId;
  ServerProject? _project;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing || widget.serverId != null) {
      _savedConfig =
          ref.read(serverConfigProvider) ??
          ref.read(serverConfigRepoProvider).load();
      if (_savedConfig != null) {
        final requestedId = widget.serverId ?? _savedConfig!.activeServerId;
        ServerProfile? server;
        for (final item in _savedConfig!.servers) {
          if (item.id == requestedId) {
            server = item;
            break;
          }
        }
        server ??= _savedConfig!.activeServer;
        if (server != null) {
          _editingServerId = server.id;
          _controller.text =
              server.activeLine?.baseUrl ?? _savedConfig!.baseUrl;
          _project = server.project;
        }
      }
    }
    if (_controller.text.isEmpty) _controller.text = 'http://';
    _project ??= ServerProject.ohMyMedia;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '请输入服务器地址');
      return;
    }
    final normalized = ServerConfig.normalize(raw);
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      setState(() => _error = '地址必须以 http:// 或 https:// 开头');
      return;
    }
    final project = _project;
    if (project == null) {
      setState(() => _error = '请选择服务器类型');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final existing =
          ref.read(serverConfigProvider) ??
          ref.read(serverConfigRepoProvider).load();
      ServerProfile? editingServer;
      if (_editingServerId != null && existing != null) {
        for (final server in existing.servers) {
          if (server.id == _editingServerId) {
            editingServer = server;
            break;
          }
        }
      }
      final sameServer =
          editingServer != null &&
          editingServer.activeLine?.baseUrl == normalized;
      final line = ServerLine(
        id: sameServer
            ? editingServer.lines
                  .firstWhere(
                    (item) => item.baseUrl == normalized,
                    orElse: () => editingServer!.lines.first,
                  )
                  .id
            : 'main-${DateTime.now().microsecondsSinceEpoch}',
        name: '主线路',
        baseUrl: normalized,
      );
      final probe = await ref
          .read(serverLineProbeCoordinatorProvider)
          .probe(line, expectedProjectName: project.projectName);
      if (!probe.success || probe.versionInfo == null) {
        throw ServerCompatibilityException(
          probe.message.isEmpty ? '服务器版本检测失败' : probe.message,
        );
      }
      final versionInfo = probe.versionInfo!;
      final ServerConfig? config;
      final ServerProfile? newServer;
      if (editingServer != null && existing != null) {
        newServer = null;
        final updatedServer = editingServer.copyWith(
          lines: sameServer ? editingServer.lines : [line],
          activeLineId: sameServer ? editingServer.activeLineId : line.id,
          projectName: project.projectName,
          serverVersion: versionInfo.version,
        );
        final servers = existing.servers
            .map(
              (server) =>
                  server.id == editingServer!.id ? updatedServer : server,
            )
            .toList();
        ServerProfile? activeServer;
        for (final server in servers) {
          if (server.id == existing.activeServerId) {
            activeServer = server;
            break;
          }
        }
        activeServer ??= servers.first;
        config = existing.copyWith(
          baseUrl: activeServer.activeLine?.baseUrl ?? existing.baseUrl,
          lines: activeServer.lines,
          servers: servers,
          activeServerId: activeServer.id,
        );
      } else {
        final server = ServerProfile(
          id: 'server-${DateTime.now().microsecondsSinceEpoch}',
          name: project.displayName,
          lines: [line],
          activeLineId: line.id,
          projectName: project.projectName,
          serverVersion: versionInfo.version,
        );
        newServer = server;
        config = null;
      }
      if (newServer != null) {
        // 追加服务器时在保存时读取最新配置，避免后台鉴权探测使用旧快照
        // 覆盖用户刚刚添加的其它服务器。
        await ref.read(serverConfigProvider.notifier).saveServer(newServer);
      } else {
        await ref.read(serverConfigProvider.notifier).save(config!);
      }
      _savedConfig = ref.read(serverConfigProvider);
      AppHaptics.medium();
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      final exception = toApiException(e);
      setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final editing = _editingServerId != null;
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: '服务器',
              title: editing ? '更换服务器' : '连接到媒体服务器',
              subtitle: editing
                  ? '修改服务器地址后重新测试连接。'
                  : '输入服务器地址，包含协议和端口。\n例：http://192.168.1.10:8001',
              showBackButton: Navigator.of(context).canPop(),
            ),
            body: ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
              children: [
                GlassPanel(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('服务器类型', style: AppText.cardTitle(context)),
                        const SizedBox(height: 10),
                        _ProjectSelector(
                          value: _project,
                          enabled: !_busy && !editing,
                          onChanged: (value) =>
                              setState(() => _project = value),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.dns_outlined,
                                color: c.accent,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '服务器地址',
                                  style: AppText.cardTitle(context),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'SERVER URL',
                                  style: AppText.eyebrow(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            style: TextStyle(
                              color: c.text,
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'http://192.168.1.10:8001',
                              hintStyle: TextStyle(
                                color: c.muted2,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.link,
                                color: c.muted,
                                size: 19,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: c.danger.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: c.danger.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: c.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: c.danger,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSaveButton(
                  onPressed: _testAndSave,
                  saving: _busy,
                  label: '测试并保存',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectSelector extends StatelessWidget {
  const _ProjectSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ServerProject? value;
  final bool enabled;
  final ValueChanged<ServerProject> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: settingsInputDecoration(
        context,
        prefixIcon: const Icon(Icons.dns_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ServerProject>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            for (final project in ServerProject.values)
              DropdownMenuItem(
                value: project,
                child: Text(_projectLabel(project)),
              ),
          ],
          onChanged: enabled
              ? (project) {
                  if (project != null && project != value) {
                    AppHaptics.selection();
                    onChanged(project);
                  }
                }
              : null,
        ),
      ),
    );
  }
}

String _projectLabel(ServerProject project) {
  return switch (project) {
    ServerProject.ohMyMedia => 'Oh-My-Media',
    ServerProject.dbOnline => 'DB Online',
  };
}
