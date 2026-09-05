import 'package:flutter/foundation.dart';

import '../api/server_compatibility.dart';

@immutable
class ServerLine {
  const ServerLine({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.enabled = true,
    this.latencyMs,
    this.lastTestedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final bool enabled;
  final int? latencyMs;
  final DateTime? lastTestedAt;

  factory ServerLine.fromJson(Map<String, dynamic> json) {
    final baseUrl = ServerConfig.normalize(json['base_url']?.toString() ?? '');
    final id = json['id']?.toString().trim() ?? '';
    return ServerLine(
      id: id.isNotEmpty ? id : baseUrl,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : '服务器线路',
      baseUrl: baseUrl,
      enabled: json['enabled'] != false,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      lastTestedAt: DateTime.tryParse(json['last_tested_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'base_url': baseUrl,
    'enabled': enabled,
    if (latencyMs != null) 'latency_ms': latencyMs,
    if (lastTestedAt != null) 'last_tested_at': lastTestedAt!.toIso8601String(),
  };

  ServerLine copyWith({
    String? id,
    String? name,
    String? baseUrl,
    bool? enabled,
    int? latencyMs,
    DateTime? lastTestedAt,
  }) {
    return ServerLine(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      latencyMs: latencyMs ?? this.latencyMs,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerLine &&
          other.id == id &&
          other.name == name &&
          other.baseUrl == baseUrl &&
          other.enabled == enabled &&
          other.latencyMs == latencyMs &&
          other.lastTestedAt == lastTestedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, baseUrl, enabled, latencyMs, lastTestedAt);
}

@immutable
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.lines,
    this.activeLineId,
    this.avatarUrl,
    this.projectName,
    this.serverVersion,
  });

  final String id;
  final String name;
  final List<ServerLine> lines;
  final String? activeLineId;
  final String? avatarUrl;
  final String? projectName;
  final String? serverVersion;

  ServerProject? get project =>
      ServerProject.fromProjectName(projectName?.trim() ?? '');

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map>()
              .map(
                (item) => ServerLine.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((line) => line.baseUrl.isNotEmpty)
              .toList()
        : <ServerLine>[];
    final projectName = _optionalString(json['project_name']);
    final project = ServerProject.fromProjectName(projectName ?? '');
    return ServerProfile(
      id: id.isNotEmpty ? id : 'server-${name.hashCode}',
      name: name.isNotEmpty ? name : '服务器',
      lines: lines,
      activeLineId: json['active_line_id']?.toString(),
      avatarUrl: project == ServerProject.ohMyMedia
          ? null
          : _optionalString(json['avatar_url']),
      projectName: projectName,
      serverVersion: _optionalString(json['server_version']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lines': lines.map((line) => line.toJson()).toList(),
    if (activeLineId != null) 'active_line_id': activeLineId,
    if (project != ServerProject.ohMyMedia &&
        avatarUrl != null &&
        avatarUrl!.isNotEmpty)
      'avatar_url': avatarUrl,
    if (projectName != null && projectName!.isNotEmpty)
      'project_name': projectName,
    if (serverVersion != null && serverVersion!.isNotEmpty)
      'server_version': serverVersion,
  };

  ServerLine? get activeLine {
    if (lines.isEmpty) return null;
    for (final line in lines) {
      if (line.id == activeLineId) return line;
    }
    for (final line in lines) {
      if (line.enabled) return line;
    }
    return lines.first;
  }

  ServerProfile copyWith({
    String? id,
    String? name,
    List<ServerLine>? lines,
    String? activeLineId,
    String? avatarUrl,
    String? projectName,
    String? serverVersion,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      lines: lines ?? this.lines,
      activeLineId: activeLineId ?? this.activeLineId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      projectName: projectName ?? this.projectName,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerProfile &&
          other.id == id &&
          other.name == name &&
          listEquals(other.lines, lines) &&
          other.activeLineId == activeLineId &&
          other.avatarUrl == avatarUrl &&
          other.projectName == projectName &&
          other.serverVersion == serverVersion;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(lines),
    activeLineId,
    avatarUrl,
    projectName,
    serverVersion,
  );
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

@immutable
class ServerConfig {
  const ServerConfig({
    required this.baseUrl,
    this.lines = const [],
    this.servers = const [],
    this.activeServerId,
  });

  final String baseUrl;

  /// 当前服务器的线路。保留该字段是为了兼容已有 API、播放器和缓存逻辑。
  final List<ServerLine> lines;
  final List<ServerProfile> servers;
  final String? activeServerId;

  static String normalize(String raw) {
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.toLowerCase().endsWith('/api')) {
      s = s.substring(0, s.length - 4);
    }
    return s;
  }

  /// 按服务器项目规范化服务根地址。
  ///
  /// 飞牛影视的 Web 应用挂在 `/v` 下，但旧配置和用户手工输入可能只
  /// 填了主机根地址，或误填了完整的 `/v/api/v1`。统一在这里收敛，
  /// 调用方只需继续追加项目 API 路径。
  static String normalizeForProject(String raw, ServerProject project) {
    final normalized = normalize(raw);
    if (project != ServerProject.feiniu) return normalized;

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return normalized;

    var path = uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    const apiSuffix = '/api/v1';
    if (path.toLowerCase().endsWith(apiSuffix)) {
      path = path.substring(0, path.length - apiSuffix.length);
    }
    if (path.isEmpty) {
      path = '/v';
    } else if (!path.toLowerCase().endsWith('/v')) {
      path = '$path/v';
    }
    return uri.replace(path: path).toString();
  }

  String get apiBase {
    final project = activeServer?.project;
    if (project == ServerProject.feiniu) {
      return '${normalizeForProject(baseUrl, ServerProject.feiniu)}/api/v1';
    }
    if (project == ServerProject.stash) return baseUrl;
    return '$baseUrl/api';
  }

  bool get hasMultipleServers => servers.length > 1;

  /// 预览生成是 OMM 独有能力，所有入口都以当前激活项目为准。
  bool get isOmm => activeServer?.project == ServerProject.ohMyMedia;

  ServerProfile? get activeServer {
    if (servers.isEmpty) return null;
    return servers.firstWhere(
      (server) => server.id == activeServerId,
      orElse: () => servers.first,
    );
  }

  ServerConfig copyWith({
    String? baseUrl,
    List<ServerLine>? lines,
    List<ServerProfile>? servers,
    String? activeServerId,
  }) {
    return ServerConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      lines: lines ?? this.lines,
      servers: servers ?? this.servers,
      activeServerId: activeServerId ?? this.activeServerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          other.baseUrl == baseUrl &&
          listEquals(other.lines, lines) &&
          listEquals(other.servers, servers) &&
          other.activeServerId == activeServerId;

  @override
  int get hashCode => Object.hash(
    baseUrl,
    Object.hashAll(lines),
    Object.hashAll(servers),
    activeServerId,
  );
}
