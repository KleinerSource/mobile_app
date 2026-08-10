import 'package:flutter/foundation.dart';

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
      lastTestedAt: DateTime.tryParse(
        json['last_tested_at']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'enabled': enabled,
        if (latencyMs != null) 'latency_ms': latencyMs,
        if (lastTestedAt != null)
          'last_tested_at': lastTestedAt!.toIso8601String(),
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
  int get hashCode => Object.hash(
        id,
        name,
        baseUrl,
        enabled,
        latencyMs,
        lastTestedAt,
      );
}

@immutable
class ServerConfig {
  const ServerConfig({required this.baseUrl, this.lines = const []});

  final String baseUrl;
  final List<ServerLine> lines;

  static String normalize(String raw) {
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String get apiBase => '$baseUrl/api';

  ServerConfig copyWith({String? baseUrl, List<ServerLine>? lines}) {
    return ServerConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      lines: lines ?? this.lines,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          other.baseUrl == baseUrl &&
          listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(baseUrl, Object.hashAll(lines));
}
