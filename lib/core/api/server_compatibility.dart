import 'package:flutter/foundation.dart';

import 'api_exception.dart';

const requiredServerProjectName = 'omm';
const minimumSupportedServerVersion = '1.7.0';

String get serverCompatibilityRequirementMessage =>
    '服务器不兼容，需要 $requiredServerProjectName 版本不低于 '
    '$minimumSupportedServerVersion';

@immutable
class ServerVersionInfo {
  const ServerVersionInfo({
    required this.projectName,
    required this.version,
    this.buildTime = '',
    this.gitCommit = '',
  });

  final String projectName;
  final String version;
  final String buildTime;
  final String gitCommit;

  factory ServerVersionInfo.fromJson(Map<String, dynamic> json) {
    return ServerVersionInfo(
      projectName: json['project_name']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      buildTime: json['build_time']?.toString().trim() ?? '',
      gitCommit: json['git_commit']?.toString().trim() ?? '',
    );
  }
}

class ServerCompatibilityException extends ApiException {
  ServerCompatibilityException(super.message);
}

ServerVersionInfo requireCompatibleServerVersion(Object? raw) {
  final info = _decodeServerVersion(raw);
  if (info.projectName != requiredServerProjectName) {
    final actual = info.projectName.isEmpty ? '未知' : info.projectName;
    throw ServerCompatibilityException(
      '服务器项目不匹配，需要项目 $requiredServerProjectName，实际为 $actual',
    );
  }
  if (!isSupportedServerVersion(info.version)) {
    final actual = info.version.isEmpty ? '未知' : info.version;
    throw ServerCompatibilityException(
      '服务器版本不满足要求，需要 $requiredServerProjectName >= '
      '$minimumSupportedServerVersion，当前版本为 $actual',
    );
  }
  return info;
}

bool isSupportedServerVersion(String version) {
  final actual = _parseVersion(version);
  final minimum = _parseVersion(minimumSupportedServerVersion);
  if (actual == null || minimum == null) return false;

  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != minimum[i]) return actual[i] > minimum[i];
  }
  return true;
}

ServerVersionInfo _decodeServerVersion(Object? raw) {
  if (raw is! Map || raw['success'] != true || raw['data'] is! Map) {
    throw ServerCompatibilityException('服务器版本接口响应格式不兼容');
  }
  return ServerVersionInfo.fromJson(
    Map<String, dynamic>.from(raw['data'] as Map),
  );
}

List<int>? _parseVersion(String value) {
  final match = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:\+[0-9A-Za-z.-]+)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}
