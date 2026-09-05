// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/core/config_models_test.dart
//   - test/core/playback_models_test.dart
//   - test/core/system_models_test.dart
//   - test/core/update_models_test.dart
//   - test/core/modal_transcription_config_test.dart
//   - test/core/actor_avatar_url_test.dart
//   - test/features/movie_detail_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/actor.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/models/ffmpeg_config.dart';
import 'package:omm/core/models/modal_transcription_config.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/playback.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/models/preview_config.dart';
import 'package:omm/core/models/system.dart';
import 'package:omm/core/update/update_installer.dart';
import 'package:omm/core/update/update_models.dart';
import 'package:omm/core/update/update_service.dart';
import 'package:omm/shared/actor_avatar.dart';

// ==================== 原 test/core/config_models_test.dart ====================
void _main_0() {
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

// ==================== 原 test/core/playback_models_test.dart ====================
Map<String, dynamic> _minimalDecisionJson() => {
  'mode': 'direct_play',
  'stream_url': '/api/movies/id/1/direct-stream',
  'direct_url': '/api/movies/id/1/stream',
  'quality_options': [
    {'id': 'auto', 'label': '自动', 'kind': 'auto'},
  ],
};

void _main_1() {
  test('播放决策解析模式、音轨和字幕轨', () {
    final decision = PlaybackDecision.fromJson(const {
      'mode': 'transcode',
      'stream_url': '/api/movies/id/1/stream.m3u8?quality=1080p',
      'direct_url': '/api/movies/id/1/stream',
      'quality_options': [
        {'id': 'auto', 'label': '自动', 'kind': 'auto'},
        {'id': 'original', 'label': '4K（原生）', 'kind': 'original'},
        {'id': '1080p', 'label': '1080P', 'kind': 'transcode'},
      ],
      'mime_type': 'application/vnd.apple.mpegurl',
      'container': 'matroska,webm',
      'video_codec': 'hevc',
      'duration_sec': 123.5,
      'bit_rate': 4000000,
      'hwaccel': 'videotoolbox',
      'target_video': 'h264',
      'target_audio': 'aac',
      'target_width': 1920,
      'target_height': 1080,
      'target_bitrate': 8000000,
      'reasons': ['container=matroska'],
      'audio_tracks': [
        {
          'index': 1,
          'codec': 'aac',
          'language': 'jpn',
          'title': '日语',
          'channels': 2,
          'default': true,
        },
      ],
      'subtitle_tracks': [
        {
          'id': 'subtitle-2',
          'index': 2,
          'source': 'external',
          'language': 'zh',
          'title': '简体中文',
          'codec': 'ass',
          'url': '/api/movies/id/1/subtitles/2?format=vtt',
          'default': true,
          'render_mode': 'overlay',
          'playable': true,
          'forced': true,
        },
      ],
    });

    expect(decision.isTranscode, isTrue);
    expect(decision.directUrl, '/api/movies/id/1/stream');
    expect(decision.qualityOptions.map((option) => option.id), [
      'auto',
      'original',
      '1080p',
    ]);
    expect(decision.audioTracks.single.language, 'jpn');
    expect(decision.subtitleTracks.single.url, contains('format=vtt'));
    expect(decision.subtitleTracks.single.isExternal, isTrue);
    expect(decision.subtitleTracks.single.canLoad, isTrue);
    expect(decision.subtitleTracks.single.id, 'subtitle-2');
    expect(decision.subtitleTracks.single.renderMode, 'overlay');
    expect(decision.subtitleTracks.single.forced, isTrue);
    expect(decision.targetHeight, 1080);
    expect(decision.targetWidth, 1920);
    expect(decision.container, 'matroska,webm');
    expect(decision.videoCodec, 'hevc');
    expect(decision.durationSec, 123.5);
    expect(decision.bitRate, 4000000);
  });

  test('硬解失败状态可识别软解回退', () {
    final status = TranscodeStatus.fromJson(const {
      'active': true,
      'quality': '1080p',
      'hw_accel': 'videotoolbox',
      'hw_decode_ok': false,
      'hw_encode_ok': true,
      'stderr_tail': 'hardware decoder failed',
    });

    expect(status.hasHardwareFallback, isTrue);
  });

  test('PGS 内嵌字幕可识别为原生位图字幕', () {
    const track = SubtitleTrack(
      index: 4,
      source: 'embedded',
      language: 'eng',
      title: 'English PGS',
      codec: 'hdmv_pgs_subtitle',
      url: '',
      isDefault: false,
    );

    expect(track.isPgs, isTrue);
    expect(track.typeLabel, 'PGS');
    expect(track.source, 'embedded');
    expect(track.isEmbedded, isTrue);
    expect(track.canLoad, isTrue);
  });

  test('普通文本字幕不启用 PGS 原生渲染', () {
    const track = SubtitleTrack(
      index: 3,
      source: 'embedded',
      language: 'zh',
      title: '中文',
      codec: 'ass',
      url: '/embedded.ass',
      isDefault: false,
    );

    expect(track.isPgs, isFalse);
    expect(track.typeLabel, 'ASS');
    expect(track.source, 'embedded');
  });

  test('KSPlayer 能力声明宽格式客户端容器和编解码', () {
    final json = PlaybackClientCaps.ksPlayer(
      qualityPreset: 'original',
    ).toJson();

    expect(json['containers'], contains('mkv'));
    expect((json['video_codecs'] as Map).keys, contains('vp9'));
    expect((json['audio_codecs'] as Map).keys, contains('flac'));
  });

  test('强制服务器视频转码能力字段仅在启用时发送', () {
    final normal = PlaybackClientCaps.mediaKit(qualityPreset: 'auto').toJson();
    final fallback = PlaybackClientCaps.mediaKit(
      qualityPreset: 'auto',
      forceVideoTranscode: true,
    ).toJson();

    expect(normal.containsKey('force_video_transcode'), isFalse);
    expect(fallback['force_video_transcode'], isTrue);
  });

  test('缺失 direct_url 或 quality_options 视为服务器协议错误', () {
    final missingDirect = _minimalDecisionJson()..remove('direct_url');
    final missingOptions = _minimalDecisionJson()..remove('quality_options');
    final emptyOptions = _minimalDecisionJson()..['quality_options'] = [];

    for (final json in [missingDirect, missingOptions, emptyOptions]) {
      expect(
        () => PlaybackDecision.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('服务器版本不兼容'),
          ),
        ),
      );
    }
  });

  test('格式错误或缺少自动档的 quality_options 视为协议错误', () {
    final malformed = _minimalDecisionJson()
      ..['quality_options'] = [
        {'id': 'auto', 'label': '自动', 'kind': 'unknown'},
      ];
    final missingAuto = _minimalDecisionJson()
      ..['quality_options'] = [
        {'id': 'original', 'label': '1080P（原生）', 'kind': 'original'},
      ];

    for (final json in [malformed, missingAuto]) {
      expect(
        () => PlaybackDecision.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    }
  });
}

// ==================== 原 test/core/system_models_test.dart ====================
void _main_2() {
  test('服务器资料模型保留名称和头像地址', () {
    const profile = ServerProfileData(
      name: '客厅服务器',
      avatarUrl: 'http://192.168.1.10:8001/api/public/avatar',
    );

    expect(profile.name, '客厅服务器');
    expect(profile.avatarUrl, contains('/public/avatar'));
  });
}

// ==================== 原 test/core/update_models_test.dart ====================
void _main_3() {
  test('版本号支持语义版本和 build 号比较', () {
    final current = AppReleaseVersion.parse('0.1.60+67');
    final nextPatch = AppReleaseVersion.parse('omm_0.1.61+68.apk');
    final nextBuild = AppReleaseVersion.parse('v0.1.60+68');

    expect(current.display, '0.1.60+67');
    expect(nextPatch.compareTo(current), greaterThan(0));
    expect(nextBuild.compareTo(current), greaterThan(0));
    expect(AppReleaseVersion.tryParse('latest'), isNull);
  });

  test('GitHub 地址规范化并生成 Release API 地址', () {
    final repository = GitHubRepository.parse(
      'https://github.com/example/app/releases',
    );

    expect(
      repository.canonicalUrl,
      'https://github.com/example/app',
    );
    expect(
      repository.releasesApiUrl,
      'https://api.github.com/example/app/releases?per_page=100',
    );
    expect(
      repository.releaseTagApiUrl(UpdatePlatform.ios),
      'https://api.github.com/example/app/releases/tags/latest',
    );
    expect(
      repository.releaseTagApiUrl(UpdatePlatform.android),
      'https://api.github.com/example/app/releases/tags/latest-android',
    );
    expect(
      repository.releaseTagApiUrl(UpdatePlatform.ios, development: true),
      'https://api.github.com/example/app/releases/tags/latest-ios-dev',
    );
    expect(
      repository.releaseTagApiUrl(UpdatePlatform.android, development: true),
      'https://api.github.com/example/app/releases/tags/latest-android-dev',
    );
    expect(
      () => GitHubRepository.parse('https://example.com/owner/repo'),
      throwsFormatException,
    );
  });

  test('iOS 安装器 URI 会正确编码 GitHub IPA 下载地址', () {
    const downloadUrl =
        'https://github.com/example/app/releases/download/'
        'latest/omm_0.1.64+71.ipa';

    final installerUrl = IosUpdateInstaller.installUri(downloadUrl);

    expect(installerUrl.scheme, 'apple-magnifier');
    expect(installerUrl.host, 'install');
    expect(installerUrl.queryParameters['url'], downloadUrl);
  });

  test('按平台从不同 Release 中选择最高版本产物', () {
    final releases = [
      GitHubRelease.fromJson(const {
        'tag_name': 'latest',
        'name': 'iOS build',
        'published_at': '2026-08-10T05:20:00Z',
        'assets': [
          {
            'name': 'omm_0.1.60+67.ipa',
            'browser_download_url': 'https://github.com/o/r/releases/ipa',
            'size': 100,
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'latest-android',
        'name': 'Android build',
        'published_at': '2026-08-10T05:21:00Z',
        'assets': [
          {
            'name': 'omm_0.1.60+67.apk',
            'browser_download_url': 'https://github.com/o/r/releases/apk',
            'size': 200,
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'v0.1.59+66',
        'name': 'Older Android build',
        'published_at': '2026-08-09T05:21:00Z',
        'assets': [
          {
            'name': 'omm_0.1.59+66.apk',
            'browser_download_url': 'https://github.com/o/r/releases/old',
            'size': 180,
          },
        ],
      }),
    ];

    final ios = GitHubUpdateService.selectLatestCandidate(
      releases,
      UpdatePlatform.ios,
    );
    final android = GitHubUpdateService.selectLatestCandidate(
      releases,
      UpdatePlatform.android,
    );

    expect(
      ios?.version,
      const AppReleaseVersion(major: 0, minor: 1, patch: 60, build: 67),
    );
    expect(ios?.asset.name, 'omm_0.1.60+67.ipa');
    expect(android?.asset.name, 'omm_0.1.60+67.apk');
  });

  test('滚动 Release 标签中的 IPA 资产可识别', () {
    final release = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'name': 'Latest unsigned iOS build',
      'assets': [
        {
          'name': 'omm_0.1.73+80.ipa',
          'browser_download_url':
              'https://github.com/o/r/releases/download/latest/omm_0.1.73%2B80.ipa',
          'size': 100,
        },
      ],
    });

    final candidate = GitHubUpdateService.selectLatestCandidate([
      release,
    ], UpdatePlatform.ios);

    expect(candidate?.asset.name, 'omm_0.1.73+80.ipa');
    expect(
      candidate?.version,
      const AppReleaseVersion(major: 0, minor: 1, patch: 73, build: 80),
    );
  });

  test('关闭开发版检测时忽略更高版本的开发 Release 和开发资产', () {
    final releases = [
      GitHubRelease.fromJson(const {
        'tag_name': 'latest-android',
        'published_at': '2026-08-24T15:12:58Z',
        'assets': [
          {
            'name': 'md_center_0.38.22+409.apk',
            'browser_download_url': 'https://github.com/o/r/releases/standard',
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'latest-android-dev',
        'published_at': '2026-08-25T14:23:28Z',
        'assets': [
          {
            'name': 'omm_dev_0.39.0+409.apk',
            'browser_download_url': 'https://github.com/o/r/releases/dev',
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'v0.40.0+410',
        'published_at': '2026-08-25T15:00:00Z',
        'assets': [
          {
            'name': 'omm_dev_0.40.0+410.apk',
            'browser_download_url': 'https://github.com/o/r/releases/dev-list',
          },
        ],
      }),
    ];

    final candidate = GitHubUpdateService.selectLatestCandidate(
      releases,
      UpdatePlatform.android,
    );

    expect(candidate?.asset.name, 'md_center_0.38.22+409.apk');
  });

  test('开启开发版检测时从两个渠道选择最高版本', () {
    final releases = [
      GitHubRelease.fromJson(const {
        'tag_name': 'latest',
        'assets': [
          {
            'name': 'omm_0.38.22+409.ipa',
            'browser_download_url': 'https://github.com/o/r/releases/standard',
          },
        ],
      }),
      GitHubRelease.fromJson(const {
        'tag_name': 'latest-ios-dev',
        'assets': [
          {
            'name': 'omm_dev_0.39.0+409.ipa',
            'browser_download_url': 'https://github.com/o/r/releases/dev',
          },
        ],
      }),
    ];

    final candidate = GitHubUpdateService.selectLatestCandidate(
      releases,
      UpdatePlatform.ios,
      includeDevelopment: true,
    );

    expect(candidate?.asset.name, 'omm_dev_0.39.0+409.ipa');
  });

  test('开发版缺失时仍选择标准版，相同版本按发布时间选择', () {
    final standardOnly = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'published_at': '2026-08-24T15:00:00Z',
      'assets': [
        {
          'name': 'omm_0.39.0+409.ipa',
          'browser_download_url': 'https://github.com/o/r/releases/standard',
        },
      ],
    });
    final newerStandard = GitHubRelease.fromJson(const {
      'tag_name': 'v0.39.0+409',
      'published_at': '2026-08-25T15:00:00Z',
      'assets': [
        {
          'name': 'omm_0.39.0+409.ipa',
          'browser_download_url': 'https://github.com/o/r/releases/newer',
        },
      ],
    });

    final fallback = GitHubUpdateService.selectLatestCandidate(
      [standardOnly],
      UpdatePlatform.ios,
      includeDevelopment: true,
    );
    final tied = GitHubUpdateService.selectLatestCandidate(
      [standardOnly, newerStandard],
      UpdatePlatform.ios,
      includeDevelopment: true,
    );

    expect(fallback?.asset.name, 'omm_0.39.0+409.ipa');
    expect(tied?.asset.downloadUrl, endsWith('/newer'));
  });

  test('更新说明会移除滚动构建元数据并保留实际内容', () {
    final release = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'body': '''版本: 0.12.5+204

本次构建包含以下更新：

fix: 修复服务器切换卡住
 - 增加快速鉴权路径

commit: [d1081e5](https://github.com/example/app/commit/d1081e5)
run: [308](https://github.com/example/app/actions/runs/123)''',
    });

    expect(release.updateNotes, 'fix: 修复服务器切换卡住\n - 增加快速鉴权路径');
  });

  test('没有更新说明时返回空内容', () {
    final release = GitHubRelease.fromJson(const {
      'tag_name': 'latest',
      'body': '本次构建包含以下更新：\n\ncommit: abc\nrun: 1',
    });

    expect(release.updateNotes, isEmpty);
  });
}

// ==================== 原 test/core/modal_transcription_config_test.dart ====================
void _main_4() {
  test('解析多令牌响应：脱敏凭据不进入草稿，策略与并发字段带回退', () {
    final loaded = ModalTranscriptionConfig.fromJson(const {
      'enabled': false,
      'tokens': [
        {'id': 'tok-1', 'name': '主账号', 'token_id_masked': '********2345'},
        {'id': 'tok-2', 'name': '备用', 'token_id_masked': ''},
      ],
      'token_strategy': 'round_robin',
      'per_token_workers': 4,
      'has_hf_token': true,
      'hf_token': '********abcd',
      'default_gpu': 'H100',
      'repo_branch': 'v1.8',
      'max_workers': 6,
    });

    expect(loaded.tokens, hasLength(2));
    expect(loaded.tokens.first.isExisting, isTrue);
    expect(loaded.tokens.first.tokenId, isEmpty);
    expect(loaded.tokens.first.tokenSecret, isEmpty);
    expect(loaded.tokens.last.tokenIdMasked, isEmpty);
    expect(loaded.hfToken, isEmpty);
    expect(loaded.perTokenWorkers, 4);
    expect(loaded.defaultGpu, 'H100');
    expect(loaded.maxWorkers, 6);
  });

  test('旧版单令牌响应可解析：未知策略回退轮询，字段越界收敛', () {
    final legacy = ModalTranscriptionConfig.fromJson(const {
      'enabled': true,
      'modal_token_id': '********2345',
      'has_modal_token_id': true,
      'token_strategy': 'unknown',
      'per_token_workers': 99,
      'max_workers': 0,
    });

    expect(legacy.tokens, isEmpty);
    expect(legacy.tokenStrategy, 'round_robin');
    expect(legacy.perTokenWorkers, 10);
    expect(legacy.maxWorkers, 1);
    // 旧字段不会被序列化进新协议请求。
    final request = legacy.toRequest();
    expect(request.containsKey('modal_token_id'), isFalse);
    expect(request['tokens'], isEmpty);
  });

  test('新增令牌条目序列化：无 id，凭据按需附带', () {
    const token = ModalTranscriptionToken(
      name: ' 主账号 ',
      tokenId: ' ak-1 ',
      tokenSecret: ' sk-1 ',
    );

    expect(token.isExisting, isFalse);
    expect(token.toEntryJson(), {
      'name': '主账号',
      'token_id': 'ak-1',
      'token_secret': 'sk-1',
    });

    const partial = ModalTranscriptionToken(
      id: 'tok-9',
      name: '只改备注',
      tokenId: '',
      tokenSecret: ' sk-9 ',
    );
    expect(partial.toEntryJson(), {
      'id': 'tok-9',
      'name': '只改备注',
      'token_secret': 'sk-9',
    });
  });

  test('令牌 copyWith 保留未变更字段', () {
    const source = ModalTranscriptionToken(
      id: 'tok-1',
      name: '主账号',
      tokenIdMasked: '********2345',
      tokenSecret: 'sk-1',
    );
    final renamed = source.copyWith(name: '新备注');

    expect(renamed.id, 'tok-1');
    expect(renamed.tokenIdMasked, '********2345');
    expect(renamed.tokenSecret, 'sk-1');
    expect(renamed.name, '新备注');
  });
}

// ==================== 原 test/core/actor_avatar_url_test.dart ====================
void _main_5() {
  test('演员头像地址保留反向代理前缀并使用公开接口', () {
    const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

    expect(
      actorAvatarUrl(config, 42),
      'https://media.example/oh-my-media/api/actors/42/avatar',
    );
  });

  test('演员头像刷新参数会追加到地址而不丢失反向代理前缀', () {
    const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

    expect(
      actorAvatarUrl(config, 42, cacheBust: '123'),
      'https://media.example/oh-my-media/api/actors/42/avatar?v=123',
    );
  });

  test('轮播索引会追加到头像地址,首页不携带 index 参数', () {
    const config = ServerConfig(baseUrl: 'https://media.example/oh-my-media');

    expect(
      actorAvatarUrl(config, 42, index: 2),
      'https://media.example/oh-my-media/api/actors/42/avatar?index=2',
    );
    expect(
      actorAvatarUrl(config, 42, index: 0),
      'https://media.example/oh-my-media/api/actors/42/avatar',
    );
    expect(
      actorAvatarUrl(config, 42, cacheBust: '9', index: 3),
      'https://media.example/oh-my-media/api/actors/42/avatar?index=3&v=9',
    );
  });

  test('演员模型读取后端返回的头像路径数组', () {
    final actor = ActorItem.fromJson(const {
      'id': 42,
      'name': '测试演员',
      'avatar_path': [
        'data/people/测试演员/avatar.jpg',
        'data/people/测试演员/avatar 2.jpg',
      ],
    });

    expect(actor.avatarPaths, [
      'data/people/测试演员/avatar.jpg',
      'data/people/测试演员/avatar 2.jpg',
    ]);
  });

  test('后端返回空数组或缺失时模型解析不崩溃', () {
    final empty = ActorItem.fromJson(const {
      'id': 1,
      'name': 'A',
      'avatar_path': <String>[],
    });
    expect(empty.avatarPaths, isEmpty);

    final missing = ActorItem.fromJson(const {'id': 2, 'name': 'B'});
    expect(missing.avatarPaths, isNull);
  });
}

// ==================== 原 test/features/movie_detail_model_test.dart ====================
void _main_6() {
  test('详情模型解析 thumb_uuid', () {
    final movie = MovieDetail.fromJson({
      'id': 1,
      'title': '测试影片',
      'thumb_uuid': 'thumb-uuid',
      'has_external_subtitle': true,
    });

    expect(movie.thumbUuid, 'thumb-uuid');
    expect(movie.hasExternalSubtitle, isTrue);
  });

  test('详情模型解析关联字幕文件', () {
    final movie = MovieDetail.fromJson({
      'id': 3,
      'title': '关联字幕测试',
      'has_external_subtitle': false,
      'related_files': [
        {'type': 'subtitle', 'label': '字幕文件', 'path': '/movies/test.srt'},
      ],
    });

    expect(movie.hasExternalSubtitle, isFalse);
    expect(movie.relatedFiles.single.type, 'subtitle');
    expect(movie.relatedFiles.single.path, '/movies/test.srt');
  });

  test('列表模型解析内嵌字幕轨道和视频分辨率状态', () {
    final movie = MovieListItem.fromJson({
      'id': 2,
      'title': '列表测试',
      'has_internal_subtitle': true,
      'video_width': 1920,
      'video_height': 1080,
    });

    expect(movie.hasInternalSubtitle, isTrue);
    expect(movie.videoWidth, 1920);
    expect(movie.videoHeight, 1080);
    // 内嵌轨道与文件名标识相互独立
    expect(movie.hasMuxedSubtitle, isTrue);
    expect(movie.hasFilenameSubtitle, isFalse);
  });

  test('列表模型解析已生成的预览视频地址', () {
    final movie = MovieListItem.fromJson({
      'id': 3,
      'title': '预览视频测试',
      'preview_video_url': '/api/movies/id/3/previews/preview.mp4',
    });

    expect(movie.previewVideoUrl, '/api/movies/id/3/previews/preview.mp4');
  });

  test('列表模型按文件名后缀识别内嵌字幕标识', () {
    final movie = MovieListItem.fromJson({
      'id': 4,
      'title': '文件名标识测试',
      'file_name': 'ABCD-001-uc.mp4',
    });

    expect(movie.hasInternalSubtitle, isFalse);
    expect(movie.hasMuxedSubtitle, isFalse);
    expect(movie.hasFilenameSubtitle, isTrue);
  });

  test('详情模型解析 has_internal_subtitle', () {
    final movie = MovieDetail.fromJson({
      'id': 5,
      'title': '内嵌轨道测试',
      'has_internal_subtitle': true,
    });

    expect(movie.hasInternalSubtitle, isTrue);
  });

  test('详情与列表模型解析 has_ai_subtitle', () {
    final detail = MovieDetail.fromJson({
      'id': 6,
      'title': 'AI 字幕详情',
      'has_ai_subtitle': true,
    });
    final item = MovieListItem.fromJson({
      'id': 7,
      'title': 'AI 字幕列表',
      'has_ai_subtitle': true,
    });

    expect(detail.hasAiSubtitle, isTrue);
    expect(item.hasAiSubtitle, isTrue);
    // 字段缺省时回退 false,不影响旧接口数据
    expect(
      MovieListItem.fromJson({'id': 8, 'title': '旧数据'}).hasAiSubtitle,
      isFalse,
    );
  });

  test('isAISubtitlePath 识别文件名中的 .ai. 标记段', () {
    expect(isAISubtitlePath('/movies/aaa.ai.chs.srt'), isTrue);
    expect(isAISubtitlePath('/movies/aaa.ai.srt'), isTrue);
    expect(isAISubtitlePath('/movies/aaa.ai.ass'), isTrue);
    expect(
      isAISubtitlePath(r'D:\movies\SW-621-UMR.ai.chinese.default.srt'),
      isTrue,
    );
    expect(isAISubtitlePath('/movies/SW-621-UMR.AI.chs.srt'), isTrue);
    expect(isAISubtitlePath('ai.srt'), isTrue);

    expect(isAISubtitlePath('/movies/aaa.ks.chs.srt'), isFalse);
    expect(isAISubtitlePath('/movies/aaa.ks.chs.default.ass'), isFalse);
    expect(
      isAISubtitlePath(r'D:\movies\SW-621-UMR.KS.chinese.default.ass'),
      isFalse,
    );
    expect(isAISubtitlePath('/movies/bbb.chs.srt'), isFalse);
    expect(isAISubtitlePath('/movies/abc.sai.srt'), isFalse);
    expect(isAISubtitlePath(null), isFalse);
    expect(isAISubtitlePath('  '), isFalse);
  });
}

void _main_7() {
  test('预览配置默认值和完整 JSON 往返', () {
    const defaults = PreviewConfig();
    expect(defaults.segments, 12);
    expect(defaults.segmentDuration, 0.75);
    expect(defaults.preset, 'slow');
    expect(defaults.spriteMinimum, 81);
    expect(defaults.spriteMaximum, 81);
    expect(defaults.spriteSize, 160);

    final config = PreviewConfig.fromJson(const {
      'auto_generate_on_scan': true,
      'audio': false,
      'segments': 60,
      'segment_duration': 30,
      'exclude_start': 20,
      'exclude_end': 30,
      'preset': 'veryslow',
      'sprite_interval': 3600,
      'sprite_minimum': 1,
      'sprite_maximum': 400,
      'sprite_size': 512,
    });
    expect(PreviewConfig.fromJson(config.toJson()).toJson(), config.toJson());
    expect(config.validationError, isNull);
  });

  test('预览配置非法值回退默认值，保存前校验边界', () {
    final config = PreviewConfig.fromJson(const {
      'segments': 0,
      'segment_duration': 0,
      'exclude_start': 99,
      'exclude_end': 99,
      'preset': 'unknown',
      'sprite_interval': 3601,
      'sprite_minimum': 0,
      'sprite_maximum': 401,
      'sprite_size': 31,
    });
    expect(config.segments, 12);
    expect(config.segmentDuration, 0.75);
    expect(config.excludeStart, 0);
    expect(config.excludeEnd, 0);
    expect(config.preset, 'slow');
    expect(config.spriteInterval, 0);
    expect(config.spriteMinimum, 81);
    expect(config.spriteMaximum, 81);
    expect(config.spriteSize, 160);

    expect(
      const PreviewConfig(excludeStart: 99, excludeEnd: 1).validationError,
      isNotNull,
    );
    expect(
      const PreviewConfig(spriteMinimum: 20, spriteMaximum: 10).validationError,
      isNotNull,
    );
  });

  test('预览任务兼容 REST 数字进度和 WebSocket 嵌套进度', () {
    final rest = PreviewTask.fromJson(const {
      'task_id': 'rest-1',
      'status': 'running',
      'total_count': 2,
      'completed_count': 1,
      'progress': 50,
      'current_movie_id': 8,
      'current_movie_title': '影片 8',
    });
    expect(rest.progress, 50);
    expect(rest.overallProgress, 75);

    final ws = PreviewTask.fromJson(const {
      'taskId': 'ws-1',
      'status': 'running',
      'progress': {'total': 1, 'completed': 0, 'percent': 42.5},
      'movieId': 9,
      'movieTitle': '影片 9',
    });
    expect(ws.taskId, 'ws-1');
    expect(ws.progress, 42.5);

    final status = PreviewStatus.fromJson(const {
      'movie_id': 9,
      'source_state': 'registered',
      'assets': {
        'video': {'ready': true, 'url': '/video.mp4', 'size': 12},
        'sprite': {'ready': false},
        'vtt': {'ready': true},
      },
    });
    expect(status.hasReadyAsset, isTrue);
    expect(status.assets['video']?.url, '/video.mp4');
    expect(status.assets['vtt']?.ready, isTrue);
  });
}

void main() {
  group('config_models', _main_0);
  group('playback_models', _main_1);
  group('system_models', _main_2);
  group('update_models', _main_3);
  group('modal_transcription_config', _main_4);
  group('actor_avatar_url', _main_5);
  group('movie_detail_model', _main_6);
  group('preview_models', _main_7);
}
