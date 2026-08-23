import 'package:flutter/foundation.dart';

/// 媒体流详情模型。
///
/// 后端 `GET /movies/id/{id}/media-info` 在文件级摘要字段之外还返回
/// `video` / `audio_streams[]` / `subtitle_streams[]`（由缓存的 probe_json
/// 重建，见 backend media_info_service.go）。本文件用纯手写类解析，
/// 避免改动 freezed 生成的模型。
///
/// 字段命名与 backend/internal/services/ffmpeg/probe.go 的 json tag 对齐。

@immutable
class VideoStreamInfo {
  const VideoStreamInfo({
    this.index,
    this.codec,
    this.profile,
    this.level,
    this.width,
    this.height,
    this.frameRate,
    this.pixFmt,
    this.bitRate,
    this.displayAspectRatio,
    this.bitDepth,
    this.colorTransfer,
    this.colorPrimaries,
    this.colorSpace,
    this.colorRange,
    this.dolbyVision = false,
  });

  final int? index;
  final String? codec;
  final String? profile;
  final int? level;
  final int? width;
  final int? height;
  final double? frameRate;
  final String? pixFmt;
  final int? bitRate;

  /// 长宽比（"16:9"），缺失时由 UI 按宽高推导。
  final String? displayAspectRatio;
  final int? bitDepth;

  // 色彩元数据：用于判断 HDR / Dolby Vision。
  final String? colorTransfer; // smpte2084=HDR10, arib-std-b67=HLG
  final String? colorPrimaries; // bt2020 等
  final String? colorSpace; // bt2020nc 等
  final String? colorRange; // tv=Limited, pc=Full
  final bool dolbyVision;

  static VideoStreamInfo? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return VideoStreamInfo(
      index: _asInt(json['index']),
      codec: _asStr(json['codec']),
      profile: _asStr(json['profile']),
      level: _asInt(json['level']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      frameRate: _asDouble(json['frame_rate']),
      pixFmt: _asStr(json['pix_fmt']),
      bitRate: _asInt(json['bit_rate']),
      displayAspectRatio: _asStr(json['display_aspect_ratio']),
      bitDepth: _asInt(json['bit_depth']),
      colorTransfer: _asStr(json['color_transfer']),
      colorPrimaries: _asStr(json['color_primaries']),
      colorSpace: _asStr(json['color_space']),
      colorRange: _asStr(json['color_range']),
      dolbyVision: json['dolby_vision'] == true,
    );
  }
}

@immutable
class AudioStreamInfo {
  const AudioStreamInfo({
    this.index,
    this.codec,
    this.profile,
    this.channels,
    this.channelLayout,
    this.sampleRate,
    this.bitRate,
    this.language,
    this.title,
    this.isDefault = false,
  });

  final int? index;
  final String? codec;
  final String? profile; // 音频等级，如 AAC "LC"、DTS "MA"
  final int? channels;
  final String? channelLayout;
  final int? sampleRate;
  final int? bitRate;
  final String? language;
  final String? title;
  final bool isDefault;

  static AudioStreamInfo fromJson(Map<String, dynamic> json) {
    return AudioStreamInfo(
      index: _asInt(json['index']),
      codec: _asStr(json['codec']),
      profile: _asStr(json['profile']),
      channels: _asInt(json['channels']),
      channelLayout: _asStr(json['channel_layout']),
      sampleRate: _asInt(json['sample_rate']),
      bitRate: _asInt(json['bit_rate']),
      language: _asStr(json['language']),
      title: _asStr(json['title']),
      isDefault: json['default'] == true,
    );
  }
}

@immutable
class SubtitleStreamInfo {
  const SubtitleStreamInfo({
    this.index,
    this.codec,
    this.language,
    this.title,
    this.isDefault = false,
    this.forced = false,
    this.playable = false,
  });

  final int? index;
  final String? codec;
  final String? language;
  final String? title;
  final bool isDefault;
  final bool forced;

  /// 文字字幕可直接转 WebVTT 提供播放器轨道；位图字幕仅展示。
  final bool playable;

  static SubtitleStreamInfo fromJson(Map<String, dynamic> json) {
    return SubtitleStreamInfo(
      index: _asInt(json['index']),
      codec: _asStr(json['codec']),
      language: _asStr(json['language']),
      title: _asStr(json['title']),
      isDefault: json['default'] == true,
      forced: json['forced'] == true,
      playable: json['playable'] == true,
    );
  }
}

@immutable
class MediaStreams {
  const MediaStreams({
    this.video,
    this.audioStreams = const [],
    this.subtitleStreams = const [],
  });

  final VideoStreamInfo? video;
  final List<AudioStreamInfo> audioStreams;
  final List<SubtitleStreamInfo> subtitleStreams;

  bool get hasContent =>
      video != null || audioStreams.isNotEmpty || subtitleStreams.isNotEmpty;

  static MediaStreams fromJson(Map<String, dynamic> json) {
    return MediaStreams(
      video: VideoStreamInfo.fromJson(
        json['video'] is Map ? _asMap(json['video']) : null,
      ),
      audioStreams: _mapList(json['audio_streams'], AudioStreamInfo.fromJson),
      subtitleStreams: _mapList(
        json['subtitle_streams'],
        SubtitleStreamInfo.fromJson,
      ),
    );
  }
}

/// 详情接口响应：文件级摘要 + 嵌套流结构来自同一份 JSON。
@immutable
class MediaInfoDetail {
  const MediaInfoDetail({
    required this.streams,
    this.container,
    this.durationSec,
    this.bitRate,
    this.fileSize,
  });

  /// 文件级摘要字段（同一响应的顶层字段）。
  final String? container;
  final double? durationSec;
  final int? bitRate;
  final int? fileSize;

  final MediaStreams streams;

  static MediaInfoDetail fromJson(Map<String, dynamic> json) {
    return MediaInfoDetail(
      container: _asStr(json['container']),
      durationSec: _asDouble(json['duration_sec']),
      bitRate: _asInt(json['bit_rate']),
      fileSize: _asInt(json['file_size']),
      streams: MediaStreams.fromJson(json),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _asStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<T> _mapList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return const [];
  return [
    for (final item in v)
      if (item is Map) fromJson(Map<String, dynamic>.from(item)),
  ];
}
