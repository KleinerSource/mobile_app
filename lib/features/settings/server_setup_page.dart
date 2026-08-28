import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/files/file_source_config.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/files/smb_file_source.dart';
import '../../core/sources/files/webdav_file_source.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({
    super.key,
    this.editing = false,
    this.serverId,
    this.title,
  });

  final bool editing;
  final String? serverId;
  final String? title;

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _shareController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  String _scheme = 'http';
  String? _editingServerId;
  FileSourceConfig? _fileSourceConfig;
  ServerProject? _project;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing || widget.serverId != null) _loadEditingServer();
    _project ??= ServerProject.ohMyMedia;
  }

  void _loadEditingServer() {
    final saved =
        ref.read(serverConfigProvider) ??
        ref.read(serverConfigRepoProvider).load();
    if (saved == null) return;

    final requestedId = widget.serverId ?? saved.activeServerId;
    ServerProfile? server;
    for (final item in saved.servers) {
      if (item.id == requestedId) {
        server = item;
        break;
      }
    }
    server ??= saved.activeServer;
    if (server == null) return;

    _editingServerId = server.id;
    _project = server.project ?? ServerProject.ohMyMedia;
    _nameController.text = server.name;
    if (_project!.isFileSource) {
      _fileSourceConfig = _findFileSourceConfig(server.id);
      _fillFileSourceFields(_fileSourceConfig);
    } else {
      _fillHttpFields(server.activeLine?.baseUrl ?? saved.baseUrl);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _shareController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final project = _project;
    if (project == null) {
      _showError('请选择服务器类型');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showError('请输入服务器名称');
      return;
    }
    if (project.isFileSource) {
      await _testAndSaveFileSource(project);
      return;
    }

    final endpoint = _buildHttpEndpoint();
    if (endpoint == null) return;
    final normalized = ServerConfig.normalize(endpoint);
    final existing =
        ref.read(serverConfigProvider) ??
        ref.read(serverConfigRepoProvider).load();
    final editingServer = _findEditingServer(existing);
    if (_isDuplicateServer(
      existing,
      project,
      normalized,
      excludingServerId: editingServer?.id,
    )) {
      _showError('已存在相同连接的${_projectLabel(project)}服务器，不能重复添加');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final currentLine = editingServer?.activeLine;
      final sameServer =
          currentLine != null &&
          ServerConfig.normalize(currentLine.baseUrl) == normalized;
      final line = ServerLine(
        id: sameServer
            ? currentLine.id
            : 'main-${DateTime.now().microsecondsSinceEpoch}',
        name: sameServer ? currentLine.name : '主线路',
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

      final server = editingServer == null
          ? ServerProfile(
              id: 'server-${DateTime.now().microsecondsSinceEpoch}',
              name: _nameController.text.trim(),
              lines: [line],
              activeLineId: line.id,
              projectName: project.projectName,
              serverVersion: probe.versionInfo!.version,
            )
          : editingServer.copyWith(
              name: _nameController.text.trim(),
              lines: sameServer ? editingServer.lines : [line],
              activeLineId: sameServer ? editingServer.activeLineId : line.id,
              projectName: project.projectName,
              serverVersion: probe.versionInfo!.version,
            );
      await ref
          .read(serverConfigProvider.notifier)
          .saveServer(server, validatedProbe: probe);
      AppHaptics.medium();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testAndSaveFileSource(ServerProject project) async {
    final host = _hostController.text.trim();
    final port = _readPort();
    final share = _shareController.text.trim();
    if (host.isEmpty) {
      _showError('请输入主机');
      return;
    }
    if (port == null) {
      _showError('请输入 1-65535 之间的端口');
      return;
    }
    if (share.isEmpty) {
      _showError('请输入共享名');
      return;
    }

    final existing =
        ref.read(serverConfigProvider) ??
        ref.read(serverConfigRepoProvider).load();
    final editingServer = _findEditingServer(existing);
    final serverId =
        editingServer?.id ?? 'server-${DateTime.now().microsecondsSinceEpoch}';
    final sourceId = _fileSourceConfig?.id ?? serverId;
    final reference = _fileSourceConfig?.credentialRef.trim() ?? sourceId;
    final uri = project == ServerProject.webDav
        ? _buildWebDavEndpoint(_scheme, host, port, share)
        : null;
    final endpoint = project == ServerProject.smb
        ? _buildSmbEndpoint(host, port, share)
        : uri!;
    if (_isDuplicateServer(
      existing,
      project,
      endpoint,
      excludingServerId: editingServer?.id,
    )) {
      _showError('已存在相同连接的${_projectLabel(project)}服务器，不能重复添加');
      return;
    }
    final config = project == ServerProject.smb
        ? FileSourceConfig.smb(
            id: sourceId,
            name: _nameController.text.trim(),
            host: host,
            port: port,
            share: share,
            credentialRef: reference,
            serverId: serverId,
          )
        : FileSourceConfig.webDav(
            id: sourceId,
            name: _nameController.text.trim(),
            host: host,
            port: port,
            share: share,
            uri: uri!,
            credentialRef: reference,
            serverId: serverId,
          );
    if (!config.isValid) {
      _showError('请完整填写有效的文件服务器配置');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credentialsRepository = ref.read(
        fileSourceCredentialsRepositoryProvider,
      );
      final stored = await credentialsRepository.read(reference);
      final credentials = FileSourceCredentials(
        user: _userController.text.trim().isNotEmpty
            ? _userController.text.trim()
            : stored?.user ?? '',
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : stored?.password ?? '',
        domain: stored?.domain,
      );
      await _connectFileSource(project, config, credentials, serverId);
      await ref.read(fileSourceConfigRepositoryProvider).save(config);
      await credentialsRepository.save(reference, credentials);

      final line = ServerLine(
        id:
            editingServer?.activeLine?.id ??
            'main-${DateTime.now().microsecondsSinceEpoch}',
        name: '主线路',
        baseUrl: endpoint,
      );
      final server = editingServer == null
          ? ServerProfile(
              id: serverId,
              name: config.name,
              lines: [line],
              activeLineId: line.id,
              projectName: project.projectName,
            )
          : editingServer.copyWith(
              name: config.name,
              lines: [line],
              activeLineId: line.id,
              projectName: project.projectName,
              serverVersion: null,
            );
      await ref.read(serverConfigProvider.notifier).saveServer(server);
      ref.invalidate(fileSourceConfigsProvider);
      ref.invalidate(fileSourceRegistryProvider);
      AppHaptics.medium();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectFileSource(
    ServerProject project,
    FileSourceConfig config,
    FileSourceCredentials credentials,
    String serverId,
  ) async {
    switch (project) {
      case ServerProject.smb:
        final source = await SmbFileSource.connect(
          id: config.id,
          name: config.name,
          options: SmbConnectionOptions(
            host: config.host,
            port: config.port,
            share: config.share,
            user: credentials.user,
            password: credentials.password,
            domain: credentials.domain,
            workers: config.smbWorkers,
            timeoutSeconds: (config.timeoutMilliseconds / 1000).ceil(),
          ),
          serverId: serverId,
        );
        await source.dispose();
      case ServerProject.webDav:
        final source = await WebDavFileSource.connect(
          id: config.id,
          name: config.name,
          options: WebDavConnectionOptions(
            uri: config.uri!,
            port: config.port,
            user: credentials.user,
            password: credentials.password,
            timeoutMilliseconds: config.timeoutMilliseconds,
          ),
          serverId: serverId,
        );
        await source.dispose();
      case ServerProject.ohMyMedia:
      case ServerProject.dbOnline:
        throw StateError('当前服务器类型不是文件服务器');
    }
  }

  ServerProfile? _findEditingServer(ServerConfig? config) {
    if (config == null || _editingServerId == null) return null;
    for (final server in config.servers) {
      if (server.id == _editingServerId) return server;
    }
    return null;
  }

  FileSourceConfig? _findFileSourceConfig(String serverId) {
    for (final config
        in ref.read(fileSourceConfigRepositoryProvider).loadAll()) {
      if (config.serverId == serverId) return config;
    }
    return null;
  }

  bool _isDuplicateServer(
    ServerConfig? config,
    ServerProject project,
    String endpoint, {
    String? excludingServerId,
  }) {
    final normalizedEndpoint = _normalizeServerEndpoint(endpoint);
    return config?.servers.any((server) {
          if (server.id == excludingServerId || server.project != project) {
            return false;
          }
          return server.lines.any(
            (line) =>
                _normalizeServerEndpoint(line.baseUrl) == normalizedEndpoint,
          );
        }) ??
        false;
  }

  String _normalizeServerEndpoint(String raw) {
    final normalized = ServerConfig.normalize(raw);
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;
    final scheme = uri.scheme.toLowerCase();
    final port =
        uri.hasPort &&
            !((scheme == 'http' && uri.port == 80) ||
                (scheme == 'https' && uri.port == 443))
        ? uri.port
        : null;
    return uri
        .replace(scheme: scheme, host: uri.host.toLowerCase(), port: port)
        .toString();
  }

  void _fillHttpFields(String raw) {
    final uri = _tryParseUri(ServerConfig.normalize(raw));
    if (uri == null) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') _scheme = uri.scheme;
    _hostController.text = uri.host;
    _portController.text = (uri.hasPort ? uri.port : _defaultPort(_scheme))
        .toString();
  }

  void _fillFileSourceFields(FileSourceConfig? config) {
    if (config == null) return;
    if (config.protocol == FileSourceProtocol.webDav) {
      _scheme = Uri.parse(config.uri!).scheme;
    }
    _hostController.text = config.host;
    _portController.text = config.port.toString();
    _shareController.text = config.share;
  }

  String? _buildHttpEndpoint() {
    final host = _hostController.text.trim();
    final port = _readPort();
    if (host.isEmpty) {
      _showError('请输入主机');
      return null;
    }
    if (port == null) {
      _showError('请输入 1-65535 之间的端口');
      return null;
    }
    return Uri(scheme: _scheme, host: host, port: port).toString();
  }

  int? _readPort() {
    final port = int.tryParse(_portController.text.trim());
    return port != null && port >= 1 && port <= 65535 ? port : null;
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final project = _project ?? ServerProject.ohMyMedia;
    final editing = _editingServerId != null;
    final httpServer =
        project == ServerProject.ohMyMedia || project == ServerProject.dbOnline;
    final webDav = project == ServerProject.webDav;
    final fileServer = project.isFileSource;
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: '服务器',
              title: widget.title ?? (editing ? '更换服务器' : '连接到媒体服务器'),
              subtitle: editing ? '修改连接信息后重新测试并保存。' : '选择服务器类型并填写连接信息。',
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
                          value: project,
                          enabled: !_busy && !editing,
                          onChanged: (value) => setState(() {
                            _project = value;
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: '服务器名称',
                            prefixIcon: Icon(Icons.drive_file_rename_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (httpServer || webDav) ...[
                          _ProtocolSelector(
                            value: _scheme,
                            enabled: !_busy,
                            onChanged: (value) =>
                                setState(() => _scheme = value),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (fileServer || httpServer)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _hostController,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.url,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    labelText: '主机',
                                    hintText: project == ServerProject.smb
                                        ? '192.168.1.10'
                                        : 'example.com',
                                    prefixIcon: const Icon(
                                      Icons.computer_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 108,
                                child: TextField(
                                  controller: _portController,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '端口',
                                    hintText: '8001',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (fileServer) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _shareController,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: '共享名',
                              hintText: webDav ? 'dav/media' : 'media',
                              prefixIcon: const Icon(Icons.folder_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _userController,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '密码',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
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

  final ServerProject value;
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

class _ProtocolSelector extends StatelessWidget {
  const _ProtocolSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: settingsInputDecoration(
        context,
        labelText: '协议',
        prefixIcon: const Icon(Icons.http_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'http', child: Text('HTTP')),
            DropdownMenuItem(value: 'https', child: Text('HTTPS')),
          ],
          onChanged: enabled
              ? (value) {
                  if (value != null) {
                    AppHaptics.selection();
                    onChanged(value);
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
    ServerProject.smb => 'SMB',
    ServerProject.webDav => 'WebDAV',
  };
}

Uri? _tryParseUri(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  try {
    return Uri.parse(value);
  } on FormatException {
    return null;
  }
}

int _defaultPort(String scheme) => scheme == 'https' ? 443 : 80;

String _buildWebDavEndpoint(
  String scheme,
  String host,
  int port,
  String share,
) {
  final path = share.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  return Uri(scheme: scheme, host: host, port: port, path: '/$path').toString();
}

String _buildSmbEndpoint(String host, int port, String share) {
  final path = share.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  return Uri(scheme: 'smb', host: host, port: port, path: '/$path').toString();
}
