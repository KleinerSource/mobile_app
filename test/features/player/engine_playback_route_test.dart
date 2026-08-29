import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/models/playback.dart';
import 'package:omm/features/player/engine_playback_route.dart';
import 'package:omm/features/player/playback_engine.dart';

PlaybackDecision _decision({required bool hls}) => PlaybackDecision(
  mode: hls ? 'transcode' : 'direct_play',
  streamUrl: hls
      ? 'https://example.com/stream.m3u8'
      : 'https://example.com/video.mp4',
  directUrl: 'https://example.com/original.mkv',
  mimeType: hls ? 'application/vnd.apple.mpegurl' : 'video/mp4',
  hwAccel: '',
  targetVideo: '',
  targetAudio: '',
  targetHeight: 0,
  targetBitrate: 0,
  reasons: const [],
  audioTracks: const [],
  subtitleTracks: const [],
  startSec: 0,
);

void main() {
  test('自动档先使用 direct_url(与引擎无关)', () {
    final route = playbackRouteForQuality(
      quality: 'auto',
      decision: _decision(hls: true),
    );

    expect(route.useBackendStream, isFalse);
    expect(route.useServerRoute, isFalse);
    expect(route.usesManagedTranscode, isFalse);
  });

  test('原生和固定档采用服务端决策地址(与引擎无关)', () {
    final originalDirect = playbackRouteForQuality(
      quality: 'original',
      decision: _decision(hls: false),
    );
    final originalTranscode = playbackRouteForQuality(
      quality: 'original',
      decision: _decision(hls: true),
    );
    final fixed = playbackRouteForQuality(
      quality: '720p',
      decision: _decision(hls: true),
    );

    expect(originalDirect.useBackendStream, isTrue);
    expect(originalDirect.useServerRoute, isFalse);
    expect(originalDirect.usesManagedTranscode, isFalse);
    for (final route in [originalTranscode, fixed]) {
      expect(route.useBackendStream, isTrue);
      expect(route.useServerRoute, isTrue);
      expect(route.usesManagedTranscode, isTrue);
    }
  });

  test('后端 HLS 使用目标编码选择 KSPlayer 内部播放器', () {
    const decision = PlaybackDecision(
      mode: 'transcode',
      streamUrl: 'https://example.com/stream.m3u8?quality=720p',
      directUrl: 'https://example.com/original.mkv',
      mimeType: 'application/vnd.apple.mpegurl',
      container: 'matroska,webm',
      videoCodec: 'hevc',
      bitRate: 20 * 1000 * 1000,
      hwAccel: 'videotoolbox',
      targetVideo: 'h264',
      targetAudio: 'aac',
      targetHeight: 720,
      targetBitrate: 4 * 1000 * 1000,
      reasons: [],
      audioTracks: [],
      subtitleTracks: [],
      startSec: 0,
    );

    final directInfo = playbackMediaInfoForDecision(decision);
    final hlsInfo = playbackMediaInfoForDecision(
      decision,
      preferTargetVideo: true,
    );

    expect(directInfo?.videoCodec, 'hevc');
    expect(hlsInfo?.videoCodec, 'h264');
    expect(hlsInfo?.videoBitrate, 4 * 1000 * 1000);
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        decision.directUrl,
        decision.container,
        videoCodec: directInfo?.videoCodec,
      ),
      'KSMEPlayer',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        decision.streamUrl,
        null,
        videoCodec: hlsInfo?.videoCodec,
      ),
      'AVPlayer',
      reason: 'OMM 转码 HLS 交给 AVPlayer 串流',
    );
    expect(
      PlaybackMediaInfo.inferInternalPlayer(
        decision.streamUrl,
        null,
        preferFfmpegForHls: true,
      ),
      'KSMEPlayer',
      reason: '文件源显式要求 FFmpeg 时 HLS 才走 KSMEPlayer',
    );
  });

  test('服务器回退优先复用 HLS，否则要求强制视频转码重决策', () {
    final reuse = serverFallbackPlanFor(
      quality: 'auto',
      alreadyAttempted: false,
      usingHls: false,
      decision: _decision(hls: true),
    );
    final refresh = serverFallbackPlanFor(
      quality: 'original',
      alreadyAttempted: false,
      usingHls: false,
      decision: _decision(hls: false),
    );

    expect(reuse?.reuseDecision, isTrue);
    expect(reuse?.forceVideoTranscode, isFalse);
    expect(refresh?.reuseDecision, isFalse);
    expect(refresh?.forceVideoTranscode, isTrue);
  });

  test('固定档、已在 HLS 或已回退时不再自动回退', () {
    final decision = _decision(hls: true);
    expect(
      serverFallbackPlanFor(
        quality: '720p',
        alreadyAttempted: false,
        usingHls: false,
        decision: decision,
      ),
      isNull,
    );
    expect(
      serverFallbackPlanFor(
        quality: 'auto',
        alreadyAttempted: false,
        usingHls: true,
        decision: decision,
      ),
      isNull,
    );
    expect(
      serverFallbackPlanFor(
        quality: 'auto',
        alreadyAttempted: true,
        usingHls: false,
        decision: decision,
      ),
      isNull,
    );
  });

  test('KSPlayer PGS 与 burn_in 字幕要求后端重决策', () {
    const pgs = SubtitleTrack(
      id: 'pgs-1',
      index: 1,
      source: 'embedded',
      language: 'zh',
      title: 'PGS',
      codec: 'hdmv_pgs_subtitle',
      url: '',
      isDefault: false,
    );
    const burnIn = SubtitleTrack(
      id: 'dvd-2',
      index: 2,
      source: 'embedded',
      language: 'zh',
      title: 'VobSub',
      codec: 'dvd_subtitle',
      url: '',
      isDefault: false,
      renderMode: 'burn_in',
    );

    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.libmpv, pgs),
      isFalse,
    );
    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.ksPlayer, pgs),
      isTrue,
    );
    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.ksPlayer, burnIn),
      isTrue,
    );
  });
}
