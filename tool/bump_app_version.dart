import 'dart:convert';
import 'dart:io';

import 'version_policy.dart';

void main(List<String> args) {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    throw StateError('未找到 pubspec.yaml');
  }

  final contents = file.readAsStringSync(encoding: utf8);
  final match = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(contents);
  if (match == null) {
    throw const FormatException(
      'pubspec.yaml 中的 version 不是 x.y.z+build 格式',
    );
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!);
  final currentVersion = '$major.$minor.$patch+$build';
  final next = nextAppVersion(currentVersion, _versionBump(args));
  final updated = contents.replaceRange(
    match.start,
    match.end,
    'version: $next',
  );
  file.writeAsStringSync(updated, encoding: utf8);
  stdout.writeln(next);
}

VersionBump _versionBump(List<String> args) {
  if (args.contains('--build-only')) return VersionBump.buildOnly;
  if (args.contains('--feature')) return VersionBump.feature;
  if (args.contains('--bug-fix')) return VersionBump.bugFix;
  if (!args.contains('--auto')) return VersionBump.bugFix;

  final index = args.indexOf('--commit-message');
  if (index < 0 || index + 1 >= args.length) {
    throw const FormatException(
      '--auto 模式必须同时提供 --commit-message',
    );
  }
  return versionBumpForCommit(args[index + 1]);
}
