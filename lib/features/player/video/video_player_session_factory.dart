import 'package:flutter/foundation.dart';

import 'ks_player_playback_engine.dart';
import '../common/playback_engine.dart';
import 'player_controller_host.dart';
import '../common/player_session_controller.dart';

PlayerSessionController createVideoPlayerSession({
  PlaybackEngineKind? engineKind,
  PlaybackEngineKind iosEnginePreference = PlaybackEngineKind.libmpv,
}) {
  final selectedEngine = resolvePlaybackEngineKind(
    engineKind: engineKind,
    iosEnginePreference: iosEnginePreference,
  );
  return PlayerSessionController(
    engine: switch (selectedEngine) {
      PlaybackEngineKind.libmpv => MediaKitPlaybackEngine(),
      PlaybackEngineKind.ksPlayer => KsPlayerPlaybackEngine(),
      PlaybackEngineKind.audio => MediaKitPlaybackEngine(),
    },
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
  return const [PlaybackEngineKind.libmpv, PlaybackEngineKind.ksPlayer];
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
          selected == PlaybackEngineKind.ksPlayer
      ? selected
      : PlaybackEngineKind.libmpv;
}
