import 'package:flutter/foundation.dart';

@immutable
class LrcCue {
  const LrcCue({required this.position, required this.text});

  final Duration position;
  final String text;
}

@immutable
class LrcDocument {
  const LrcDocument({required this.cues});

  final List<LrcCue> cues;

  bool get isEmpty => cues.isEmpty;

  LrcCue? cueAt(Duration position) {
    LrcCue? current;
    for (final cue in cues) {
      if (cue.position > position) break;
      current = cue;
    }
    return current;
  }

  int indexAt(Duration position) {
    var index = -1;
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].position > position) break;
      index = i;
    }
    return index;
  }
}

final _timestampPattern = RegExp(r'^\[(\d+):(\d{1,2})(?:\.(\d{1,3}))?\]$');
final _tagPrefixPattern = RegExp(r'^((?:\[[^\]]*\]\s*)+)(.*)$');
final _offsetPattern = RegExp(
  r'^\[offset:([+-]?\d+)\]\s*$',
  caseSensitive: false,
);
final _metadataPattern = RegExp(r'^\[[a-z]{1,8}:.*\]$', caseSensitive: false);

LrcDocument? parseLrc(String content) {
  var offsetMs = 0;
  final rawCues = <LrcCue>[];

  for (final rawLine
      in content.replaceFirst('\ufeff', '').split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final offsetMatch = _offsetPattern.firstMatch(line);
    if (offsetMatch != null) {
      offsetMs = int.tryParse(offsetMatch.group(1)!) ?? offsetMs;
      continue;
    }

    final prefix = _tagPrefixPattern.firstMatch(line);
    if (prefix == null) continue;
    final tags = RegExp(
      r'\[[^\]]*\]',
    ).allMatches(prefix.group(1)!).map((match) => match.group(0)!).toList();
    final timestamps = tags
        .map(_timestampPattern.firstMatch)
        .toList(growable: false);
    if (timestamps.isEmpty ||
        timestamps.any((timestamp) => timestamp == null)) {
      continue;
    }
    final text = prefix.group(2)!.trim();
    if (text.isEmpty || _metadataPattern.hasMatch(line)) continue;

    for (final timestamp in timestamps) {
      final match = timestamp!;
      final minutes = int.tryParse(match.group(1)!) ?? 0;
      final seconds = int.tryParse(match.group(2)!) ?? 0;
      if (seconds >= 60) continue;
      final fraction = _fractionToMilliseconds(match.group(3));
      final milliseconds = minutes * 60 * 1000 + seconds * 1000 + fraction;
      rawCues.add(
        LrcCue(
          position: Duration(milliseconds: milliseconds),
          text: text,
        ),
      );
    }
  }

  if (rawCues.isEmpty) return null;
  final cues = rawCues
      .map((cue) {
        final adjusted = cue.position.inMilliseconds + offsetMs;
        return adjusted < 0
            ? null
            : LrcCue(
                position: Duration(milliseconds: adjusted),
                text: cue.text,
              );
      })
      .whereType<LrcCue>()
      .toList();
  if (cues.isEmpty) return null;
  cues.sort((a, b) => a.position.compareTo(b.position));
  return LrcDocument(cues: List<LrcCue>.unmodifiable(cues));
}

int _fractionToMilliseconds(String? value) {
  if (value == null || value.isEmpty) return 0;
  final digits = value.padRight(3, '0').substring(0, 3);
  return int.tryParse(digits) ?? 0;
}
