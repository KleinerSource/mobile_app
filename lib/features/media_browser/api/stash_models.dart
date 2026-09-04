import 'package:flutter/foundation.dart';

@immutable
class StashScenePage {
  const StashScenePage({required this.scenes, required this.total});

  final List<StashScene> scenes;
  final int total;

  bool hasMore(int page, int perPage) => page * perPage < total;
}

@immutable
class StashScene {
  const StashScene({
    required this.id,
    this.title = '',
    this.code,
    this.details,
    this.date,
    this.rating100,
    this.resumeTime = 0,
    this.playDuration = 0,
    this.playCount = 0,
    this.lastPlayedAt,
    this.files = const <StashSceneFile>[],
    this.paths = const StashScenePaths(),
    this.performers = const <StashScenePerson>[],
    this.studio,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String? code;
  final String? details;
  final String? date;
  final int? rating100;
  final double resumeTime;
  final double playDuration;
  final int playCount;
  final String? lastPlayedAt;
  final List<StashSceneFile> files;
  final StashScenePaths paths;
  final List<StashScenePerson> performers;
  final StashScenePerson? studio;
  final List<String> tags;

  factory StashScene.fromJson(Object? raw) {
    if (raw is! Map) return const StashScene(id: '');
    final json = Map<String, dynamic>.from(raw);
    final rawFiles = json['files'];
    final rawPerformers = json['performers'];
    final rawTags = json['tags'];
    return StashScene(
      id: _string(json['id']),
      title: _string(json['title']),
      code: _nullableString(json['code']),
      details: _nullableString(json['details']),
      date: _nullableString(json['date']),
      rating100: _int(json['rating100']),
      resumeTime: _double(json['resume_time']),
      playDuration: _double(json['play_duration']),
      playCount: _int(json['play_count']) ?? 0,
      lastPlayedAt: _nullableString(json['last_played_at']),
      files: rawFiles is List
          ? rawFiles.map(StashSceneFile.fromJson).toList(growable: false)
          : const <StashSceneFile>[],
      paths: StashScenePaths.fromJson(json['paths']),
      performers: rawPerformers is List
          ? rawPerformers
                .map(StashScenePerson.fromJson)
                .where(
                  (person) => person.id.isNotEmpty || person.name.isNotEmpty,
                )
                .toList(growable: false)
          : const <StashScenePerson>[],
      studio: json['studio'] == null
          ? null
          : StashScenePerson.fromJson(json['studio']),
      tags: rawTags is List
          ? rawTags
                .map(
                  (value) =>
                      value is Map ? _string(value['name']) : _string(value),
                )
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

@immutable
class StashSceneFile {
  const StashSceneFile({
    this.id,
    this.path,
    this.basename,
    this.size,
    this.duration,
    this.format,
    this.width,
    this.height,
    this.videoCodec,
    this.audioCodec,
    this.frameRate,
    this.bitRate,
  });

  final String? id;
  final String? path;
  final String? basename;
  final int? size;
  final double? duration;
  final String? format;
  final int? width;
  final int? height;
  final String? videoCodec;
  final String? audioCodec;
  final double? frameRate;
  final int? bitRate;

  factory StashSceneFile.fromJson(Object? raw) {
    if (raw is! Map) return const StashSceneFile();
    final json = Map<String, dynamic>.from(raw);
    return StashSceneFile(
      id: _nullableString(json['id']),
      path: _nullableString(json['path']),
      basename: _nullableString(json['basename']),
      size: _int(json['size']),
      duration: _nullableDouble(json['duration']),
      format: _nullableString(json['format']),
      width: _int(json['width']),
      height: _int(json['height']),
      videoCodec: _nullableString(json['video_codec']),
      audioCodec: _nullableString(json['audio_codec']),
      frameRate: _nullableDouble(json['frame_rate']),
      bitRate: _int(json['bit_rate']),
    );
  }
}

@immutable
class StashScenePaths {
  const StashScenePaths({
    this.screenshot,
    this.preview,
    this.stream,
    this.webp,
  });

  final String? screenshot;
  final String? preview;
  final String? stream;
  final String? webp;

  factory StashScenePaths.fromJson(Object? raw) {
    if (raw is! Map) return const StashScenePaths();
    final json = Map<String, dynamic>.from(raw);
    return StashScenePaths(
      screenshot: _nullableString(json['screenshot']),
      preview: _nullableString(json['preview']),
      stream: _nullableString(json['stream']),
      webp: _nullableString(json['webp']),
    );
  }
}

@immutable
class StashScenePerson {
  const StashScenePerson({this.id = '', this.name = '', this.role});

  final String id;
  final String name;
  final String? role;

  factory StashScenePerson.fromJson(Object? raw) {
    if (raw is! Map) return StashScenePerson(name: _string(raw));
    final json = Map<String, dynamic>.from(raw);
    return StashScenePerson(
      id: _string(json['id']),
      name: _string(json['name']),
      role: _nullableString(json['role']),
    );
  }
}

@immutable
class StashSceneStream {
  const StashSceneStream({required this.url, this.mimeType, this.label});

  final String url;
  final String? mimeType;
  final String? label;

  factory StashSceneStream.fromJson(Object? raw) {
    if (raw is! Map) return const StashSceneStream(url: '');
    final json = Map<String, dynamic>.from(raw);
    return StashSceneStream(
      url: _string(json['url']),
      mimeType: _nullableString(json['mime_type']),
      label: _nullableString(json['label']),
    );
  }
}

String _string(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final valueText = _string(value);
  return valueText.isEmpty ? null : valueText;
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value));
}

double _double(Object? value) => _nullableDouble(value) ?? 0;

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value));
}
