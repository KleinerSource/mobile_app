import 'package:flutter/foundation.dart';

import '../../core/models/playback.dart' as playback_models;
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
  bool forceServerRoute = false,
}) {
  final normalized = quality.trim().toLowerCase();
  final useDecisionStream = forceServerRoute || normalized != 'auto';
  final useServerRoute = useDecisionStream && decisionHasHlsUrl(decision);
  return EnginePlaybackRoute(
    useBackendStream: useDecisionStream,
    useServerRoute: useServerRoute,
    usesManagedTranscode: useServerRoute,
  );
}

bool decisionHasHlsUrl(playback_models.PlaybackDecision decision) {
  final url = decision.streamUrl.trim().toLowerCase();
  final mime = decision.mimeType.trim().toLowerCase();
  return url.contains('.m3u8') || mime.contains('mpegurl');
}

@immutable
class ServerFallbackPlan {
  const ServerFallbackPlan({
    required this.reuseDecision,
    required this.forceVideoTranscode,
  });

  final bool reuseDecision;
  final bool forceVideoTranscode;
}

ServerFallbackPlan? serverFallbackPlanFor({
  required String quality,
  required bool alreadyAttempted,
  required bool usingHls,
  required playback_models.PlaybackDecision decision,
}) {
  final normalized = quality.trim().toLowerCase();
  if (alreadyAttempted ||
      usingHls ||
      (normalized != 'auto' && normalized != 'original')) {
    return null;
  }
  final reuseDecision = decisionHasHlsUrl(decision);
  return ServerFallbackPlan(
    reuseDecision: reuseDecision,
    forceVideoTranscode: !reuseDecision,
  );
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
