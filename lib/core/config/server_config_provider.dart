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

class ServerConfigNotifier extends Notifier<ServerConfig?> {
  @override
  ServerConfig? build() {
    return ref.watch(serverConfigRepoProvider).load();
  }

  Future<void> save(ServerConfig cfg) async {
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
    var servers = cfg.servers
        .map(
          (server) => server.copyWith(lines: _normalizeLines(server.lines, '')),
        )
        .where((server) => server.lines.isNotEmpty)
        .toList();

    if (servers.isEmpty) {
      final server = ServerProfile(
        id: cfg.activeServerId ?? 'server-${baseUrl.hashCode}',
        name: '主服务器',
        lines: currentLines,
        activeLineId: _lineForUrl(currentLines, baseUrl).id,
      );
      servers = [server];
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
        );
    final selected = selection.selected;
    if (selected == null) {
      throw StateError(_lineSelectionFailureMessage(selection));
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
      server.copyWith(lines: testedLines, activeLineId: selected.line.id),
      select: true,
    );
    ref.read(serverSelectionReadyProvider.notifier).state = true;
  }

  Future<void> saveServer(ServerProfile server, {bool select = false}) async {
    final current = state ?? ref.read(serverConfigRepoProvider).load();
    if (current == null) {
      await save(
        ServerConfig(
          baseUrl: server.activeLine?.baseUrl ?? server.lines.first.baseUrl,
          lines: server.lines,
          servers: [server],
          activeServerId: server.id,
        ),
      );
      return;
    }
    ServerProfile? previousServer;
    for (final item in current.servers) {
      if (item.id == server.id) {
        previousServer = item;
        break;
      }
    }
    final previousBaseUrl = previousServer?.activeLine?.baseUrl;
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
    final repository = ref.read(serverConfigRepoProvider);
    await repository.save(next);
    if (previousBaseUrl != null &&
        updatedServerBaseUrl != null &&
        previousBaseUrl != updatedServerBaseUrl) {
      await ref.read(serverProfileCacheRepoProvider).remove(server.id);
    }
    state = repository.load();
    if (select) {
      ref.read(serverSelectionReadyProvider.notifier).state = true;
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
    final activeLine = nextActive.activeLine ?? nextActive.lines.first;
    final next = ServerConfig(
      baseUrl: activeLine.baseUrl,
      lines: nextActive.lines,
      servers: remaining,
      activeServerId: nextActive.id,
    );
    final repository = ref.read(serverConfigRepoProvider);
    await repository.save(next);
    await ref.read(serverProfileCacheRepoProvider).remove(serverId);
    state = repository.load();
  }

  void showServerSelection() {
    ref.read(serverSelectionReadyProvider.notifier).state = false;
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
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig?>(
      ServerConfigNotifier.new,
    );

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
  if (selection.results.any((result) => result.incompatible)) {
    return serverCompatibilityRequirementMessage;
  }
  final detail = selection.results
      .map((result) => '${result.line.name}：${result.message}')
      .where((message) => message.trim().isNotEmpty)
      .join('\n');
  return detail.isEmpty ? '没有可用的服务器线路' : detail;
}
