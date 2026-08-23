import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';

class ServerConfigRepository {
  ServerConfigRepository(this._prefs);

  static const _kBaseUrl = 'server.base_url';
  static const _kLines = 'server.lines';
  static const _kServers = 'server.servers';
  static const _kActiveServerId = 'server.active_server_id';

  final SharedPreferences _prefs;

  ServerConfig? load() {
    final storedServers = _loadServers();
    if (storedServers.isNotEmpty) {
      final servers = _normalizeServers(storedServers);
      if (servers.isEmpty) return null;
      final requestedId = _prefs.getString(_kActiveServerId);
      final activeServer = servers.firstWhere(
        (server) => server.id == requestedId,
        orElse: () => servers.first,
      );
      final activeLine = activeServer.activeLine;
      if (activeLine == null) return null;
      return ServerConfig(
        baseUrl: activeLine.baseUrl,
        lines: activeServer.lines,
        servers: servers,
        activeServerId: activeServer.id,
      );
    }

    final baseUrl = ServerConfig.normalize(_prefs.getString(_kBaseUrl) ?? '');
    final lines = _loadLines();
    if (baseUrl.isEmpty && lines.isEmpty) return null;

    final migratedLines = _normalizeLines(lines, baseUrl);
    if (migratedLines.isEmpty) return null;
    final activeUrl = baseUrl.isNotEmpty
        ? baseUrl
        : migratedLines
              .firstWhere(
                (line) => line.enabled,
                orElse: () => migratedLines.first,
              )
              .baseUrl;
    final activeLine = migratedLines.firstWhere(
      (line) => line.baseUrl == activeUrl,
      orElse: () => migratedLines.first,
    );
    final server = ServerProfile(
      id: 'legacy-server',
      name: '主服务器',
      lines: migratedLines,
      activeLineId: activeLine.id,
    );
    return ServerConfig(
      baseUrl: activeLine.baseUrl,
      lines: migratedLines,
      servers: [server],
      activeServerId: server.id,
    );
  }

  Future<void> save(ServerConfig config) async {
    final sourceServers = config.servers.isEmpty
        ? [
            ServerProfile(
              id: config.activeServerId ?? 'legacy-server',
              name: '主服务器',
              lines: _normalizeLines(config.lines, config.baseUrl),
              activeLineId: _lineForUrl(
                _normalizeLines(config.lines, config.baseUrl),
                config.baseUrl,
              ).id,
            ),
          ]
        : config.servers;
    final servers = _normalizeServers(sourceServers);
    if (servers.isEmpty) {
      throw StateError('至少需要配置一条服务器线路');
    }
    final activeServer = servers.firstWhere(
      (server) => server.id == config.activeServerId,
      orElse: () => servers.first,
    );
    final activeLine = activeServer.activeLine;
    if (activeLine == null) {
      throw StateError('当前服务器没有可用线路');
    }

    await _prefs.setString(
      _kServers,
      jsonEncode(servers.map((server) => server.toJson()).toList()),
    );
    await _prefs.setString(_kActiveServerId, activeServer.id);
    // 保留旧键，便于旧版本读取到当前服务器，而不影响新版本的多服务器数据。
    await _prefs.setString(_kBaseUrl, activeLine.baseUrl);
    await _prefs.setString(
      _kLines,
      jsonEncode(activeServer.lines.map((line) => line.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_kBaseUrl);
    await _prefs.remove(_kLines);
    await _prefs.remove(_kServers);
    await _prefs.remove(_kActiveServerId);
  }

  List<ServerProfile> _loadServers() {
    final raw = _prefs.getString(_kServers);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ServerProfile.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ServerLine> _loadLines() {
    final raw = _prefs.getString(_kLines);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => ServerLine.fromJson(Map<String, dynamic>.from(item)))
          .where((line) => line.baseUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ServerLine> _normalizeLines(List<ServerLine> input, String activeUrl) {
    final seenUrls = <String>{};
    final lines = <ServerLine>[];
    for (final line in input) {
      final baseUrl = ServerConfig.normalize(line.baseUrl);
      if (baseUrl.isEmpty || !seenUrls.add(baseUrl)) continue;
      lines.add(line.copyWith(baseUrl: baseUrl));
    }
    final normalizedActiveUrl = ServerConfig.normalize(activeUrl);
    if (lines.isEmpty && normalizedActiveUrl.isNotEmpty) {
      lines.add(
        ServerLine(id: 'legacy', name: '主线路', baseUrl: normalizedActiveUrl),
      );
    } else if (normalizedActiveUrl.isNotEmpty &&
        !lines.any((line) => line.baseUrl == normalizedActiveUrl)) {
      lines.insert(
        0,
        ServerLine(id: 'active', name: '当前线路', baseUrl: normalizedActiveUrl),
      );
    }
    return lines;
  }

  List<ServerProfile> _normalizeServers(List<ServerProfile> input) {
    final seenIds = <String>{};
    final servers = <ServerProfile>[];
    for (final server in input) {
      final lines = _normalizeLines(server.lines, '');
      if (lines.isEmpty) continue;
      var id = server.id.trim();
      if (id.isEmpty || !seenIds.add(id)) {
        id = 'server-${servers.length + 1}';
        while (!seenIds.add(id)) {
          id = 'server-${servers.length + 2}';
        }
      }
      final activeLine = server.activeLine;
      final activeLineId = lines.any((line) => line.id == activeLine?.id)
          ? activeLine!.id
          : lines.first.id;
      servers.add(
        ServerProfile(
          id: id,
          name: server.name.trim().isEmpty
              ? '服务器 ${servers.length + 1}'
              : server.name.trim(),
          avatarUrl: server.avatarUrl,
          lines: lines,
          activeLineId: activeLineId,
        ),
      );
    }
    return servers;
  }

  ServerLine _lineForUrl(List<ServerLine> lines, String baseUrl) {
    if (lines.isEmpty) throw StateError('至少需要配置一条服务器线路');
    final normalized = ServerConfig.normalize(baseUrl);
    return lines.firstWhere(
      (line) => line.baseUrl == normalized,
      orElse: () =>
          lines.firstWhere((line) => line.enabled, orElse: () => lines.first),
    );
  }
}
