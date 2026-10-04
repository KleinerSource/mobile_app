import 'dart:convert';
import 'dart:io';

/// 生成构建期内嵌的更新日志 Dart 文件（lib/core/update/build_changelog.dart）。
///
/// CI 在 flutter build 之前运行本工具，把"本次构建包含以下更新"以常量形式编译进
/// 产物；应用在更新后首次启动时弹窗展示（StartupChangelogGate）。
///
/// 用法：
///   dart tool/generate_build_changelog.dart --version 0.113.5+893 --release-tag latest-android
///   dart tool/generate_build_changelog.dart --version 0.113.5+893 --base-sha `<sha>`
///
/// 提交边界与 tool/generate_release_notes.sh 一致：以上一次成功发布（Release 指向
/// 的提交）为界；边界不可用时回退为仅当前提交，避免把全部仓库历史写入产物。
///
/// 内嵌内容必须完全不含 GitHub 源相关信息：merge 提交、版本号提交、PR/issue 引用、
/// Git 尾注（Co-authored-by 等含邮箱）、GitHub 域名与仓库身份串都会被过滤，最终
/// 输出前还有 [assertNoGithubSourceInfo] 断言兜底，任何命中都会让生成直接失败。
const String _outputArgument = '--output';
const String _releaseTagArgument = '--release-tag';
const String _baseShaArgument = '--base-sha';
const String _versionArgument = '--version';
const String _defaultOutputPath = 'lib/core/update/build_changelog.dart';

final RegExp _versionPattern = RegExp(r'^\d+\.\d+\.\d+\+\d+$');

/// GitHub 域名：任何命中都视为源信息泄露。
final RegExp _githubDomainPattern = RegExp(
  r'github\.(com|io)|githubusercontent\.com',
  caseSensitive: false,
);

/// 仓库身份串：与 CI 的 APK/IPA 隐私扫描保持一致并放宽大小写。
final RegExp _repositoryIdentityPattern = RegExp(
  'kleinersource',
  caseSensitive: false,
);

/// Git 尾注行（Co-authored-by 等）：携带姓名与邮箱，整行丢弃。
final RegExp _gitTrailerLinePattern = RegExp(
  r'^(co-authored-by|signed-off-by|reviewed-by|acked-by|tested-by|cc):',
  caseSensitive: false,
);

/// 纯 issue 引用行（Closes #123 等）：属于源仓库元数据，整行丢弃。
final RegExp _issueReferenceLinePattern = RegExp(
  r'^(close[sd]?|fix(es|ed)?|resolve[sd]?|refs?|references?)\s*:?\s*#\d+',
  caseSensitive: false,
);

/// 主题尾部的 PR 引用（feat: xxx (#123)），去除后保留主题本身。
final RegExp _pullRequestSuffixPattern = RegExp(r'\s*\(#\d+\)$');

/// 提交信息不应进入产物的控制字符（换行与制表符除外）。
final RegExp _controlCharacterPattern = RegExp(
  '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
);

class ChangelogCommit {
  const ChangelogCommit({required this.subject, required this.body});

  final String subject;
  final String body;
}

Future<void> main(List<String> args) async {
  final options = _parseArguments(args);
  final version = options[_versionArgument];
  if (version == null || !_versionPattern.hasMatch(version)) {
    throw const FormatException('必须提供 --version，格式为 x.y.z+build');
  }
  final outputPath = options[_outputArgument] ?? _defaultOutputPath;

  final base = await _resolveBaseCommit(
    releaseTag: options[_releaseTagArgument],
    baseSha: options[_baseShaArgument],
  );
  final commits = await _collectCommits(base);
  final notes = buildChangelogNotes(commits);
  final source = renderBuildChangelogSource(version: version, notes: notes);
  assertNoGithubSourceInfo(source);
  File(outputPath).writeAsStringSync(source);
  final entryCount = commits
      .where((commit) => changelogEntryLines(commit).isNotEmpty)
      .length;
  stdout.writeln('内嵌更新日志: $entryCount 条提交 -> $outputPath');
}

Map<String, String> _parseArguments(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case _versionArgument:
      case _releaseTagArgument:
      case _baseShaArgument:
      case _outputArgument:
        if (i + 1 >= args.length) {
          throw FormatException('${args[i]} 需要一个参数值');
        }
        options[args[i]] = args[++i];
    }
  }
  return options;
}

/// 解析提交边界：显式 --base-sha 优先，其次用 gh 查询 Release 指向的提交。
/// 提交不存在或不是当前 HEAD 的祖先时回退为 null（仅记录当前提交）。
Future<String?> _resolveBaseCommit({
  String? releaseTag,
  String? baseSha,
}) async {
  String? candidate = baseSha;
  if (candidate == null && releaseTag != null) {
    candidate = await _releaseTargetCommitish(releaseTag);
  }
  if (candidate == null) return null;
  candidate = candidate.trim();
  if (candidate.isEmpty) return null;
  final exists = await _gitSucceeds(['cat-file', '-e', '$candidate^{commit}']);
  final isAncestor = await _gitSucceeds([
    'merge-base',
    '--is-ancestor',
    candidate,
    'HEAD',
  ]);
  if (exists && isAncestor) return candidate;
  stderr.writeln('警告: 边界提交 $candidate 不可用，回退为仅记录当前提交');
  return null;
}

Future<String?> _releaseTargetCommitish(String releaseTag) async {
  final result = await Process.run(
    'gh',
    [
      'release',
      'view',
      releaseTag,
      '--json',
      'targetCommitish',
      '--jq',
      '.targetCommitish',
    ],
    // Windows 下系统编码不是 UTF-8，必须显式指定，否则中文提交信息会乱码。
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) return null;
  return result.stdout as String?;
}

Future<bool> _gitSucceeds(List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return result.exitCode == 0;
}

Future<List<ChangelogCommit>> _collectCommits(String? base) async {
  final revArguments = base == null
      ? const ['rev-list', '-n', '1', 'HEAD']
      : ['rev-list', '--reverse', '--no-merges', '$base..HEAD'];
  final revResult = await Process.run(
    'git',
    revArguments,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (revResult.exitCode != 0) {
    throw StateError('git rev-list 失败: ${revResult.stderr}');
  }
  final shas = (revResult.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final commits = <ChangelogCommit>[];
  for (final sha in shas) {
    commits.add(
      ChangelogCommit(
        subject: await _commitFormat(sha, '%s'),
        body: await _commitFormat(sha, '%b'),
      ),
    );
  }
  return commits;
}

Future<String> _commitFormat(String sha, String format) async {
  final result = await Process.run('git', [
    'show',
    '-s',
    '--format=$format',
    sha,
  ], stdoutEncoding: utf8, stderrEncoding: utf8);
  if (result.exitCode != 0) {
    throw StateError('git show $sha 失败: ${result.stderr}');
  }
  return result.stdout as String;
}

/// 文本是否包含 GitHub 源信息（域名或仓库身份串）。
bool containsGithubSourceInfo(String text) {
  return _githubDomainPattern.hasMatch(text) ||
      _repositoryIdentityPattern.hasMatch(text);
}

bool isBuildMetadataCommit(String subject) {
  return subject.trim().startsWith('chore: bump build metadata');
}

bool isMergeCommitSubject(String subject) {
  return subject.trimLeft().toLowerCase().startsWith('merge ');
}

/// 净化提交主题：去掉控制字符与尾部 PR 引用后去首尾空白。
String sanitizeChangelogSubject(String subject) {
  var text = subject
      .replaceAll('\r\n', '\n')
      .split('\n')
      .first
      .replaceAll(_controlCharacterPattern, '');
  do {
    text = text.replaceFirst(_pullRequestSuffixPattern, '');
  } while (_pullRequestSuffixPattern.hasMatch(text));
  return text.trim();
}

/// 单条提交的日志行（主题 + 正文短横线行）；被过滤或净化后无内容时返回空列表。
List<String> changelogEntryLines(ChangelogCommit commit) {
  if (isBuildMetadataCommit(commit.subject) ||
      isMergeCommitSubject(commit.subject)) {
    return const [];
  }
  final subject = sanitizeChangelogSubject(commit.subject);
  if (subject.isEmpty || containsGithubSourceInfo(subject)) {
    return const [];
  }
  return [subject, ..._normalizedBodyLines(commit.body)];
}

/// 正文归一化为 " - " 短横线行，与 Release 说明格式一致；
/// 途中丢弃尾注、issue 引用与含源信息的行，并去掉首尾空行。
List<String> _normalizedBodyLines(String body) {
  final normalized = body.replaceAll('\r\n', '\n');
  if (normalized.replaceAll(RegExp(r'\s'), '').isEmpty) return const [];

  final lines = <String>[];
  for (final rawLine in normalized.split('\n')) {
    var line = rawLine
        .replaceFirst(RegExp(r'^\s+'), '')
        .replaceFirst(RegExp(r'^-\s*'), '')
        .replaceAll(_controlCharacterPattern, '');
    if (_gitTrailerLinePattern.hasMatch(line) ||
        _issueReferenceLinePattern.hasMatch(line) ||
        containsGithubSourceInfo(line)) {
      continue;
    }
    lines.add(line.trim());
  }
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.map((line) => line.isEmpty ? '' : ' - $line').toList();
}

/// 汇总提交为最终日志文本：条目之间以空行分隔。
String buildChangelogNotes(List<ChangelogCommit> commits) {
  final entries = commits
      .map(changelogEntryLines)
      .where((lines) => lines.isNotEmpty)
      .map((lines) => lines.join('\n'));
  return entries.join('\n\n').trim();
}

/// 转义为单引号 Dart 字符串字面量。
String dartStringLiteral(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return "'$escaped'";
}

/// 渲染最终的内嵌日志 Dart 源文件。
String renderBuildChangelogSource({
  required String version,
  required String notes,
}) {
  const header = '// GENERATED FILE - CI 构建前由 tool/generate_build_changelog.dart 生成。\n'
      '// 仓库内默认保持空值（本地构建不展示更新日志弹窗），请勿手动提交生成内容。\n';
  return '$header\n'
      '/// 内嵌更新日志对应的构建版本，形如 0.113.5+893；为空表示本地构建。\n'
      'const String kBuildChangelogVersion = ${dartStringLiteral(version)};\n'
      '\n'
      '/// 净化后的更新内容（多行文本，条目间空行分隔）；为空表示无内嵌日志。\n'
      'const String kBuildChangelogNotes = ${dartStringLiteral(notes)};\n';
}

/// 最终断言：生成源文件中不得出现任何 GitHub 源信息，命中即失败。
void assertNoGithubSourceInfo(String source) {
  final domain = _githubDomainPattern.firstMatch(source);
  if (domain != null) {
    throw FormatException('内嵌更新日志包含 GitHub 域名: ${domain.group(0)}');
  }
  final identity = _repositoryIdentityPattern.firstMatch(source);
  if (identity != null) {
    throw FormatException('内嵌更新日志包含仓库身份信息: ${identity.group(0)}');
  }
}
