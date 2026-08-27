import 'dart:async';
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
    final rawServers = _prefs.getString(_kServers);
    final storedServers = _loadServers();
    if (rawServers?.isNotEmpty == true) {
      final servers = _normalizeServers(storedServers);
      if (servers.isEmpty) {
        unawaited(clear());
        return null;
      }
      final requestedId = _prefs.getString(_kActiveServerId);
      final activeServer = servers.firstWhere(
        (server) => server.id == requestedId,
        orElse: () => servers.first,
      );
      final activeLine = activeServer.activeLine;
      if (activeLine == null) return null;
      final config = ServerConfig(
        baseUrl: activeLine.baseUrl,
        lines: activeServer.lines,
        servers: servers,
        activeServerId: activeServer.id,
      );
      if (servers.length != storedServers.length ||
          !_sameServerList(servers, storedServers) ||
          activeServer.id != requestedId) {
        unawaited(save(config));
      }
      return config;
    }

    // 旧版本只有地址/线路，没有用户明确选择的项目类型；不再把它们
    // 静默迁移成无类型服务器，避免后续走错鉴权路径。
    if (_prefs.containsKey(_kBaseUrl) || _prefs.containsKey(_kLines)) {
      unawaited(clear());
    }
    return null;
  }

  Future<void> save(ServerConfig config) async {
    final servers = _normalizeServers(config.servers);
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
      final project = server.project;
      if (project == null) continue;
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
          projectName: project.projectName,
          serverVersion: server.serverVersion,
          lines: lines,
          activeLineId: activeLineId,
        ),
      );
    }
    return servers;
  }

  bool _sameServerList(List<ServerProfile> first, List<ServerProfile> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
