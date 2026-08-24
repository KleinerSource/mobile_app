import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PlaybackEngineKind {
  libmpv('libmpv', 'libmpv'),
  avPlayer('avplayer', 'AVPlayer');

  const PlaybackEngineKind(this.value, this.label);

  final String value;
  final String label;
}

abstract final class PlayerEnginePreference {
  static const storageKey = 'player.ios_engine';

  static PlaybackEngineKind fromValue(String? value) {
    return PlaybackEngineKind.values.firstWhere(
      (item) => item.value == value?.trim().toLowerCase(),
      orElse: () => PlaybackEngineKind.libmpv,
    );
  }
}

enum PlaybackLifecycle { idle, opening, ready, completed, stopped, failed }

@immutable
class PlaybackEngineCapabilities {
  const PlaybackEngineCapabilities({
    required this.pictureInPicture,
    required this.framePreview,
    required this.audioTracks,
    required this.textSubtitles,
    required this.bitmapSubtitles,
    required this.customBuffering,
    this.pictureInPictureRequiresNativeSource = false,
    this.pictureInPictureUsesSeparatePlayer = false,
  });

  const PlaybackEngineCapabilities.libmpv({
    this.pictureInPictureRequiresNativeSource = false,
    this.pictureInPictureUsesSeparatePlayer = false,
  }) : pictureInPicture = true,
       framePreview = true,
       audioTracks = true,
       textSubtitles = true,
       bitmapSubtitles = true,
       customBuffering = true;

  const PlaybackEngineCapabilities.avPlayer()
    : pictureInPicture = true,
      framePreview = true,
      audioTracks = true,
      textSubtitles = true,
      bitmapSubtitles = false,
      customBuffering = false,
      pictureInPictureRequiresNativeSource = false,
      pictureInPictureUsesSeparatePlayer = false;

  final bool pictureInPicture;
  final bool framePreview;
  final bool audioTracks;
  final bool textSubtitles;
  final bool bitmapSubtitles;
  final bool customBuffering;
  final bool pictureInPictureRequiresNativeSource;
  final bool pictureInPictureUsesSeparatePlayer;
}

@immutable
class PlaybackAudioTrackState {
  const PlaybackAudioTrackState({
    required this.id,
    required this.title,
    required this.language,
    required this.isSelected,
  });

  final String id;
  final String title;
  final String language;
  final bool isSelected;
}

@immutable
class PlaybackViewState {
  const PlaybackViewState({
    required this.engineKind,
    this.lifecycle = PlaybackLifecycle.idle,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.rate = 1,
    this.videoSize = Size.zero,
    this.subtitleText = const <String>[],
    this.audioTracks = const <PlaybackAudioTrackState>[],
    this.selectedAudioTrackId,
    this.selectedSubtitleTrackId,
    this.firstFrameRendered = false,
    this.inPictureInPicture = false,
    this.error,
  });

  final PlaybackEngineKind engineKind;
  final PlaybackLifecycle lifecycle;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final double rate;
  final Size videoSize;
  final List<String> subtitleText;
  final List<PlaybackAudioTrackState> audioTracks;
  final String? selectedAudioTrackId;
  final String? selectedSubtitleTrackId;
  final bool firstFrameRendered;
  final bool inPictureInPicture;
  final String? error;

  bool get mainMediaLoaded =>
      lifecycle == PlaybackLifecycle.ready ||
      duration > Duration.zero ||
      videoSize != Size.zero ||
      audioTracks.isNotEmpty;

  PlaybackViewState copyWith({
    PlaybackEngineKind? engineKind,
    PlaybackLifecycle? lifecycle,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? rate,
    Size? videoSize,
    List<String>? subtitleText,
    List<PlaybackAudioTrackState>? audioTracks,
    String? selectedAudioTrackId,
    bool clearSelectedAudioTrackId = false,
    String? selectedSubtitleTrackId,
    bool clearSelectedSubtitleTrackId = false,
    bool? firstFrameRendered,
    bool? inPictureInPicture,
    String? error,
    bool clearError = false,
  }) {
    return PlaybackViewState(
      engineKind: engineKind ?? this.engineKind,
      lifecycle: lifecycle ?? this.lifecycle,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      rate: rate ?? this.rate,
      videoSize: videoSize ?? this.videoSize,
      subtitleText: subtitleText ?? this.subtitleText,
      audioTracks: audioTracks ?? this.audioTracks,
      selectedAudioTrackId: clearSelectedAudioTrackId
          ? null
          : selectedAudioTrackId ?? this.selectedAudioTrackId,
      selectedSubtitleTrackId: clearSelectedSubtitleTrackId
          ? null
          : selectedSubtitleTrackId ?? this.selectedSubtitleTrackId,
      firstFrameRendered: firstFrameRendered ?? this.firstFrameRendered,
      inPictureInPicture: inPictureInPicture ?? this.inPictureInPicture,
      error: clearError ? null : error ?? this.error,
    );
  }
}

@immutable
class PlaybackOpenRequest {
  const PlaybackOpenRequest({
    required this.url,
    this.startAt,
    this.headers,
    this.play = true,
  });

  final String url;
  final Duration? startAt;
  final Map<String, String>? headers;
  final bool play;
}

@immutable
class PlaybackPictureInPictureRequest {
  const PlaybackPictureInPictureRequest({
    required this.url,
    required this.position,
    required this.autoplay,
    this.headers,
    this.onStopped,
  });

  final String url;
  final Map<String, String>? headers;
  final Duration position;
  final bool autoplay;
  final Future<void> Function(Duration position)? onStopped;
}

abstract interface class PlaybackEngine {
  PlaybackEngineKind get kind;
  PlaybackEngineCapabilities get capabilities;
  ValueListenable<PlaybackViewState> get state;

  Future<void> open(PlaybackOpenRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> configure({bool? hardwareAcceleration, int? preloadBytes});
  Future<void> setAudioTrackById(String id);
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  });
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  });
  Future<void> clearSubtitle();
  Future<void> setSubtitleDelay(Duration delay);
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  });
  Future<void> clearFramePreview();
  Future<bool> enterPictureInPicture(PlaybackPictureInPictureRequest request);
  Future<void> stopPictureInPicture();
  Future<void> stop();
  Future<void> dispose();

  Widget buildSurface({BoxFit fit = BoxFit.contain});
}
