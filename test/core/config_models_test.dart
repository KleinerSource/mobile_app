import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/models/ffmpeg_config.dart';

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
      'audio_extract_workers': 6,
      'audio_extract_threads': 4,
    });

    expect(config.hwAccel, 'qsv');
    expect(config.enabled, isTrue);
    expect(config.hwFallback, isFalse);
    expect(config.audioExtractWorkers, 6);
    expect(config.audioExtractThreads, 4);
    expect(config.toJson()['hwaccel'], 'qsv');
    expect(config.toJson()['audio_extract_workers'], 6);
    expect(config.toJson()['audio_extract_threads'], 4);
  });

  test('FFmpeg 音频提取设置超出范围时使用默认值', () {
    final config = FfmpegConfig.fromJson(const {
      'audio_extract_workers': 0,
      'audio_extract_threads': 17,
    });

    expect(config.audioExtractWorkers, FfmpegConfig.defaultAudioExtractWorkers);
    expect(config.audioExtractThreads, FfmpegConfig.defaultAudioExtractThreads);
  });

  test('未知硬件后端回退到 none', () {
    expect(
      FfmpegConfig.fromJson(const {'hwaccel': 'videotoolbox'}).hwAccel,
      'none',
    );
  });

  test('DB Online 配置读写 API Key 和起始年月', () {
    final config = DboConfig.fromJson(const {
      'enabled': true,
      'api_key': 'dbo-secret',
      'min_resource_month': '2024-01',
    });

    expect(config.apiKey, 'dbo-secret');
    expect(config.hasApiKey, isTrue);
    expect(config.toJson()['api_key'], 'dbo-secret');
    expect(config.minResourceMonth, '2024-01');
    expect(config.toJson()['min_resource_month'], '2024-01');
  });

  test('访问控制配置读取会话策略和验证方式状态', () {
    final config = AuthConfig.fromJson(const {
      'enabled': true,
      'configured': true,
      'password_login_disabled': false,
      'refresh_token_expire_days': 14,
      'max_failed_attempts': 8,
      'lock_minutes': 45,
      'totp_configured': true,
      'webauthn_configured': true,
    });

    expect(config.enabled, isTrue);
    expect(config.refreshTokenExpireDays, 14);
    expect(config.maxFailedAttempts, 8);
    expect(config.lockMinutes, 45);
    expect(config.totpConfigured, isTrue);
    expect(config.webAuthnConfigured, isTrue);
  });
}
