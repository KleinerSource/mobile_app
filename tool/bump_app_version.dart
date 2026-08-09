import 'dart:convert';
import 'dart:io';

void main() {
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
    throw FormatException('pubspec.yaml 中的 version 不是 x.y.z+build 格式');
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!) + 1;
  final build = int.parse(match.group(4)!) + 1;
  final next = '$major.$minor.$patch+$build';
  final updated = contents.replaceRange(
    match.start,
    match.end,
    'version: $next',
  );
  file.writeAsStringSync(updated, encoding: utf8);
  stdout.writeln(next);
}
