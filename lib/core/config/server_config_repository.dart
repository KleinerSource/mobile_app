import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';

class ServerConfigRepository {
  ServerConfigRepository(this._prefs);

  static const _kBaseUrl = 'server.base_url';
  static const _kLines = 'server.lines';

  final SharedPreferences _prefs;

  ServerConfig? load() {
    final baseUrl = ServerConfig.normalize(_prefs.getString(_kBaseUrl) ?? '');
    final lines = _loadLines();
    if (baseUrl.isEmpty && lines.isEmpty) return null;

    final migratedLines = _normalizeLines(lines, baseUrl);
    final activeUrl = baseUrl.isNotEmpty
        ? baseUrl
        : migratedLines
            .firstWhere(
              (line) => line.enabled,
              orElse: () => migratedLines.first,
            )
            .baseUrl;
    return ServerConfig(baseUrl: activeUrl, lines: migratedLines);
  }

  Future<void> save(ServerConfig config) async {
    final baseUrl = ServerConfig.normalize(config.baseUrl);
    final lines = _normalizeLines(config.lines, baseUrl);
    await _prefs.setString(_kBaseUrl, baseUrl);
    await _prefs.setString(
      _kLines,
      jsonEncode(lines.map((line) => line.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_kBaseUrl);
    await _prefs.remove(_kLines);
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

  List<ServerLine> _normalizeLines(
    List<ServerLine> input,
    String activeUrl,
  ) {
    final lines = input
        .map(
          (line) => line.copyWith(
            baseUrl: ServerConfig.normalize(line.baseUrl),
          ),
        )
        .where((line) => line.baseUrl.isNotEmpty)
        .toList();
    if (lines.isEmpty && activeUrl.isNotEmpty) {
      return [
        ServerLine(
          id: 'legacy',
          name: '主线路',
          baseUrl: activeUrl,
        ),
      ];
    }
    if (activeUrl.isNotEmpty && !lines.any((line) => line.baseUrl == activeUrl)) {
      lines.insert(
        0,
        ServerLine(
          id: 'active',
          name: '当前线路',
          baseUrl: activeUrl,
        ),
      );
    }
    return lines;
  }
}
