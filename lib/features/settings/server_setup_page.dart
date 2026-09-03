import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/auth/totp_code.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/config/server_line_probe.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/sources/files/file_source_config.dart';
import '../../core/sources/files/file_source_providers.dart';
import '../../core/sources/files/openlist_api.dart';
import '../../core/sources/files/openlist_file_source.dart';
import '../../core/sources/files/smb_file_source.dart';
import '../../core/sources/files/webdav_file_source.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import '../../shared/server_avatar.dart';
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
  final _pathController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpSecretController = TextEditingController();

  String _scheme = 'http';
  String? _editingServerId;
  FileSourceConfig? _fileSourceConfig;
  ServerProject? _project;
  bool _busy = false;
  String? _error;
  // 编辑模式下是否存在已保存的 TOTP 密钥，以及用户是否要求清除它。
  bool _hasStoredTotpSecret = false;
  bool _clearTotpSecret = false;

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
      _fillHttpFields(server.activeLine?.baseUrl ?? saved.baseUrl, _project!);
      _loadStoredTotpSecret(server.id);
    }
  }

  Future<void> _loadStoredTotpSecret(String serverId) async {
    try {
      final secret = await ref
          .read(authSessionRepositoryProvider)
          .forServer(serverId, allowLegacyMigration: false)
          .readTotpSecret();
      if (mounted && secret != null) {
        setState(() => _hasStoredTotpSecret = true);
      }
    } catch (_) {
      // 读取失败按未配置处理，不影响编辑其他字段。
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _pathController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _totpSecretController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final l = AppL10n.of(context);
    final project = _project;
    if (project == null) {
      _showError(l.serverSetupSelectProject);
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showError(l.serverSetupNameRequired);
      return;
    }
    if (project.isFileSource) {
      await _testAndSaveFileSource(project);
      return;
    }

    final endpoint = _buildHttpEndpoint(project);
    if (endpoint == null) return;
    final normalized = ServerConfig.normalizeForProject(endpoint, project);
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
      _showError(
        AppL10n.of(
          context,
        ).serverSetupDuplicate(_projectLabel(AppL10n.of(context), project)),
      );
      return;
    }

    // 可选登录凭据：填写了就在保存前完成登录验证；TOTP 密钥只对
    // OMM/DBO 的密码鉴权有意义，其他 HTTP 类型没有该概念。
    final needsUsername =
        project == ServerProject.emby ||
        project == ServerProject.jellyfin ||
        project == ServerProject.feiniu;
    final passwordAuth =
        project == ServerProject.ohMyMedia || project == ServerProject.dbOnline;
    final username = _userController.text.trim();
    final password = _passwordController.text;
    final totpSecretRaw = passwordAuth
        ? _totpSecretController.text.trim()
        : '';
    final wantsLogin =
        password.isNotEmpty || (needsUsername && username.isNotEmpty);
    if (wantsLogin && needsUsername && username.isEmpty) {
      _showError(l.serverSetupLoginUsernameRequired);
      return;
    }
    String? normalizedTotpSecret;
    if (totpSecretRaw.isNotEmpty) {
      normalizedTotpSecret = normalizeTotpSecret(totpSecretRaw);
      if (normalizedTotpSecret == null) {
        _showError(l.serverSetupTotpKeyInvalid);
        return;
      }
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
      if (!mounted) return;
      if (!probe.success || probe.versionInfo == null) {
        throw ServerCompatibilityException(
          probe.message.isEmpty
              ? AppL10n.of(context).serverLineProbeFailed
              : probe.message,
        );
      }

      // 会话与 TOTP 密钥都按服务器 ID 作用域存储，先固定 ID 再登录，
      // 保证与最终保存的 ServerProfile 一致。
      final serverId =
          editingServer?.id ??
          'server-${DateTime.now().microsecondsSinceEpoch}';
      final server = editingServer == null
          ? ServerProfile(
              id: serverId,
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
      if (wantsLogin) {
        try {
          await ref
              .read(authControllerProvider.notifier)
              .loginForServer(
                server: server,
                username: needsUsername ? username : null,
                password: password,
                totpSecret: normalizedTotpSecret,
              );
        } on ApiException catch (error) {
          final data = error.data;
          if (data is Map && data['totp_required'] == true) {
            throw ApiException(l.serverSetupTotpRequired);
          }
          rethrow;
        }
      }
      await ref
          .read(serverConfigProvider.notifier)
          .saveServer(server, validatedProbe: probe);
      await _persistTotpSecret(server.id, normalizedTotpSecret);
      AppHaptics.medium();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 保存/清除服务器作用域的 TOTP 密钥（服务器配置保存成功后调用）。
  Future<void> _persistTotpSecret(
    String serverId,
    String? normalizedSecret,
  ) async {
    try {
      final repository = ref
          .read(authSessionRepositoryProvider)
          .forServer(serverId, allowLegacyMigration: false);
      if (normalizedSecret != null) {
        await repository.saveTotpSecret(normalizedSecret);
      } else if (_clearTotpSecret) {
        await repository.deleteTotpSecret();
      }
    } catch (_) {
      // 密钥持久化失败不影响服务器保存结果，登录页仍可手动输入验证码。
    }
  }

  Future<void> _testAndSaveFileSource(ServerProject project) async {
    final l = AppL10n.of(context);
    final host = _hostController.text.trim();
    final port = _readPort(project);
    final path = _pathController.text.trim();
    final username = _userController.text.trim();
    final password = _passwordController.text;
    final editing = _editingServerId != null;
    if (host.isEmpty) {
      _showError(l.serverSetupHostRequired);
      return;
    }
    if (port == null) {
      _showError(l.serverSetupPortInvalid);
      return;
    }
    if (path.isEmpty) {
      _showError(l.serverSetupPathRequired);
      return;
    }
    if (!editing &&
        (project == ServerProject.smb || project == ServerProject.openList) &&
        username.isEmpty) {
      _showError(l.serverSetupUserRequired);
      return;
    }
    if (!editing && project == ServerProject.openList && password.isEmpty) {
      _showError(l.serverSetupPasswordRequired);
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
    final uri = switch (project) {
      ServerProject.webDav => _buildWebDavEndpoint(_scheme, host, port, path),
      // OpenList 文件管理走内置 /dav 前缀，路径字段是实例内的根路径。
      ServerProject.openList => _buildOpenListEndpoint(
        _scheme,
        host,
        port,
        path,
      ),
      _ => null,
    };
    final endpoint = project == ServerProject.smb
        ? _buildSmbEndpoint(host, port, path)
        : uri!;
    if (_isDuplicateServer(
      existing,
      project,
      endpoint,
      excludingServerId: editingServer?.id,
    )) {
      _showError(
        AppL10n.of(
          context,
        ).serverSetupDuplicate(_projectLabel(AppL10n.of(context), project)),
      );
      return;
    }
    final config = switch (project) {
      ServerProject.smb => FileSourceConfig.smb(
        id: sourceId,
        name: _nameController.text.trim(),
        host: host,
        port: port,
        path: path,
        credentialRef: reference,
        serverId: serverId,
      ),
      ServerProject.webDav => FileSourceConfig.webDav(
        id: sourceId,
        name: _nameController.text.trim(),
        host: host,
        port: port,
        path: path,
        uri: uri!,
        credentialRef: reference,
        serverId: serverId,
      ),
      ServerProject.openList => FileSourceConfig.openList(
        id: sourceId,
        name: _nameController.text.trim(),
        host: host,
        port: port,
        path: path,
        uri: uri!,
        credentialRef: reference,
        serverId: serverId,
      ),
      ServerProject.ohMyMedia ||
      ServerProject.dbOnline ||
      ServerProject.emby ||
      ServerProject.jellyfin ||
      ServerProject.feiniu => null,
    };
    if (config == null || !config.isValid) {
      _showError(AppL10n.of(context).serverSetupInvalidFileConfig);
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
        user: username.isNotEmpty ? username : stored?.user ?? '',
        password: password.isNotEmpty ? password : stored?.password ?? '',
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
      ServerLineProbeResult? validatedProbe;
      if (project == ServerProject.openList) {
        final probe = await ref
            .read(serverLineProbeCoordinatorProvider)
            .probe(line, expectedProjectName: project.projectName);
        if (!mounted) return;
        if (!probe.success || probe.versionInfo == null) {
          throw ServerCompatibilityException(
            probe.message.isEmpty
                ? AppL10n.of(context).serverLineProbeFailed
                : probe.message,
          );
        }
        validatedProbe = probe;
      }
      final serverVersion = validatedProbe?.versionInfo?.version;
      final server = editingServer == null
          ? ServerProfile(
              id: serverId,
              name: config.name,
              lines: [line],
              activeLineId: line.id,
              projectName: project.projectName,
              serverVersion: serverVersion,
            )
          : editingServer.copyWith(
              name: config.name,
              lines: [line],
              activeLineId: line.id,
              projectName: project.projectName,
              serverVersion: serverVersion,
            );
      await ref
          .read(serverConfigProvider.notifier)
          .saveServer(server, validatedProbe: validatedProbe);
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
            path: config.path,
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
      case ServerProject.openList:
        final source = await OpenListFileSource.connect(
          id: config.id,
          name: config.name,
          options: OpenListConnectionOptions(
            uri: config.uri!,
            port: config.port,
            path: config.path,
            user: credentials.user,
            password: credentials.password,
            timeoutMilliseconds: config.timeoutMilliseconds,
          ),
          serverId: serverId,
        );
        await source.dispose();
      case ServerProject.ohMyMedia:
      case ServerProject.dbOnline:
      case ServerProject.emby:
      case ServerProject.jellyfin:
      case ServerProject.feiniu:
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
    final normalizedEndpoint = _normalizeServerEndpoint(endpoint, project);
    return config?.servers.any((server) {
          if (server.id == excludingServerId || server.project != project) {
            return false;
          }
          return server.lines.any(
            (line) =>
                _normalizeServerEndpoint(line.baseUrl, project) ==
                normalizedEndpoint,
          );
        }) ??
        false;
  }

  String _normalizeServerEndpoint(String raw, [ServerProject? project]) {
    final normalized = project == null
        ? ServerConfig.normalize(raw)
        : ServerConfig.normalizeForProject(raw, project);
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

  void _fillHttpFields(String raw, ServerProject project) {
    final uri = _tryParseUri(ServerConfig.normalize(raw));
    if (uri == null) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') _scheme = uri.scheme;
    _hostController.text = uri.host;
    _portController.text =
        (uri.hasPort ? uri.port : defaultServerPort(project, scheme: _scheme))
            .toString();
  }

  void _fillFileSourceFields(FileSourceConfig? config) {
    if (config == null) return;
    if (config.protocol == FileSourceProtocol.webDav ||
        config.protocol == FileSourceProtocol.openList) {
      _scheme = Uri.parse(config.uri!).scheme;
    }
    _hostController.text = config.host;
    _portController.text = config.port.toString();
    _pathController.text = config.path;
  }

  String? _buildHttpEndpoint(ServerProject project) {
    final l = AppL10n.of(context);
    final host = _hostController.text.trim();
    final port = _readPort(project);
    if (host.isEmpty) {
      _showError(l.serverSetupHostRequired);
      return null;
    }
    if (port == null) {
      _showError(l.serverSetupPortInvalid);
      return null;
    }
    return ServerConfig.normalizeForProject(
      Uri(scheme: _scheme, host: host, port: port).toString(),
      project,
    );
  }

  int? _readPort(ServerProject project) {
    final raw = _portController.text.trim();
    if (raw.isEmpty) {
      return defaultServerPort(project, scheme: _scheme);
    }
    final port = int.tryParse(raw);
    return port != null && port >= 1 && port <= 65535 ? port : null;
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final project = _project ?? ServerProject.ohMyMedia;
    final editing = _editingServerId != null;
    final httpServer =
        project == ServerProject.ohMyMedia ||
        project == ServerProject.dbOnline ||
        project == ServerProject.emby ||
        project == ServerProject.jellyfin ||
        project == ServerProject.feiniu;
    final webDav = project == ServerProject.webDav;
    final openList = project == ServerProject.openList;
    final httpLike = webDav || openList;
    final fileServer = project.isFileSource;
    final needsUsername =
        project == ServerProject.emby ||
        project == ServerProject.jellyfin ||
        project == ServerProject.feiniu;
    final passwordAuth =
        project == ServerProject.ohMyMedia || project == ServerProject.dbOnline;
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsGroupServer,
              title:
                  widget.title ??
                  (editing
                      ? l.serverSetupReplaceTitle
                      : l.serverSetupConnectTitle),
              subtitle: editing
                  ? l.serverSetupEditSubtitle
                  : l.serverSetupNewSubtitle,
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
                        Text(
                          l.serverSetupProjectLabel,
                          style: AppText.cardTitle(context),
                        ),
                        const SizedBox(height: 10),
                        _ProjectSelector(
                          value: project,
                          enabled: !_busy && !editing,
                          onChanged: (value) => setState(() {
                            final previous = _project;
                            _project = value;
                            _error = null;
                            // 跨文件源/HTTP 或 HTTP 类型之间切换时清空凭据，
                            // 避免把上一类型的用户名/密码误用到新类型登录。
                            final bothFileSources =
                                previous?.isFileSource == true &&
                                value.isFileSource;
                            if (!bothFileSources) {
                              _userController.clear();
                              _passwordController.clear();
                              _totpSecretController.clear();
                              _clearTotpSecret = false;
                            }
                            if (value == ServerProject.openList &&
                                _pathController.text.trim().isEmpty) {
                              _pathController.text = '/';
                            }
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameController,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: l.serverSetupNameLabel,
                            prefixIcon: const Icon(
                              Icons.drive_file_rename_outline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (httpServer || httpLike) ...[
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
                                    labelText: l.serverSetupHostLabel,
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
                                  decoration: InputDecoration(
                                    labelText: l.serverSetupPortLabel,
                                    hintText: defaultServerPort(
                                      project,
                                      scheme: _scheme,
                                    ).toString(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (fileServer) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pathController,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: openList
                                  ? l.serverSetupRootPathLabel
                                  : l.serverSetupPathLabel,
                              hintText: switch (project) {
                                ServerProject.smb => l.serverSetupPathHintSmb,
                                ServerProject.webDav => 'dav/media',
                                ServerProject.openList =>
                                  l.serverSetupPathHintOpenList,
                                _ => '/',
                              },
                              prefixIcon: const Icon(Icons.folder_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _userController,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: editing
                                  ? l.serverSetupUserEditLabel
                                  : (openList || project == ServerProject.smb)
                                  ? l.serverSetupUserLabel
                                  : l.serverSetupUserOptionalGenericLabel,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: editing
                                  ? l.serverSetupPasswordEditLabel
                                  : openList
                                  ? l.serverSetupPasswordLabel
                                  : l.serverSetupPasswordOptionalLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
                        if (httpServer) ...[
                          const SizedBox(height: 12),
                          if (needsUsername) ...[
                            TextField(
                              controller: _userController,
                              enabled: !_busy,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: editing
                                    ? l.serverSetupUserEditLabel
                                    : l.serverSetupUserOptionalGenericLabel,
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: editing
                                  ? l.serverSetupPasswordEditLabel
                                  : l.serverSetupPasswordOptionalLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                          if (passwordAuth) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _totpSecretController,
                              enabled: !_busy,
                              autocorrect: false,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: editing
                                    ? l.serverSetupTotpKeyEditLabel
                                    : l.serverSetupTotpKeyLabel,
                                helperText: l.serverSetupTotpKeyHint,
                                prefixIcon: const Icon(Icons.password_outlined),
                                suffixIcon:
                                    _hasStoredTotpSecret &&
                                        _totpSecretController.text.isEmpty
                                    ? IconButton(
                                        tooltip: l.serverSetupTotpClearStored,
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: _busy
                                            ? null
                                            : () => setState(() {
                                                _clearTotpSecret = true;
                                                _hasStoredTotpSecret = false;
                                              }),
                                      )
                                    : null,
                              ),
                            ),
                          ],
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
                  label: l.serverTestAndSave,
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
    final c = appColors(context);
    return InputDecorator(
      decoration: settingsInputDecoration(
        context,
        prefixIcon: const Icon(Icons.dns_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ServerProject>(
          value: value,
          isExpanded: true,
          isDense: true,
          itemHeight: null,
          style: TextStyle(
            color: c.text,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final project in ServerProject.values)
              DropdownMenuItem(
                value: project,
                child: _ProjectMenuItem(
                  project: project,
                  showDivider: project == ServerProject.smb,
                  colors: c,
                ),
              ),
          ],
          // 菜单项带头像和分组标题，关闭状态仍保持单行紧凑展示。
          selectedItemBuilder: (context) => [
            for (final project in ServerProject.values)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(_projectLabel(AppL10n.of(context), project)),
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
    final c = appColors(context);
    return InputDecorator(
      decoration: settingsInputDecoration(
        context,
        labelText: AppL10n.of(context).serverSetupProtocolLabel,
        prefixIcon: const Icon(Icons.http_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: c.text,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
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

class _ProjectMenuItem extends StatelessWidget {
  const _ProjectMenuItem({
    required this.project,
    required this.showDivider,
    required this.colors,
  });

  final ServerProject project;
  final bool showDivider;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Divider(height: 1, color: colors.divider),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              ServerAvatar(
                displayName: _projectLabel(AppL10n.of(context), project),
                avatarUrl: null,
                size: 30,
                colors: colors,
                project: project,
                showBackground: false,
                showBorder: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_projectLabel(AppL10n.of(context), project)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _projectLabel(AppL10n l, ServerProject project) {
  return switch (project) {
    ServerProject.ohMyMedia => 'Oh My Media',
    ServerProject.dbOnline => 'DB Online',
    ServerProject.emby => 'Emby',
    ServerProject.jellyfin => 'Jellyfin',
    ServerProject.feiniu => l.serverProjectFeiniu,
    ServerProject.smb => 'SMB',
    ServerProject.webDav => 'WebDAV',
    ServerProject.openList => 'OpenList',
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

String _buildWebDavEndpoint(String scheme, String host, int port, String path) {
  final normalizedPath = path
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '');
  return Uri(
    scheme: scheme,
    host: host,
    port: port,
    path: '/$normalizedPath',
  ).toString();
}

String _buildOpenListEndpoint(
  String scheme,
  String host,
  int port,
  String path,
) {
  // /dav 前缀内置到端点中，用户只填实例内的根路径。
  final normalizedPath = path
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '');
  final suffix = normalizedPath.isEmpty || normalizedPath == '/'
      ? ''
      : '/$normalizedPath';
  return Uri(
    scheme: scheme,
    host: host,
    port: port,
    path: '/dav$suffix',
  ).toString();
}

String _buildSmbEndpoint(String host, int port, String path) {
  final normalizedPath = path
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '');
  return Uri(
    scheme: 'smb',
    host: host,
    port: port,
    path: normalizedPath.isEmpty ? '/' : '/$normalizedPath',
  ).toString();
}
