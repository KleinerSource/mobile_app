part of 'server_selection_page.dart';

// 状态及资源所有权保留在页面；此扩展只组织同一职责的方法。
extension _ServerSelectionOperations on _ServerSelectionPageState {
  Future<void> _refreshServers() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      _profileFutures.clear();
      _statusFutures.clear();
      if (!mounted) return;
      _updateViewState(() {});

      final config = ref.read(serverSelectionConfigProvider);
      final allServers = config?.servers ?? const <ServerProfile>[];
      final servers = allServers.length > 20
          ? _filterServers(allServers, AppL10n.of(context))
          : allServers;
      try {
        await Future.wait<void>([
          for (final server in servers) _profileFor(server).then<void>((_) {}),
          for (final server in servers) _statusFor(server).then<void>((_) {}),
        ]);
      } catch (_) {
        // 单台服务器探测失败不应让下拉刷新一直处于加载状态；卡片自身会
        // 根据 FutureBuilder 的结果显示对应状态。
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  void _openCreateServer() {
    AppHaptics.selection();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ServerSetupPage()));
  }

  Future<void> _editServer(ServerProfile server) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServerSetupPage(serverId: server.id),
      ),
    );
  }

  Future<void> _deleteServer(ServerProfile server) async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.serverDeleteTitle),
        content: Text(l.serverDeleteBody(server.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.serverCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.serverDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(serverConfigProvider.notifier).deleteServer(server.id);
      await ref.read(serverCredentialsRepositoryProvider).delete(server.id);
      AppHaptics.medium();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.serverDeleteFailed(toApiException(error).message)),
          ),
        );
      }
    }
  }

  Future<void> _selectServer(ServerProfile server) async {
    if (ref.read(serverSwitchTransitionProvider).isActive) return;
    final avatarContext = _avatarKeyFor(server.id).currentContext;
    final renderObject = avatarContext?.findRenderObject();
    final avatarOrigin = renderObject is RenderBox && renderObject.hasSize
        ? Rect.fromLTWH(
            renderObject.localToGlobal(Offset.zero).dx,
            renderObject.localToGlobal(Offset.zero).dy,
            renderObject.size.width,
            renderObject.size.height,
          )
        : null;
    await ref
        .read(serverSwitchTransitionProvider.notifier)
        .switchTo(
          server.id,
          allowActiveTarget: true,
          avatarOrigin: avatarOrigin,
          returnToSelectionOnCancel: true,
        );
    if (!mounted) return;
    await _completeSelectionIfReady(server.id);
  }

  Future<void> _completeSelectionIfReady(String serverId) async {
    if (!mounted ||
        ref.read(serverSelectionRequestedProvider) == false ||
        (ref.read(serverSwitchTransitionProvider).isActive &&
            ref.read(serverSwitchTransitionProvider).phase !=
                ServerSwitchPhase.finishing) ||
        ref.read(serverSelectionReadyProvider) == false ||
        ref.read(serverConfigProvider)?.activeServerId != serverId) {
      return;
    }
    ref.read(serverConfigProvider.notifier).completeServerSelection();
    if (widget.returnAfterSelection && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<ServerProfileData?> _profileFor(ServerProfile server) {
    return _profileFutures.putIfAbsent(server.id, () => _loadProfile(server));
  }

  Future<_ServerStatus> _statusFor(ServerProfile server) {
    // 状态由整组线路共同决定；只缓存当前线路会在备用线路变更后继续复用
    // 旧的失败结果，造成卡片红点与实际切换结果不一致。
    final key = [
      server.id,
      server.projectName,
      server.activeLineId,
      for (final line in server.lines)
        '${line.id}|${line.baseUrl}|${line.enabled}',
    ].join('|');
    return _statusFutures.putIfAbsent(key, () => _detectStatus(server));
  }

  Future<_ServerStatus> _detectStatus(ServerProfile server) async {
    final project = server.project;
    if (project == null) {
      return _ServerStatus.unavailable;
    }

    final candidates = server.lines
        .where((line) => line.enabled && line.baseUrl.trim().isNotEmpty)
        .toList();
    if (candidates.isEmpty) return _ServerStatus.unavailable;

    // SMB/WebDAV 的连接由文件浏览页在挂载来源时完成验证；选择器这里只
    // 反映是否存在启用线路，避免在卡片列表中重复创建文件源连接。
    if (project.isFileSource && project != ServerProject.openList) {
      return _ServerStatus.connected;
    }

    final activeLine = server.activeLine;
    final current =
        activeLine != null &&
            activeLine.enabled &&
            activeLine.baseUrl.trim().isNotEmpty
        ? activeLine
        : candidates.first;
    // 所有线路立即并发探测；任意线路成功就立刻继续状态判断，不等待其它
    // 慢线路超时。失败时才等待完整结果，以便保留“需要鉴权”的判断。
    final selection = await ref
        .read(serverLineProbeCoordinatorProvider)
        .selectPreferred(
          current: current,
          alternatives: candidates.where((line) => line.id != current.id),
          expectedProjectName: server.projectName,
        );
    final probe = selection.selected;
    if (probe == null) {
      return selection.results.any((result) => result.requiresAuthentication)
          ? _ServerStatus.authenticationRequired
          : _ServerStatus.unavailable;
    }

    // 线路探测结果已经足以更新状态；版本和延迟写回本地配置放到后台，
    // 避免配置写队列或磁盘 IO 阻塞首条成功线路的状态响应。
    unawaited(_persistProbeMetadata(server.id, probe));

    return _detectAuthentication(server, probe.line, project);
  }

  Future<void> _persistProbeMetadata(
    String serverId,
    ServerLineProbeResult probe,
  ) async {
    try {
      final version = probe.versionInfo?.version.trim();
      if (version?.isNotEmpty == true) {
        await ref
            .read(serverConfigProvider.notifier)
            .saveServerVersion(serverId, version!);
      }
      await ref
          .read(serverConfigProvider.notifier)
          .saveServerLineProbe(serverId, probe);
    } catch (_) {
      // 本地元数据写回失败不应影响已经完成的服务器状态判断。
    }
  }

  Future<_ServerStatus> _detectAuthentication(
    ServerProfile server,
    ServerLine line,
    ServerProject project,
  ) async {
    if (project.isFileSource) return _ServerStatus.connected;

    final config = ServerConfig(
      baseUrl: line.baseUrl,
      lines: [line],
      servers: [server],
      activeServerId: server.id,
    );
    final sessionRepository = ref
        .read(authSessionRepositoryProvider)
        .forServer(server.id, allowLegacyMigration: false);
    // DB Online 的鉴权是必选项，没有本地会话即可确定为“需要鉴权”，
    // 避免为每张卡片额外发起一个必然返回 401 的请求。
    if (project == ServerProject.dbOnline) {
      final session = await sessionRepository.load();
      if (session == null || !session.hasAccessToken) {
        return _ServerStatus.authenticationRequired;
      }
    }
    final client = ApiClient.fromConfig(
      config,
      sessionRepository: sessionRepository,
      stashApiKeyRepository: ref.read(stashApiKeyRepositoryProvider),
    );

    try {
      if (project == ServerProject.stash) {
        final key = await ref
            .read(serverCredentialsRepositoryProvider)
            .readApiKey(server.id);
        if (key == null) return _ServerStatus.authenticationRequired;
        await client.stash.validateApiKey(key);
        return _ServerStatus.connected;
      }
      if (project == ServerProject.emby || project == ServerProject.jellyfin) {
        final session = await sessionRepository.load();
        if (session == null || !session.hasAccessToken) {
          return _ServerStatus.authenticationRequired;
        }
        final mediaConfig = MediaBrowserConfig.byProject[project]!;
        await client
            .mediaBrowserFor(mediaConfig)
            .validateSession(session.userId);
        return _ServerStatus.connected;
      }
      if (project == ServerProject.feiniu) {
        await client.feiniu.userInfo();
        return _ServerStatus.connected;
      }

      final authStatus = await client.auth.status();
      if (!authStatus.enabled || !authStatus.configured) {
        return _ServerStatus.connected;
      }
      if (project == ServerProject.dbOnline) {
        final session = await sessionRepository.load();
        if (session == null ||
            !session.hasAccessToken ||
            !await client.auth.verify()) {
          return _ServerStatus.authenticationRequired;
        }
        return _ServerStatus.connected;
      }
      final session = await sessionRepository.load();
      return authStatus.authenticated && session?.isUsable == true
          ? _ServerStatus.connected
          : _ServerStatus.authenticationRequired;
    } catch (error) {
      final exception = toApiException(error);
      return exception.status == 401 || exception.status == 403
          ? _ServerStatus.authenticationRequired
          : _ServerStatus.unavailable;
    } finally {
      client.close();
    }
  }

  Future<ServerProfileData?> _loadProfile(ServerProfile server) async {
    if (server.project == ServerProject.ohMyMedia) {
      return ServerProfileData(name: server.name);
    }
    final cached = _cachedProfileFor(server);
    final project = server.project;
    if (project == ServerProject.emby ||
        project == ServerProject.jellyfin ||
        project == ServerProject.feiniu) {
      return _loadMediaBrowserProfile(server, cached, project!);
    }
    if (project != ServerProject.ohMyMedia) {
      final profile = ServerProfileData(
        name: server.name,
        avatarUrl: server.avatarUrl,
      );
      return profile;
    }
    return cached;
  }

  Future<ServerProfileData?> _loadMediaBrowserProfile(
    ServerProfile server,
    ServerProfileData? cached,
    ServerProject project,
  ) async {
    if (project == ServerProject.emby || project == ServerProject.jellyfin) {
      return loadMediaBrowserUserProfile(ref.read, server);
    }

    final sessionRepository = ref
        .read(authSessionRepositoryProvider)
        .forServer(server.id, allowLegacyMigration: false);

    final line = server.activeLine;
    if (line == null) return _fallbackProfile(server);

    ApiClient? client;
    try {
      final session = await sessionRepository.load();
      if (session == null || !session.hasAccessToken) {
        return _fallbackProfile(server);
      }
      client = ApiClient.fromConfig(
        ServerConfig(
          baseUrl: line.baseUrl,
          lines: [line],
          servers: [server],
          activeServerId: server.id,
        ),
        sessionRepository: sessionRepository,
        stashApiKeyRepository: ref.read(stashApiKeyRepositoryProvider),
      );
      final mediaBrowserConfig = MediaBrowserConfig.byProject[project];
      if (mediaBrowserConfig == null) {
        return _fallbackProfile(server);
      }
      final normalizedName = (await client.feiniu.userInfo()).name.trim();
      if (normalizedName.isEmpty) {
        return _fallbackProfile(server);
      }
      final profile = ServerProfileData(
        name: normalizedName,
        avatarUrl: server.avatarUrl ?? cached?.avatarUrl,
      );
      await ref.read(serverProfileCacheRepoProvider).save(server.id, profile);
      return profile;
    } catch (_) {
      return _fallbackProfile(server);
    } finally {
      client?.close();
    }
  }
}
