import 'package:flutter/foundation.dart';

@immutable
class ServerConfig {
  const ServerConfig({required this.baseUrl});

  final String baseUrl;

  static String normalize(String raw) {
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String get apiBase => '$baseUrl/api';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ServerConfig && other.baseUrl == baseUrl;

  @override
  int get hashCode => baseUrl.hashCode;
}
