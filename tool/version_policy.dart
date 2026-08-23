/// 应用版本的递增类型。
enum VersionBump {
  /// 新增、删除或增强功能: x.y.z -> x.(y + 1).0。
  feature,

  /// 优化、修复 bug 或改进既有行为: x.y.z -> x.y.(z + 1)。
  bugFix,

  /// 只生成新的构建产物: x.y.z+b -> x.y.z+(b + 1)。
  buildOnly,
}

/// 根据提交信息判断应用版本应如何递增。
VersionBump versionBumpForCommit(String commitMessage) {
  final subject = commitMessage.trim().split(RegExp(r'\r?\n')).first.trim();
  if (subject.isEmpty) return VersionBump.bugFix;

  final normalized = subject.toLowerCase();
  if (normalized.contains('[build-fix]') ||
      normalized.contains('[no-version]')) {
    return VersionBump.buildOnly;
  }

  final type = RegExp(
    r'^([a-z]+)(?:\([^)]*\))?!?:',
  ).firstMatch(normalized)?.group(1);

  if (type == 'feat' ||
      type == 'feature' ||
      type == 'add' ||
      type == 'enhance' ||
      type == 'enhancement' ||
      type == 'remove' ||
      type == 'delete' ||
      (type == null &&
          [
            '新增功能',
            '新增',
            '添加',
            '补上',
            '支持',
            '实现',
            '引入',
            '删除',
            '移除',
            '增强',
          ].any(normalized.contains))) {
    return VersionBump.feature;
  }

  if (type == 'build' ||
      type == 'ci' ||
      type == 'chore' ||
      type == 'doc' ||
      type == 'docs' ||
      type == 'test') {
    return VersionBump.buildOnly;
  }

  final isFix =
      type == 'fix' ||
      normalized.startsWith('fix ') ||
      normalized.contains('修复');
  if (!isFix) return VersionBump.bugFix;

  const buildFixKeywords = [
    '编译',
    '构建',
    'analyze',
    'analyzer',
    'gradle',
    'xcode',
    'cocoapods',
    'pod install',
    'swift',
    'kotlin',
    'codesign',
    '签名',
    '依赖安装',
  ];
  if (buildFixKeywords.any(normalized.contains)) {
    return VersionBump.buildOnly;
  }
  return VersionBump.bugFix;
}

/// 兼容旧调用方: 只判断是否需要改变前三位版本号。
bool shouldBumpPatchForCommit(String commitMessage) {
  return versionBumpForCommit(commitMessage) != VersionBump.buildOnly;
}

/// 根据递增类型生成下一个 `x.y.z+build` 版本。
String nextAppVersion(String currentVersion, VersionBump bump) {
  final match = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$',
  ).firstMatch(currentVersion.trim());
  if (match == null) {
    throw const FormatException('版本号不是 x.y.z+build 格式');
  }

  final major = int.parse(match.group(1)!);
  final currentMinor = int.parse(match.group(2)!);
  final currentPatch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!) + 1;
  final minor = bump == VersionBump.feature ? currentMinor + 1 : currentMinor;
  final patch = bump == VersionBump.feature
      ? 0
      : bump == VersionBump.bugFix
      ? currentPatch + 1
      : currentPatch;
  return '$major.$minor.$patch+$build';
}
