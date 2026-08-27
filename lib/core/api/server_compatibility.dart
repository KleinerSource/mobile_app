import 'package:flutter/foundation.dart';

import 'api_exception.dart';

const requiredServerProjectName = 'oh-my-media';
const minimumSupportedServerVersion = '2.0.0';

enum ServerProject {
  ohMyMedia(
    projectName: 'oh-my-media',
    displayName: 'Oh-My-Media',
    minimumVersion: '2.0.0',
  ),
  dbOnline(
    projectName: 'db_online',
    displayName: 'dbonline',
    minimumVersion: '1.14.0',
  );

  const ServerProject({
    required this.projectName,
    required this.displayName,
    required this.minimumVersion,
  });

  final String projectName;
  final String displayName;
  final String minimumVersion;

  static ServerProject? fromProjectName(String value) {
    final normalized = value.trim().toLowerCase();
    for (final project in values) {
      if (project.projectName == normalized) return project;
    }
    return null;
  }
}

String get serverCompatibilityRequirementMessage =>
    '服务器不兼容，需要 ${ServerProject.ohMyMedia.projectName} >= '
    '${ServerProject.ohMyMedia.minimumVersion} 或 '
    '${ServerProject.dbOnline.projectName} >= '
    '${ServerProject.dbOnline.minimumVersion}';

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

  ServerProject? get project => ServerProject.fromProjectName(projectName);

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
  final project = info.project;
  if (project == null) {
    final actual = info.projectName.isEmpty ? '未知' : info.projectName;
    final version = info.version.isEmpty ? '未知' : info.version;
    throw ServerCompatibilityException(
      '$serverCompatibilityRequirementMessage；实际项目为 $actual，版本为 $version',
    );
  }
  if (!isSupportedServerVersion(info.version, project.minimumVersion)) {
    final actual = info.version.isEmpty ? '未知' : info.version;
    throw ServerCompatibilityException(
      '服务器版本不满足要求，需要 ${project.projectName} >= '
      '${project.minimumVersion}，当前版本为 $actual',
    );
  }
  return info;
}

bool isSupportedServerVersion(
  String version, [
  String minimumVersion = minimumSupportedServerVersion,
]) {
  final actual = _parseVersion(version);
  final minimum = _parseVersion(minimumVersion);
  if (actual == null || minimum == null) return false;

  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != minimum[i]) return actual[i] > minimum[i];
  }
  return true;
}

ServerVersionInfo _decodeServerVersion(Object? raw) {
  if (raw is! Map || raw['success'] != true || raw['data'] is! Map) {
    throw ServerCompatibilityException(
      '服务器版本接口响应格式不兼容；实际项目为未知，版本为未知。'
      '$serverCompatibilityRequirementMessage',
    );
  }
  return ServerVersionInfo.fromJson(
    Map<String, dynamic>.from(raw['data'] as Map),
  );
}

List<int>? _parseVersion(String value) {
  final match = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}
