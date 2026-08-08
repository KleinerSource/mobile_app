import 'package:flutter/foundation.dart';

@immutable
class FfmpegConfig {
  const FfmpegConfig({
    this.ffmpegPath = '',
    this.ffprobePath = '',
    this.hwAccel = 'amf',
    this.enabled = true,
    this.hwFallback = true,
  });

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

  factory FfmpegConfig.fromJson(Map<String, dynamic> json) => FfmpegConfig(
        ffmpegPath: json['ffmpeg_path']?.toString() ?? '',
        ffprobePath: json['ffprobe_path']?.toString() ?? '',
        hwAccel: _validHardwareAccel(json['hwaccel']?.toString()),
        enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
        hwFallback:
            json['hw_fallback'] is bool ? json['hw_fallback'] as bool : true,
      );

  Map<String, dynamic> toJson() => {
        'ffmpeg_path': ffmpegPath,
        'ffprobe_path': ffprobePath,
        'hwaccel': hwAccel,
        'enabled': enabled,
        'hw_fallback': hwFallback,
      };

  static String _validHardwareAccel(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return 'amf';
    return supportedHardwareAccels.contains(normalized) ? normalized : 'none';
  }
}
