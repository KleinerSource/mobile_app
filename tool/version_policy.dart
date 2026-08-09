/// 根据提交信息判断是否属于应用版本变更。
///
/// 应用功能、界面和逻辑变更递增 patch；纯 CI/构建变更，以及编译失败后的
/// 构建修复只递增 build。提交信息也可以显式使用 `[build-fix]` 或
/// `[no-version]` 标记强制不递增 patch。
bool shouldBumpPatchForCommit(String commitMessage) {
  final subject = commitMessage.trim().split(RegExp(r'\r?\n')).first.trim();
  if (subject.isEmpty) return true;

  final normalized = subject.toLowerCase();
  if (normalized.contains('[build-fix]') ||
      normalized.contains('[no-version]')) {
    return false;
  }

  final type = RegExp(r'^([a-z]+)(?:\([^)]*\))?!?:')
      .firstMatch(normalized)
      ?.group(1);
  if (type == 'build' ||
      type == 'ci' ||
      type == 'chore' ||
      type == 'doc' ||
      type == 'docs' ||
      type == 'test') {
    return false;
  }

  final isFix = type == 'fix' ||
      normalized.startsWith('fix ') ||
      normalized.contains('修复');
  if (!isFix) return true;

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
  return !buildFixKeywords.any(normalized.contains);
}
