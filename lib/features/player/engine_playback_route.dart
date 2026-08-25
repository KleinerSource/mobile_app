import 'package:flutter/foundation.dart';

import '../../core/models/playback.dart' as playback_models;
import 'playback_decision.dart';
import 'playback_engine.dart';

@immutable
class EnginePlaybackRoute {
  const EnginePlaybackRoute({
    required this.useBackendStream,
    required this.useServerRoute,
    required this.usesManagedTranscode,
  });

  final bool useBackendStream;
  final bool useServerRoute;
  final bool usesManagedTranscode;
}

EnginePlaybackRoute playbackRouteForEngine({
  required PlaybackEngineKind engineKind,
  required String quality,
  required playback_models.PlaybackDecision decision,
}) {
  final useServerRoute = playbackRouteForQuality(quality) == PlaybackRoute.hls;
  return EnginePlaybackRoute(
    // 服务端决策地址可能包含 direct-stream 模式、音轨或字幕参数。
    // 只有它确实是 HLS 时才使用；低于源分辨率的固定档位仍用兜底 HLS
    // 强制执行用户选择的质量上限。
    useBackendStream:
        engineKind == PlaybackEngineKind.ksPlayer &&
        useServerRoute &&
        _decisionHasHlsUrl(decision),
    useServerRoute: useServerRoute,
    usesManagedTranscode: useServerRoute,
  );
}

bool _decisionHasHlsUrl(playback_models.PlaybackDecision decision) {
  final url = decision.streamUrl.trim().toLowerCase();
  final mime = decision.mimeType.trim().toLowerCase();
  return url.contains('.m3u8') || mime.contains('mpegurl');
}

bool subtitleRequiresBackendDecision(
  PlaybackEngineKind engineKind,
  playback_models.SubtitleTrack track,
) {
  if (engineKind != PlaybackEngineKind.ksPlayer) {
    return false;
  }
  final renderMode = track.renderMode.trim().toLowerCase();
  return track.isPgs ||
      renderMode == 'burn_in' ||
      renderMode == 'burn-in' ||
      renderMode == 'burnin';
}
