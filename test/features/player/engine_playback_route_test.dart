import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/core/models/playback.dart';
import 'package:md_center/features/player/engine_playback_route.dart';
import 'package:md_center/features/player/playback_engine.dart';

PlaybackDecision _decision(String mode) => PlaybackDecision(
  mode: mode,
  streamUrl: 'https://example.com/$mode',
  mimeType: mode == 'transcode' ? 'application/vnd.apple.mpegurl' : 'video/mp4',
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
  test('libmpv 保持自动画质直传、固定画质 HLS', () {
    final decision = _decision('transcode');
    final original = playbackRouteForEngine(
      engineKind: PlaybackEngineKind.libmpv,
      quality: 'original',
      decision: decision,
    );
    final fixed = playbackRouteForEngine(
      engineKind: PlaybackEngineKind.libmpv,
      quality: '1080p',
      decision: decision,
    );

    expect(original.useBackendStream, isFalse);
    expect(original.useServerRoute, isFalse);
    expect(fixed.useBackendStream, isFalse);
    expect(fixed.useServerRoute, isTrue);
  });

  test('KSPlayer 使用宽格式客户端路线', () {
    final route = playbackRouteForEngine(
      engineKind: PlaybackEngineKind.ksPlayer,
      quality: 'original',
      decision: _decision('transcode'),
    );

    expect(route.useBackendStream, isFalse);
    expect(route.useServerRoute, isFalse);
    expect(route.usesManagedTranscode, isFalse);
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
