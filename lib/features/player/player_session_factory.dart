import 'package:flutter/foundation.dart';

import 'av_player_playback_engine.dart';
import 'ks_player_playback_engine.dart';
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
      PlaybackEngineKind.ksPlayer => KsPlayerPlaybackEngine(),
    },
    libmpvFallbackFactory: selectedEngine != PlaybackEngineKind.libmpv
        ? MediaKitPlaybackEngine.new
        : null,
    onFallback: onFallback,
  );
}

List<PlaybackEngineKind> availablePlaybackEngineKinds({
  bool? isWeb,
  TargetPlatform? targetPlatform,
}) {
  final web = isWeb ?? kIsWeb;
  final platform = targetPlatform ?? defaultTargetPlatform;
  if (web || platform != TargetPlatform.iOS) {
    return const [PlaybackEngineKind.libmpv];
  }
  return const [
    PlaybackEngineKind.libmpv,
    PlaybackEngineKind.avPlayer,
    PlaybackEngineKind.ksPlayer,
  ];
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
  final selected = engineKind ?? iosEnginePreference;
  return selected == PlaybackEngineKind.libmpv ||
          selected == PlaybackEngineKind.avPlayer ||
          selected == PlaybackEngineKind.ksPlayer
      ? selected
      : PlaybackEngineKind.libmpv;
}
