import 'package:flutter/foundation.dart';

import '../api/error_codes.dart';

/// OMM 预览视频与 Sprite/VTT 生成配置。
@immutable
class PreviewConfig {
  const PreviewConfig({
    this.autoGenerateOnScan = false,
    this.audio = true,
    this.segments = 12,
    this.segmentDuration = 0.75,
    this.excludeStart = 0,
    this.excludeEnd = 0,
    this.preset = 'slow',
    this.spriteInterval = 0,
    this.spriteMinimum = 81,
    this.spriteMaximum = 81,
    this.spriteSize = 160,
  });

  static const minSegments = 1;
  static const maxSegments = 60;
  static const maxSegmentDuration = 30.0;
  static const minExcludePercent = 0.0;
  static const maxExcludePercent = 99.0;
  static const maxSpriteInterval = 3600;
  static const minSpriteCount = 1;
  static const maxSpriteCount = 400;
  static const minSpriteSize = 32;
  static const maxSpriteSize = 512;

  static const supportedPresets = <String>[
    'ultrafast',
    'superfast',
    'veryfast',
    'faster',
    'fast',
    'medium',
    'slow',
    'slower',
    'veryslow',
  ];

  final bool autoGenerateOnScan;
  final bool audio;
  final int segments;
  final double segmentDuration;
  final double excludeStart;
  final double excludeEnd;
  final String preset;
  final int spriteInterval;
  final int spriteMinimum;
  final int spriteMaximum;
  final int spriteSize;

  factory PreviewConfig.fromJson(Map<String, dynamic> json) {
    final excludeStart = _doubleValue(json['exclude_start'], 0);
    final excludeEnd = _doubleValue(json['exclude_end'], 0);
    final validExcludes = _validExclude(excludeStart, excludeEnd);
    final minimum = _intValue(json['sprite_minimum'], 81);
    final maximum = _intValue(json['sprite_maximum'], 81);
    final validSpriteRange =
        minimum >= minSpriteCount &&
        minimum <= maxSpriteCount &&
        maximum >= minimum &&
        maximum <= maxSpriteCount;

    return PreviewConfig(
      autoGenerateOnScan: json['auto_generate_on_scan'] is bool
          ? json['auto_generate_on_scan'] as bool
          : false,
      audio: json['audio'] is bool ? json['audio'] as bool : true,
      segments: _inRangeInt(json['segments'], minSegments, maxSegments, 12),
      segmentDuration: _validSegmentDuration(json['segment_duration']),
      excludeStart: validExcludes ? excludeStart : 0,
      excludeEnd: validExcludes ? excludeEnd : 0,
      preset: supportedPresets.contains(json['preset']?.toString())
          ? json['preset'].toString()
          : 'slow',
      spriteInterval: _inRangeInt(
        json['sprite_interval'],
        0,
        maxSpriteInterval,
        0,
      ),
      spriteMinimum: validSpriteRange ? minimum : 81,
      spriteMaximum: validSpriteRange ? maximum : 81,
      spriteSize: _inRangeInt(
        json['sprite_size'],
        minSpriteSize,
        maxSpriteSize,
        160,
      ),
    );
  }

  /// 返回保存前的校验错误；返回 null 表示可以提交。
  String? get validationError {
    if (segments < minSegments || segments > maxSegments) {
      return AppErrorCode.previewSegmentsInvalid;
    }
    if (segmentDuration <= 0 || segmentDuration > maxSegmentDuration) {
      return AppErrorCode.previewSegmentDurationInvalid;
    }
    if (!_validExclude(excludeStart, excludeEnd)) {
      return AppErrorCode.previewExcludeInvalid;
    }
    if (!supportedPresets.contains(preset)) {
      return AppErrorCode.previewPresetInvalid;
    }
    if (spriteInterval < 0 || spriteInterval > maxSpriteInterval) {
      return AppErrorCode.previewSpriteIntervalInvalid;
    }
    if (spriteMinimum < minSpriteCount || spriteMinimum > maxSpriteCount) {
      return AppErrorCode.previewSpriteMinimumInvalid;
    }
    if (spriteMaximum < spriteMinimum || spriteMaximum > maxSpriteCount) {
      return AppErrorCode.previewSpriteMaximumInvalid;
    }
    if (spriteSize < minSpriteSize || spriteSize > maxSpriteSize) {
      return AppErrorCode.previewSpriteSizeInvalid;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'auto_generate_on_scan': autoGenerateOnScan,
    'audio': audio,
    'segments': segments,
    'segment_duration': segmentDuration,
    'exclude_start': excludeStart,
    'exclude_end': excludeEnd,
    'preset': preset,
    'sprite_interval': spriteInterval,
    'sprite_minimum': spriteMinimum,
    'sprite_maximum': spriteMaximum,
    'sprite_size': spriteSize,
  };

  PreviewConfig copyWith({
    bool? autoGenerateOnScan,
    bool? audio,
    int? segments,
    double? segmentDuration,
    double? excludeStart,
    double? excludeEnd,
    String? preset,
    int? spriteInterval,
    int? spriteMinimum,
    int? spriteMaximum,
    int? spriteSize,
  }) {
    return PreviewConfig(
      autoGenerateOnScan: autoGenerateOnScan ?? this.autoGenerateOnScan,
      audio: audio ?? this.audio,
      segments: segments ?? this.segments,
      segmentDuration: segmentDuration ?? this.segmentDuration,
      excludeStart: excludeStart ?? this.excludeStart,
      excludeEnd: excludeEnd ?? this.excludeEnd,
      preset: preset ?? this.preset,
      spriteInterval: spriteInterval ?? this.spriteInterval,
      spriteMinimum: spriteMinimum ?? this.spriteMinimum,
      spriteMaximum: spriteMaximum ?? this.spriteMaximum,
      spriteSize: spriteSize ?? this.spriteSize,
    );
  }
}

bool _validExclude(double start, double end) {
  return start >= PreviewConfig.minExcludePercent &&
      start <= PreviewConfig.maxExcludePercent &&
      end >= PreviewConfig.minExcludePercent &&
      end <= PreviewConfig.maxExcludePercent &&
      start + end < 100;
}

double _validSegmentDuration(Object? raw) {
  final value = _doubleValue(raw, 0.75);
  return value > 0 && value <= PreviewConfig.maxSegmentDuration ? value : 0.75;
}

int _inRangeInt(Object? raw, int min, int max, int fallback) {
  final value = _intValue(raw, fallback);
  return value >= min && value <= max ? value : fallback;
}

int _intValue(Object? raw, int fallback) {
  if (raw is num && raw == raw.round()) return raw.toInt();
  return int.tryParse(raw?.toString().trim() ?? '') ?? fallback;
}

double _doubleValue(Object? raw, double fallback) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString().trim() ?? '') ?? fallback;
}
