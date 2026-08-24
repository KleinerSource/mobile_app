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
  for (final mode in ['direct_play', 'remux', 'direct_stream', 'transcode']) {
    test('AVPlayer $mode 始终采纳后端 stream_url', () {
      final route = playbackRouteForEngine(
        engineKind: PlaybackEngineKind.avPlayer,
        quality: 'original',
        decision: _decision(mode),
      );

      expect(route.useBackendStream, isTrue);
      expect(route.useServerRoute, mode != 'direct_play');
      expect(route.usesManagedTranscode, mode == 'transcode');
    });
  }

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

  test('AVPlayer PGS 与 burn_in 字幕要求后端重决策', () {
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
      subtitleRequiresBackendDecision(PlaybackEngineKind.avPlayer, pgs),
      isTrue,
    );
    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.avPlayer, burnIn),
      isTrue,
    );
    expect(
      subtitleRequiresBackendDecision(PlaybackEngineKind.libmpv, pgs),
      isFalse,
    );
  });
}
