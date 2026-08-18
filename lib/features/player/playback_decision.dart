import 'package:flutter/foundation.dart';

import '../../core/models/media_info.dart';

/// 移动端播放链路。自动画质始终交给客户端解码，固定画质才启动服务端转码。
enum PlaybackRoute { direct, hls }

PlaybackRoute playbackRouteForQuality(String quality) {
  final normalized = quality.trim().toLowerCase();
  return normalized.isEmpty || normalized == 'original' || normalized == 'auto'
      ? PlaybackRoute.direct
      : PlaybackRoute.hls;
}

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

    // 移动端 media_kit/libmpv 默认启用系统硬解。H.264/HEVC 先交给客户端，
    // 不因编码名称或 Android 平台差异强制创建服务端转码会话。
    if (codec == 'h264' ||
        codec == 'avc1' ||
        codec == 'avc' ||
        codec == 'hevc' ||
        codec == 'h265' ||
        codec == 'hvc1') {
      return PlaybackSource(
        url: streamUrl,
        type: PlaybackSourceType.direct,
        reason: 'mobile hardware codec direct',
      );
    }

    // 10-bit / 422 等其他编码的高色深 → HLS 转码
    if (pixFmt.contains('10') ||
        pixFmt.contains('p10') ||
        pixFmt.contains('422') ||
        pixFmt.contains('444')) {
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
