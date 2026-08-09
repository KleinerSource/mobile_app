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
  final currentPatch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!) + 1;
  final patch = _shouldBumpPatch(args) ? currentPatch + 1 : currentPatch;
  final next = '$major.$minor.$patch+$build';
  final updated = contents.replaceRange(
    match.start,
    match.end,
    'version: $next',
  );
  file.writeAsStringSync(updated, encoding: utf8);
  stdout.writeln(next);
}

bool _shouldBumpPatch(List<String> args) {
  if (args.contains('--build-only')) return false;
  if (args.contains('--feature')) return true;
  if (!args.contains('--auto')) return true;

  final index = args.indexOf('--commit-message');
  if (index < 0 || index + 1 >= args.length) {
    throw const FormatException(
      '--auto 模式必须同时提供 --commit-message',
    );
  }
  return shouldBumpPatchForCommit(args[index + 1]);
}
