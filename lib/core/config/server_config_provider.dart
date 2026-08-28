import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/server_compatibility.dart';
import 'server_config.dart';
import 'server_line_probe.dart';
import 'server_config_repository.dart';
import 'server_profile_cache_repository.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('在 main.dart 用 overrideWithValue 注入');
});

final serverConfigRepoProvider = Provider<ServerConfigRepository>((ref) {
  return ServerConfigRepository(ref.watch(sharedPrefsProvider));
});

final serverProfileCacheRepoProvider = Provider<ServerProfileCacheRepository>((
  ref,
) {
  return ServerProfileCacheRepository(ref.watch(sharedPrefsProvider));
});

final serverLineProbeCoordinatorProvider = Provider<ServerLineProbeCoordinator>(
  (ref) {
    return ServerLineProbeCoordinator();
  },
);

/// 多服务器启动选择只在当前进程首次进入时显示一次。
final serverSelectionReadyProvider = StateProvider<bool>((ref) => false);

/// 已登录页面主动返回服务器选择器时，要求根页面卸载当前服务器内容。
final serverSelectionRequestedProvider = StateProvider<bool>((ref) => false);

/// 防止同一次边缘返回同时打开多个选择器路由。
final serverSelectionRouteActiveProvider = StateProvider<bool>((ref) => false);

class ServerConfigNotifier extends Notifier<ServerConfig?> {
  Future<void> _configWriteQueue = Future<void>.value();

  @override
  ServerConfig? build() {
    return ref.watch(serverConfigRepoProvider).load();
  }

  Future<void> save(ServerConfig cfg) {
    return _enqueueConfigWrite(() => _saveNow(cfg));
  }

  Future<void> _saveNow(ServerConfig cfg) async {
    final baseUrl = ServerConfig.normalize(cfg.baseUrl);
    ServerProfile? selectedServer;
    for (final server in cfg.servers) {
      if (server.id == cfg.activeServerId) {
        selectedServer = server;
        break;
      }
    }
    final currentLines = _normalizeLines(
      cfg.lines.isNotEmpty ? cfg.lines : selectedServer?.lines ?? const [],
      baseUrl,
    );
    final servers = cfg.servers
        .map(
          (server) => server.copyWith(lines: _normalizeLines(server.lines, '')),
        )
        .where((server) => server.lines.isNotEmpty)
        .toList();

    if (servers.isEmpty) {
      throw StateError('服务器配置缺少明确的服务器类型');
    }

    final activeServerId =
        servers.any((server) => server.id == cfg.activeServerId)
        ? cfg.activeServerId!
        : servers.first.id;
    final shouldReplaceActiveLines =
        cfg.lines.isNotEmpty || selectedServer == null;
    final updatedServers = servers
        .map(
          (server) => server.id == activeServerId
              ? shouldReplaceActiveLines
                    ? server.copyWith(
                        lines: currentLines,
                        activeLineId: _lineForUrl(currentLines, baseUrl).id,
                      )
                    : server
              : server,
        )
        .toList();
    final activeServer = updatedServers.firstWhere(
      (server) => server.id == activeServerId,
    );
    final activeLine = activeServer.activeLine ?? activeServer.lines.first;
    final normalized = ServerConfig(
      baseUrl: activeLine.baseUrl,
      lines: activeServer.lines,
      servers: updatedServers,
      activeServerId: activeServer.id,
    );

    final repository = ref.read(serverConfigRepoProvider);
    await repository.save(normalized);
    state = repository.load();
  }

  Future<void> selectServer(String serverId) async {
    final current = state ?? ref.read(serverConfigRepoProvider).load();
    if (current == null) return;
    final server = current.servers.firstWhere(
      (item) => item.id == serverId,
      orElse: () => throw StateError('服务器不存在'),
    );

    if (server.project?.isFileSource == true) {
      await saveServer(server, select: true);
      ref.read(serverSelectionReadyProvider.notifier).state = true;
      return;
    }

    final candidates = server.lines.where((line) => line.enabled).toList();
    if (candidates.isEmpty) {
      throw StateError('目标服务器没有启用线路');
    }
    final preferred = server.activeLine;
    final currentLine = preferred != null && preferred.enabled
        ? preferred
        : candidates.first;
    final selection = await ref
        .read(serverLineProbeCoordinatorProvider)
        .selectPreferred(
          current: currentLine,
          alternatives: candidates.where((line) => line.id != currentLine.id),
          expectedProjectName: server.projectName,
        );
    final selected = selection.selected;
    if (selected == null) {
      final message = _lineSelectionFailureMessage(selection);
      if (selection.results.any((result) => result.incompatible)) {
        throw ServerCompatibilityException(message);
      }
      throw StateError(message);
    }

    final testedAt = DateTime.now();
    final testedLines = server.lines
        .map(
          (line) => line.id == selected.line.id
              ? line.copyWith(
                  latencyMs: selected.latencyMs,
                  lastTestedAt: testedAt,
                )
              : line,
        )
        .toList();
    await saveServer(
      server.copyWith(
        lines: testedLines,
        activeLineId: selected.line.id,
        serverVersion: selected.versionInfo?.version ?? server.serverVersion,
      ),
      select: true,
      validatedProbe: selected,
    );
    ref.read(serverSelectionReadyProvider.notifier).state = true;
  }

  Future<void> saveServer(
    ServerProfile server, {
    bool select = false,
    ServerLineProbeResult? validatedProbe,
  }) {
    return _enqueueConfigWrite(
      () => _saveServerNow(
        server,
        select: select,
        validatedProbe: validatedProbe,
      ),
    );
  }

  Future<void> _saveServerNow(
    ServerProfile server, {
    required bool select,
    required ServerLineProbeResult? validatedProbe,
  }) async {
    final current = state ?? ref.read(serverConfigRepoProvider).load();
    ServerProfile? previousServer;
    if (current != null) {
      for (final item in current.servers) {
        if (item.id == server.id) {
          previousServer = item;
          break;
        }
      }
    }
    final previousBaseUrl = previousServer?.activeLine?.baseUrl;
    final nextBaseUrl = server.activeLine?.baseUrl;
    final activeLineChanged =
        current == null ||
        previousServer == null ||
        ServerConfig.normalize(previousBaseUrl ?? '') !=
            ServerConfig.normalize(nextBaseUrl ?? '');
    if (activeLineChanged) {
      _requireValidatedProbe(server, validatedProbe);
    }
    if (current == null) {
      await _saveNow(
        ServerConfig(
          baseUrl: server.activeLine?.baseUrl ?? server.lines.first.baseUrl,
          lines: server.lines,
          servers: [server],
          activeServerId: server.id,
        ),
      );
      return;
    }
    final previousProject = previousServer?.projectName?.trim().toLowerCase();
    final nextProject = server.projectName?.trim().toLowerCase();
    if (previousProject != null &&
        previousProject.isNotEmpty &&
        nextProject != null &&
        nextProject.isNotEmpty &&
        previousProject != nextProject) {
      throw StateError('同一服务器的线路必须属于同一项目，请新建服务器配置');
    }
    final updatedServerBaseUrl = server.activeLine?.baseUrl;
    final servers = current.servers
        .map((item) => item.id == server.id ? server : item)
        .toList();
    if (!servers.any((item) => item.id == server.id)) {
      servers.add(server);
    }
    final activeServer = select
        ? server
        : servers.firstWhere(
            (item) => item.id == current.activeServerId,
            orElse: () => servers.first,
          );
    final activeLine = activeServer.activeLine ?? activeServer.lines.first;
    final next = ServerConfig(
      baseUrl: activeLine.baseUrl,
      lines: activeServer.lines,
      servers: servers,
      activeServerId: activeServer.id,
    );
    await _saveNow(next);
    if (previousBaseUrl != null &&
        updatedServerBaseUrl != null &&
        previousBaseUrl != updatedServerBaseUrl) {
      await ref.read(serverProfileCacheRepoProvider).remove(server.id);
    }
    if (select) {
      ref.read(serverSelectionReadyProvider.notifier).state = true;
    }
  }

  void _requireValidatedProbe(
    ServerProfile server,
    ServerLineProbeResult? probe,
  ) {
    if (server.project?.isFileSource == true) return;
    final project = server.project;
    if (project == null) {
      throw ServerCompatibilityException('服务器类型无效，请选择正确的服务器类型');
    }
    final line = server.activeLine;
    if (line == null) {
      throw ServerCompatibilityException('服务器没有可用线路，无法保存');
    }
    if (probe == null ||
        !probe.success ||
        probe.versionInfo == null ||
        ServerConfig.normalize(probe.line.baseUrl) !=
            ServerConfig.normalize(line.baseUrl)) {
      final message = probe?.message.trim() ?? '';
      throw ServerCompatibilityException(
        message.isNotEmpty
            ? message
            : '保存前必须通过服务器版本检查，需要 ${project.projectName} >= ${project.minimumVersion}',
      );
    }

    final info = probe.versionInfo!;
    if (info.project != project) {
      final actual = info.projectName.isEmpty ? '未知' : info.projectName;
      throw ServerCompatibilityException(
        '线路项目不匹配，需要 ${project.projectName}，实际为 $actual',
      );
    }
    if (!isSupportedServerVersion(info.version, project.minimumVersion)) {
      final actual = info.version.isEmpty ? '未知' : info.version;
      throw ServerCompatibilityException(
        '服务器版本不满足要求，需要 ${project.projectName} >= '
        '${project.minimumVersion}，当前版本为 $actual',
      );
    }
  }

  Future<void> deleteServer(String serverId) async {
    final current = state ?? ref.read(serverConfigRepoProvider).load();
    if (current == null) return;
    final remaining = current.servers
        .where((server) => server.id != serverId)
        .toList();
    if (remaining.isEmpty) {
      throw StateError('至少保留一台服务器');
    }
    final nextActive = current.activeServer?.id == serverId
        ? remaining.first
        : current.activeServer ?? remaining.first;
    var validatedActiveServer = nextActive;
    ServerLineProbeResult? validatedProbe;
    if (current.activeServer?.id == serverId &&
        nextActive.project?.isFileSource != true) {
      final candidates = nextActive.lines
          .where((line) => line.enabled)
          .toList();
      if (candidates.isEmpty) {
        throw StateError('目标服务器没有启用线路，无法切换');
      }
      final preferred = nextActive.activeLine;
      final currentLine = preferred != null && preferred.enabled
          ? preferred
          : candidates.first;
      final selection = await ref
          .read(serverLineProbeCoordinatorProvider)
          .selectPreferred(
            current: currentLine,
            alternatives: candidates.where((line) => line.id != currentLine.id),
            expectedProjectName: nextActive.projectName,
          );
      final selected = selection.selected;
      if (selected == null) {
        throw ServerCompatibilityException(
          _lineSelectionFailureMessage(selection),
        );
      }
      final testedAt = DateTime.now();
      validatedActiveServer = nextActive.copyWith(
        lines: nextActive.lines
            .map(
              (line) => line.id == selected.line.id
                  ? line.copyWith(
                      latencyMs: selected.latencyMs,
                      lastTestedAt: testedAt,
                    )
                  : line,
            )
            .toList(),
        activeLineId: selected.line.id,
        serverVersion:
            selected.versionInfo?.version ?? nextActive.serverVersion,
      );
      validatedProbe = selected;
      _requireValidatedProbe(validatedActiveServer, validatedProbe);
    }
    final activeLine =
        validatedActiveServer.activeLine ?? validatedActiveServer.lines.first;
    final updatedServers = remaining
        .map(
          (server) => server.id == validatedActiveServer.id
              ? validatedActiveServer
              : server,
        )
        .toList();
    final next = ServerConfig(
      baseUrl: activeLine.baseUrl,
      lines: validatedActiveServer.lines,
      servers: updatedServers,
      activeServerId: validatedActiveServer.id,
    );
    final repository = ref.read(serverConfigRepoProvider);
    await repository.save(next);
    await ref.read(serverProfileCacheRepoProvider).remove(serverId);
    state = repository.load();
  }

  void showServerSelection({bool releaseResources = true}) {
    ref.read(serverSelectionReadyProvider.notifier).state = false;
    if (releaseResources) {
      // 清空运行态配置以释放所有服务器作用域资源；持久化配置仍由选择器读取。
      state = null;
    }
    ref.read(serverSelectionRequestedProvider.notifier).state = true;
  }

  void completeServerSelection() {
    ref.read(serverSelectionRequestedProvider.notifier).state = false;
  }

  Future<void> clear() async {
    await ref.read(serverConfigRepoProvider).clear();
    await ref.read(serverProfileCacheRepoProvider).clear();
    ref.read(serverSelectionReadyProvider.notifier).state = false;
    state = null;
  }

  /// 进入服务器编辑页，但保留本地配置，供编辑页回填。
  void beginEdit() {
    ref.read(serverSelectionReadyProvider.notifier).state = false;
    state = null;
  }

  Future<void> _enqueueConfigWrite(Future<void> Function() operation) {
    final result = _configWriteQueue.then((_) => operation());
    _configWriteQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig?>(
      ServerConfigNotifier.new,
    );

/// 选择器展示用配置：服务器运行态被卸载时回退到本地保存的配置。
final serverSelectionConfigProvider = Provider<ServerConfig?>((ref) {
  return ref.watch(serverConfigProvider) ??
      ref.watch(serverConfigRepoProvider).load();
});

List<ServerLine> _normalizeLines(List<ServerLine> lines, String baseUrl) {
  final normalizedBaseUrl = ServerConfig.normalize(baseUrl);
  final seenUrls = <String>{};
  final result = <ServerLine>[];
  for (final line in lines) {
    final normalized = ServerConfig.normalize(line.baseUrl);
    if (normalized.isEmpty || !seenUrls.add(normalized)) continue;
    result.add(line.copyWith(baseUrl: normalized));
  }
  if (result.isEmpty && normalizedBaseUrl.isNotEmpty) {
    result.add(
      ServerLine(id: 'legacy', name: '主线路', baseUrl: normalizedBaseUrl),
    );
  }
  if (normalizedBaseUrl.isNotEmpty &&
      !result.any((line) => line.baseUrl == normalizedBaseUrl)) {
    result.insert(
      0,
      ServerLine(id: 'active', name: '当前线路', baseUrl: normalizedBaseUrl),
    );
  }
  return result;
}

ServerLine _lineForUrl(List<ServerLine> lines, String baseUrl) {
  if (lines.isEmpty) {
    throw StateError('至少需要配置一条服务器线路');
  }
  final normalized = ServerConfig.normalize(baseUrl);
  return lines.firstWhere(
    (line) => line.baseUrl == normalized,
    orElse: () =>
        lines.firstWhere((line) => line.enabled, orElse: () => lines.first),
  );
}

String _lineSelectionFailureMessage(ServerLineSelection selection) {
  final incompatible = selection.results.where((result) => result.incompatible);
  if (incompatible.isNotEmpty) {
    final message = incompatible.first.message.trim();
    return message.isEmpty ? serverCompatibilityRequirementMessage : message;
  }
  final detail = selection.results
      .map((result) => '${result.line.name}：${result.message}')
      .where((message) => message.trim().isNotEmpty)
      .join('\n');
  return detail.isEmpty ? '没有可用的服务器线路' : detail;
}
