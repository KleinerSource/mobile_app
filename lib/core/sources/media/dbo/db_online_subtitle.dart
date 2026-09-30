import 'package:flutter/foundation.dart';

@immutable
class DbOnlineSubtitleFile {
  const DbOnlineSubtitleFile({
    required this.id,
    required this.name,
    this.extension = '',
    this.size = 0,
  });

  final String id;
  final String name;
  final String extension;
  final int size;

  factory DbOnlineSubtitleFile.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DbOnlineSubtitleFile(id: '', name: '');
    }
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineSubtitleFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      extension: json['extension']?.toString() ?? '',
      size: _intValue(json['size']),
    );
  }
}

@immutable
class DbOnlineSubtitleCandidate {
  const DbOnlineSubtitleCandidate({
    required this.name,
    required this.url,
    this.extension = '',
    this.languages = const <String>[],
    this.durationMs = 0,
  });

  final String name;
  final String url;
  final String extension;
  final List<String> languages;
  final int durationMs;

  factory DbOnlineSubtitleCandidate.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DbOnlineSubtitleCandidate(name: '', url: '');
    }
    final json = Map<String, dynamic>.from(raw);
    final languages = json['languages'];
    return DbOnlineSubtitleCandidate(
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      extension: json['ext']?.toString() ?? '',
      languages: languages is List
          ? languages.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      durationMs: _intValue(json['duration']),
    );
  }
}

@immutable
class DbOnlineSubtitlePreview {
  const DbOnlineSubtitlePreview({required this.content});

  final String content;

  factory DbOnlineSubtitlePreview.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineSubtitlePreview(content: '');
    return DbOnlineSubtitlePreview(content: raw['content']?.toString() ?? '');
  }
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
