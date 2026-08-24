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
  if (engineKind == PlaybackEngineKind.avPlayer) {
    return EnginePlaybackRoute(
      useBackendStream: true,
      useServerRoute: decision.mode != 'direct_play',
      usesManagedTranscode: decision.isTranscode,
    );
  }
  final useServerRoute = playbackRouteForQuality(quality) == PlaybackRoute.hls;
  return EnginePlaybackRoute(
    useBackendStream: false,
    useServerRoute: useServerRoute,
    usesManagedTranscode: useServerRoute,
  );
}

bool subtitleRequiresBackendDecision(
  PlaybackEngineKind engineKind,
  playback_models.SubtitleTrack track,
) {
  if (engineKind != PlaybackEngineKind.avPlayer &&
      engineKind != PlaybackEngineKind.ksPlayer) {
    return false;
  }
  final renderMode = track.renderMode.trim().toLowerCase();
  return track.isPgs ||
      renderMode == 'burn_in' ||
      renderMode == 'burn-in' ||
      renderMode == 'burnin';
}
