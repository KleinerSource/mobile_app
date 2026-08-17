import 'package:flutter/foundation.dart';

@immutable
class VideoCodecCapability {
  const VideoCodecCapability({
    this.maxProfile,
    this.maxLevel,
    this.pixFormats = const [],
  });

  final String? maxProfile;
  final int? maxLevel;
  final List<String> pixFormats;

  Map<String, dynamic> toJson() => {
        if (maxProfile != null && maxProfile!.isNotEmpty)
          'max_profile': maxProfile,
        if (maxLevel != null) 'max_level': maxLevel,
        if (pixFormats.isNotEmpty) 'pix_formats': pixFormats,
      };
}

@immutable
class AudioCodecCapability {
  const AudioCodecCapability({this.maxChannels, this.maxSampleRate});

  final int? maxChannels;
  final int? maxSampleRate;

  Map<String, dynamic> toJson() => {
        if (maxChannels != null) 'max_channels': maxChannels,
        if (maxSampleRate != null) 'max_sample_rate': maxSampleRate,
      };
}

@immutable
class PlaybackClientCaps {
  const PlaybackClientCaps({
    required this.containers,
    required this.videoCodecs,
    required this.audioCodecs,
    this.maxBitrate = 0,
    this.maxHeight = 0,
    this.qualityPreset = 'original',
    this.userAgent,
  });

  final List<String> containers;
  final Map<String, VideoCodecCapability> videoCodecs;
  final Map<String, AudioCodecCapability> audioCodecs;
  final int maxBitrate;
  final int maxHeight;
  final String qualityPreset;
  final String? userAgent;

  /// 移动端使用 media_kit/libmpv 播放，并默认启用系统硬解。
  ///
  /// H.264/HEVC 的级别由设备解码器处理；这里不能把缺少级别上限的
  /// HEVC 声明发送给后端，否则后端会按“不支持 HEVC”强制创建转码会话。
  /// 具体画质限制仍通过 [qualityPreset] 交给后端决定。
  factory PlaybackClientCaps.mobile({
    required String qualityPreset,
    String? userAgent,
  }) {
    return PlaybackClientCaps(
      containers: const [
        'mp4',
        'mov',
        'm4v',
        'matroska',
        'mkv',
        'webm',
        'mpegts',
      ],
      videoCodecs: _mobileVideoCodecs,
      audioCodecs: _mobileAudioCodecs,
      qualityPreset: qualityPreset,
      userAgent: userAgent,
    );
  }

  static const _mobilePixelFormats = <String>[
    'yuv420p',
    'yuvj420p',
    'yuv420p10le',
  ];

  static const _mobileVideoCodecs = <String, VideoCodecCapability>{
    'h264': VideoCodecCapability(
      maxLevel: 999,
      pixFormats: _mobilePixelFormats,
    ),
    'avc1': VideoCodecCapability(
      maxLevel: 999,
      pixFormats: _mobilePixelFormats,
    ),
    'hevc': VideoCodecCapability(
      maxLevel: 999,
      pixFormats: _mobilePixelFormats,
    ),
    'h265': VideoCodecCapability(
      maxLevel: 999,
      pixFormats: _mobilePixelFormats,
    ),
    'vp9': VideoCodecCapability(
      pixFormats: ['yuv420p', 'yuv420p10le'],
    ),
    'av1': VideoCodecCapability(
      pixFormats: ['yuv420p', 'yuv420p10le'],
    ),
  };

  static const _mobileAudioCodecs = <String, AudioCodecCapability>{
    'aac': AudioCodecCapability(maxChannels: 8),
    'ac3': AudioCodecCapability(maxChannels: 8),
    'eac3': AudioCodecCapability(maxChannels: 8),
    'mp3': AudioCodecCapability(maxChannels: 2),
    'opus': AudioCodecCapability(maxChannels: 8),
    'vorbis': AudioCodecCapability(maxChannels: 8),
    'flac': AudioCodecCapability(maxChannels: 8),
  };

  Map<String, dynamic> toJson() => {
        'containers': containers,
        'video_codecs': {
          for (final entry in videoCodecs.entries) entry.key: entry.value.toJson(),
        },
        'audio_codecs': {
          for (final entry in audioCodecs.entries) entry.key: entry.value.toJson(),
        },
        'max_bitrate': maxBitrate,
        'max_height': maxHeight,
        'quality_preset': qualityPreset,
        if (userAgent != null && userAgent!.isNotEmpty) 'ua': userAgent,
      };
}

@immutable
class AudioTrack {
  const AudioTrack({
    required this.index,
    required this.codec,
    required this.language,
    required this.title,
    required this.channels,
    required this.isDefault,
  });

  final int index;
  final String codec;
  final String language;
  final String title;
  final int channels;
  final bool isDefault;

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        index: _asInt(json['index']),
        codec: _asString(json['codec']),
        language: _asString(json['language']),
        title: _asString(json['title']),
        channels: _asInt(json['channels']),
        isDefault: json['default'] == true,
      );
}

@immutable
class SubtitleTrack {
  const SubtitleTrack({
    required this.index,
    required this.source,
    required this.language,
    required this.title,
    required this.codec,
    required this.url,
    required this.isDefault,
  });

  final int index;
  final String source;
  final String language;
  final String title;
  final String codec;
  final String url;
  final bool isDefault;

  bool get isEmbedded => source.trim().toLowerCase() == 'embedded';

  bool get isExternal => source.trim().toLowerCase() == 'external';

  bool get isPgs {
    final normalized = codec.trim().toLowerCase();
    return normalized == 'hdmv_pgs_subtitle' ||
        normalized == 'pgssub' ||
        normalized.contains('pgs');
  }

  bool get canLoad => isEmbedded || url.trim().isNotEmpty;

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
        index: _asInt(json['index']),
        source: _asString(json['source']),
        language: _asString(json['language']),
        title: _asString(json['title']),
        codec: _asString(json['codec']),
        url: _asString(json['url']),
        isDefault: json['default'] == true,
      );
}

@immutable
class PlaybackDecision {
  const PlaybackDecision({
    required this.mode,
    required this.streamUrl,
    required this.mimeType,
    required this.hwAccel,
    required this.targetVideo,
    required this.targetAudio,
    required this.targetHeight,
    required this.targetBitrate,
    required this.reasons,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.startSec,
  });

  final String mode;
  final String streamUrl;
  final String mimeType;
  final String hwAccel;
  final String targetVideo;
  final String targetAudio;
  final int targetHeight;
  final int targetBitrate;
  final List<String> reasons;
  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final double startSec;

  bool get isTranscode => mode == 'transcode';
  bool get isDirect =>
      mode == 'direct_play' || mode == 'remux' || mode == 'direct_stream';

  factory PlaybackDecision.fromJson(Map<String, dynamic> json) {
    final audio = json['audio_tracks'];
    final subtitles = json['subtitle_tracks'];
    return PlaybackDecision(
      mode: _asString(json['mode']),
      streamUrl: _asString(json['stream_url']),
      mimeType: _asString(json['mime_type']),
      hwAccel: _asString(json['hwaccel']),
      targetVideo: _asString(json['target_video']),
      targetAudio: _asString(json['target_audio']),
      targetHeight: _asInt(json['target_height']),
      targetBitrate: _asInt(json['target_bitrate']),
      reasons: _asStringList(json['reasons']),
      audioTracks: _asMapList(audio).map(AudioTrack.fromJson).toList(),
      subtitleTracks:
          _asMapList(subtitles).map(SubtitleTrack.fromJson).toList(),
      startSec: _asDouble(json['start_sec']),
    );
  }
}

@immutable
class TranscodeStatus {
  const TranscodeStatus({
    required this.active,
    required this.quality,
    required this.hwAccel,
    required this.hwDecodeOk,
    required this.hwEncodeOk,
    required this.stderrTail,
  });

  final bool active;
  final String quality;
  final String hwAccel;
  final bool hwDecodeOk;
  final bool hwEncodeOk;
  final String stderrTail;

  bool get hasHardwareFallback => hwAccel.isNotEmpty && !hwDecodeOk;

  factory TranscodeStatus.fromJson(Map<String, dynamic> json) => TranscodeStatus(
        active: json['active'] == true,
        quality: _asString(json['quality']),
        hwAccel: _asString(json['hw_accel']),
        hwDecodeOk: json['hw_decode_ok'] != false,
        hwEncodeOk: json['hw_encode_ok'] != false,
        stderrTail: _asString(json['stderr_tail']),
      );
}

String _asString(Object? value) => value?.toString() ?? '';

int _asInt(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

List<String> _asStringList(Object? value) =>
    value is List ? value.map(_asString).toList() : const [];

List<Map<String, dynamic>> _asMapList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];
