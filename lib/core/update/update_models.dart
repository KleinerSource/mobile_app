import 'package:flutter/foundation.dart';

enum UpdatePlatform { ios, android }

extension UpdatePlatformX on UpdatePlatform {
  String get assetExtension => this == UpdatePlatform.ios ? '.ipa' : '.apk';

  String get rollingReleaseTag =>
      this == UpdatePlatform.ios ? 'latest' : 'latest-android';

  String get label => this == UpdatePlatform.ios ? 'iOS' : 'Android';
}

@immutable
class AppReleaseVersion implements Comparable<AppReleaseVersion> {
  const AppReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  static final _pattern = RegExp(
    r'(?:^|[^0-9])v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?(?:$|[^0-9])',
    caseSensitive: false,
  );

  factory AppReleaseVersion.parse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('版本号格式不正确', raw);
    }
    return AppReleaseVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.tryParse(match.group(4) ?? '') ?? 0,
    );
  }

  static AppReleaseVersion? tryParse(String raw) {
    try {
      return AppReleaseVersion.parse(raw);
    } on FormatException {
      return null;
    }
  }

  factory AppReleaseVersion.fromPackageInfo(
    String version,
    String buildNumber,
  ) {
    final build = int.tryParse(buildNumber.trim()) ?? 0;
    final parsed = AppReleaseVersion.parse(version);
    return AppReleaseVersion(
      major: parsed.major,
      minor: parsed.minor,
      patch: parsed.patch,
      build: build == 0 ? parsed.build : build,
    );
  }

  String get display => '$major.$minor.$patch+$build';

  @override
  int compareTo(AppReleaseVersion other) {
    final semantic = _compare(major, other.major);
    if (semantic != 0) return semantic;
    final minorResult = _compare(minor, other.minor);
    if (minorResult != 0) return minorResult;
    final patchResult = _compare(patch, other.patch);
    if (patchResult != 0) return patchResult;
    return _compare(build, other.build);
  }

  int _compare(int left, int right) => left.compareTo(right);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppReleaseVersion &&
          other.major == major &&
          other.minor == minor &&
          other.patch == patch &&
          other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => display;
}

@immutable
class GitHubRepository {
  const GitHubRepository({required this.owner, required this.name});

  final String owner;
  final String name;

  factory GitHubRepository.parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) throw const FormatException('请输入 GitHub 仓库地址');
    if (!value.contains('://')) value = 'https://$value';

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      throw const FormatException('GitHub 地址必须使用 HTTPS');
    }
    final host = uri.host.toLowerCase();
    if (host != 'github.com' && host != 'www.github.com') {
      throw const FormatException('请输入 github.com 仓库地址');
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length < 2) {
      throw const FormatException('GitHub 地址应包含 owner 和 repository');
    }
    final owner = segments[0];
    final name = segments[1].replaceFirst(RegExp(r'\.git$'), '');
    final validSegment = RegExp(r'^[A-Za-z0-9_.-]+$');
    if (!validSegment.hasMatch(owner) || !validSegment.hasMatch(name)) {
      throw const FormatException('GitHub 仓库地址格式不正确');
    }
    return GitHubRepository(owner: owner, name: name);
  }

  String get canonicalUrl => 'https://github.com/$owner/$name';

  String get releasesApiUrl =>
      'https://api.github.com/repos/$owner/$name/releases?per_page=100';

  String releaseTagApiUrl(UpdatePlatform platform) =>
      'https://api.github.com/repos/$owner/$name/releases/tags/'
      '${platform.rollingReleaseTag}';

  @override
  String toString() => canonicalUrl;
}

@immutable
class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.size = 0,
  });

  final String name;
  final String downloadUrl;
  final int size;

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name']?.toString().trim() ?? '',
      downloadUrl: json['browser_download_url']?.toString().trim() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }

  AppReleaseVersion? get version => AppReleaseVersion.tryParse(name);

  bool get isHttpsUrl =>
      Uri.tryParse(downloadUrl)?.scheme.toLowerCase() == 'https';
}

@immutable
class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.assets,
    this.draft = false,
    this.publishedAt,
  });

  final String tagName;
  final String name;
  final String body;
  final List<GitHubReleaseAsset> assets;
  final bool draft;
  final DateTime? publishedAt;

  /// 返回面向用户的更新内容，隐藏自动构建脚本添加的元数据。
  ///
  /// 滚动 Release 会在正文中包含构建标题、版本号、commit 和 run 信息。
  /// 这些内容不应挤占弹窗首次展示的更新内容区域。
  String get updateNotes {
    final normalizedBody = body.replaceAll('\r\n', '\n').trim();
    if (normalizedBody.isEmpty) return '';

    final heading = RegExp(
      r'^\s*本次构建包含以下更新[：:]?\s*$',
      multiLine: true,
    ).firstMatch(normalizedBody);
    final notes = heading == null
        ? normalizedBody
        : normalizedBody.substring(heading.end).trim();

    return notes
        .split('\n')
        .where(
          (line) => !RegExp(
            r'^\s*(commit|run):\s*',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .join('\n')
        .trim();
  }

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    return GitHubRelease(
      tagName: json['tag_name']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      body: json['body']?.toString().trim() ?? '',
      draft: json['draft'] == true,
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      assets: rawAssets is List
          ? rawAssets
                .whereType<Map>()
                .map(
                  (item) => GitHubReleaseAsset.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where(
                  (asset) =>
                      asset.name.isNotEmpty && asset.downloadUrl.isNotEmpty,
                )
                .toList()
          : const [],
    );
  }

  AppReleaseVersion? versionFor(GitHubReleaseAsset asset) {
    return asset.version ?? AppReleaseVersion.tryParse(tagName);
  }

  GitHubReleaseAsset? assetFor(UpdatePlatform platform) {
    final matching = assets
        .where(
          (asset) => asset.isHttpsUrl && _matchesPlatformAsset(asset, platform),
        )
        .toList();
    if (matching.isEmpty) return null;
    matching.sort((left, right) {
      final leftVersion = versionFor(left);
      final rightVersion = versionFor(right);
      if (leftVersion == null && rightVersion == null) {
        return left.name.compareTo(right.name);
      }
      if (leftVersion == null) return -1;
      if (rightVersion == null) return 1;
      final versionResult = leftVersion.compareTo(rightVersion);
      if (versionResult != 0) return versionResult;
      return left.size.compareTo(right.size);
    });
    return matching.last;
  }

  bool _matchesPlatformAsset(
    GitHubReleaseAsset asset,
    UpdatePlatform platform,
  ) {
    final name = _decodeAssetName(asset.name).toLowerCase();
    return name.endsWith(platform.assetExtension);
  }

  String _decodeAssetName(String value) {
    try {
      return Uri.decodeComponent(value.trim());
    } on FormatException {
      return value.trim();
    }
  }
}

@immutable
class GitHubUpdateCandidate {
  const GitHubUpdateCandidate({
    required this.release,
    required this.asset,
    required this.version,
  });

  final GitHubRelease release;
  final GitHubReleaseAsset asset;
  final AppReleaseVersion version;
}

@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.repository,
    required this.currentVersion,
    required this.candidate,
  });

  final GitHubRepository repository;
  final AppReleaseVersion currentVersion;
  final GitHubUpdateCandidate candidate;

  bool get hasUpdate => candidate.version.compareTo(currentVersion) > 0;
}
