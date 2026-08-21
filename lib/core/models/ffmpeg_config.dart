import 'package:flutter/foundation.dart';

@immutable
class FfmpegConfig {
  const FfmpegConfig({
    this.ffmpegPath = '',
    this.ffprobePath = '',
    this.hwAccel = 'amf',
    this.enabled = true,
    this.hwFallback = true,
    this.audioExtractWorkers = defaultAudioExtractWorkers,
    this.audioExtractThreads = defaultAudioExtractThreads,
  });

  static const defaultAudioExtractWorkers = 2;
  static const defaultAudioExtractThreads = 1;
  static const minAudioSetting = 1;
  static const maxAudioSetting = 16;

  static const supportedHardwareAccels = <String>[
    'none',
    'amf',
    'nvenc',
    'qsv',
  ];

  final String ffmpegPath;
  final String ffprobePath;
  final String hwAccel;
  final bool enabled;
  final bool hwFallback;
  final int audioExtractWorkers;
  final int audioExtractThreads;

  factory FfmpegConfig.fromJson(Map<String, dynamic> json) => FfmpegConfig(
    ffmpegPath: json['ffmpeg_path']?.toString() ?? '',
    ffprobePath: json['ffprobe_path']?.toString() ?? '',
    hwAccel: _validHardwareAccel(json['hwaccel']?.toString()),
    enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    hwFallback: json['hw_fallback'] is bool
        ? json['hw_fallback'] as bool
        : true,
    audioExtractWorkers: _validAudioSetting(
      json['audio_extract_workers'],
      defaultAudioExtractWorkers,
    ),
    audioExtractThreads: _validAudioSetting(
      json['audio_extract_threads'],
      defaultAudioExtractThreads,
    ),
  );

  Map<String, dynamic> toJson() => {
    'ffmpeg_path': ffmpegPath,
    'ffprobe_path': ffprobePath,
    'hwaccel': hwAccel,
    'enabled': enabled,
    'hw_fallback': hwFallback,
    'audio_extract_workers': audioExtractWorkers,
    'audio_extract_threads': audioExtractThreads,
  };

  static int _validAudioSetting(Object? raw, int fallback) {
    int? value;
    if (raw is int) {
      value = raw;
    } else if (raw is num && raw == raw.round()) {
      value = raw.toInt();
    } else if (raw is String) {
      value = int.tryParse(raw.trim());
    }
    if (value == null || value < minAudioSetting || value > maxAudioSetting) {
      return fallback;
    }
    return value;
  }

  static String _validHardwareAccel(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return 'amf';
    return supportedHardwareAccels.contains(normalized) ? normalized : 'none';
  }
}
