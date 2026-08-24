import 'package:flutter/foundation.dart';

import 'av_player_playback_engine.dart';
import 'playback_engine.dart';
import 'player_controller_host.dart';
import 'player_session_controller.dart';

PlayerSessionController createPlayerSession({
  PlaybackEngineKind? engineKind,
  PlaybackEngineKind iosEnginePreference = PlaybackEngineKind.libmpv,
  void Function(String message)? onFallback,
}) {
  final selectedEngine = resolvePlaybackEngineKind(
    engineKind: engineKind,
    iosEnginePreference: iosEnginePreference,
  );
  return PlayerSessionController(
    engine: switch (selectedEngine) {
      PlaybackEngineKind.libmpv => MediaKitPlaybackEngine(),
      PlaybackEngineKind.avPlayer => AvPlayerPlaybackEngine(),
    },
    libmpvFallbackFactory: selectedEngine == PlaybackEngineKind.avPlayer
        ? MediaKitPlaybackEngine.new
        : null,
    onFallback: onFallback,
  );
}

PlaybackEngineKind resolvePlaybackEngineKind({
  PlaybackEngineKind? engineKind,
  PlaybackEngineKind iosEnginePreference = PlaybackEngineKind.libmpv,
  bool? isWeb,
  TargetPlatform? targetPlatform,
}) {
  final web = isWeb ?? kIsWeb;
  final platform = targetPlatform ?? defaultTargetPlatform;
  if (web || platform != TargetPlatform.iOS) {
    return PlaybackEngineKind.libmpv;
  }
  return engineKind ?? iosEnginePreference;
}
