import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/avdb_config.dart';
import 'package:md_center/core/models/ffmpeg_config.dart';

void main() {
  test('AVDB 数据源配置读写 enabled、URL 和 API Key', () {
    final config = AvdbConfig.fromJson(const {
      'enabled': true,
      'base_url': 'https://avdb.example',
      'api_key': '***masked***',
    });

    expect(config.enabled, isTrue);
    expect(config.baseUrl, 'https://avdb.example');
    expect(config.hasApiKey, isTrue);
    expect(config.toJson()['api_key'], '***masked***');
  });

  test('FFmpeg 配置读写硬解开关和失败回退', () {
    final config = FfmpegConfig.fromJson(const {
      'ffmpeg_path': '/usr/local/bin/ffmpeg',
      'ffprobe_path': '/usr/local/bin/ffprobe',
      'hwaccel': 'qsv',
      'enabled': true,
      'hw_fallback': false,
    });

    expect(config.hwAccel, 'qsv');
    expect(config.enabled, isTrue);
    expect(config.hwFallback, isFalse);
    expect(config.toJson()['hwaccel'], 'qsv');
  });

  test('未知硬件后端回退到 none', () {
    expect(
      FfmpegConfig.fromJson(const {'hwaccel': 'videotoolbox'}).hwAccel,
      'none',
    );
  });
}
