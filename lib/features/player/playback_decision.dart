import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../core/models/media_info.dart';

/// 播放源类型
enum PlaybackSourceType { direct, hls }

@immutable
class PlaybackSource {
  const PlaybackSource({
    required this.url,
    required this.type,
    required this.reason,
  });

  final String url;
  final PlaybackSourceType type;

  /// 调试用: 为何选这个源
  final String reason;

  bool get isHls => type == PlaybackSourceType.hls;
}

/// 根据 MediaInfo + 平台 决定走直传 / HLS
class PlaybackDecision {
  /// [streamUrl]: 直传 `/movies/id/{id}/stream`
  /// [hlsUrl]: HLS `/movies/id/{id}/stream.m3u8`
  /// [mediaInfo]: 后端探测 (可能为 null, 此时降级直传)
  /// [forceHls]: 用户手动选了非 auto 档位
  static PlaybackSource decide({
    required String streamUrl,
    required String hlsUrl,
    MediaInfo? mediaInfo,
    bool forceHls = false,
  }) {
    if (forceHls) {
      return PlaybackSource(
        url: hlsUrl,
        type: PlaybackSourceType.hls,
        reason: 'user-selected quality',
      );
    }
    if (mediaInfo == null) {
      return PlaybackSource(
        url: streamUrl,
        type: PlaybackSourceType.direct,
        reason: 'no media info, fallback to direct',
      );
    }

    final container = (mediaInfo.container ?? '').toLowerCase();
    final codec = (mediaInfo.videoCodec ?? '').toLowerCase();
    final pixFmt = (mediaInfo.videoPixFmt ?? '').toLowerCase();

    // 10-bit / 422 等高色深 → HLS 转码
    if (pixFmt.contains('10') || pixFmt.contains('p10') ||
        pixFmt.contains('422') || pixFmt.contains('444')) {
      return PlaybackSource(
        url: hlsUrl,
        type: PlaybackSourceType.hls,
        reason: 'high bit-depth pix_fmt=$pixFmt',
      );
    }

    // 容器不在白名单 → HLS
    const okContainers = {'mp4', 'mov', 'm4v', 'mp4a'};
    if (container.isNotEmpty && !okContainers.contains(container)) {
      return PlaybackSource(
        url: hlsUrl,
        type: PlaybackSourceType.hls,
        reason: 'container=$container not in whitelist',
      );
    }

    // codec 判断 (按平台区分)
    final isIOS = !kIsWeb && Platform.isIOS;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (codec == 'h264' || codec == 'avc1' || codec == 'avc') {
      return PlaybackSource(
        url: streamUrl,
        type: PlaybackSourceType.direct,
        reason: 'h264 universal direct',
      );
    }
    if (codec == 'hevc' || codec == 'h265' || codec == 'hvc1') {
      if (isIOS) {
        return PlaybackSource(
          url: streamUrl,
          type: PlaybackSourceType.direct,
          reason: 'hevc on iOS direct',
        );
      }
      if (isAndroid) {
        // Android HEVC 硬解支持参差, 保守走 HLS
        return PlaybackSource(
          url: hlsUrl,
          type: PlaybackSourceType.hls,
          reason: 'hevc on Android → HLS for compatibility',
        );
      }
    }

    // 后端已经判定不兼容
    if (mediaInfo.browserCompatible == false) {
      return PlaybackSource(
        url: hlsUrl,
        type: PlaybackSourceType.hls,
        reason: 'backend marked browser_compatible=false',
      );
    }

    // 兜底直传
    return PlaybackSource(
      url: streamUrl,
      type: PlaybackSourceType.direct,
      reason: 'default direct',
    );
  }
}
