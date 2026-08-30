import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:omm/features/player/playback_engine.dart';

class FakePlaybackEngine implements PlaybackEngine {
  FakePlaybackEngine(
    this.kind, {
    this.failOnOpen = false,
    this.pauseOnSeek = false,
    PlaybackViewState? initialState,
  }) : notifier = ValueNotifier(
         initialState ?? PlaybackViewState(engineKind: kind),
       );

  @override
  final PlaybackEngineKind kind;
  final bool failOnOpen;
  final bool pauseOnSeek;
  final ValueNotifier<PlaybackViewState> notifier;
  final List<String> commands = [];
  int openCount = 0;
  PlaybackOpenRequest? lastOpenRequest;

  @override
  PlaybackEngineCapabilities get capabilities => switch (kind) {
    PlaybackEngineKind.ksPlayer => const PlaybackEngineCapabilities.ksPlayer(),
    PlaybackEngineKind.libmpv => const PlaybackEngineCapabilities.libmpv(),
    PlaybackEngineKind.audio => const PlaybackEngineCapabilities(
      pictureInPicture: false,
      framePreview: false,
      audioTracks: false,
      textSubtitles: false,
      bitmapSubtitles: false,
      customBuffering: false,
    ),
  };

  @override
  ValueListenable<PlaybackViewState> get state => notifier;

  void _update(PlaybackViewState Function(PlaybackViewState) update) {
    notifier.value = update(notifier.value);
  }

  @override
  Future<void> open(PlaybackOpenRequest request) async {
    commands.add('open');
    openCount++;
    lastOpenRequest = request;
    if (failOnOpen) throw StateError('open failed');
    _update(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.ready,
        playing: request.play,
        position: request.startAt ?? Duration.zero,
        duration: const Duration(minutes: 10),
        buffered: const Duration(minutes: 2),
        firstFrameRendered: true,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> play() async {
    commands.add('play');
    _update((state) => state.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    _update((state) => state.copyWith(playing: false));
  }

  @override
  Future<void> playOrPause() => notifier.value.playing ? pause() : play();

  @override
  Future<void> skipToPrevious() async => commands.add('previous');

  @override
  Future<void> skipToNext() async => commands.add('next');

  @override
  Future<void> setShuffleMode(bool enabled) async =>
      commands.add('shuffle:$enabled');

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) async =>
      commands.add('repeat:${mode.name}');

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek');
    _update(
      (state) => state.copyWith(
        position: position,
        playing: pauseOnSeek ? false : state.playing,
      ),
    );
  }

  @override
  Future<void> setRate(double rate) async {
    commands.add('rate');
    _update((state) => state.copyWith(rate: rate));
  }

  @override
  Future<void> configure({
    bool? hardwareAcceleration,
    int? preloadBytes,
  }) async {
    commands.add('configure');
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    commands.add('audio:$id');
    _update((state) => state.copyWith(selectedAudioTrackId: id));
  }

  @override
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  }) async {
    commands.add('subtitle:$id');
    _update((state) => state.copyWith(selectedSubtitleTrackId: id));
  }

  @override
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  }) async {
    commands.add('subtitle-data');
    _update((state) => state.copyWith(subtitleText: [content]));
  }

  @override
  Future<void> clearSubtitle() async {
    commands.add('subtitle-clear');
    _update(
      (state) => state.copyWith(
        subtitleText: const [],
        clearSelectedSubtitleTrackId: true,
      ),
    );
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    commands.add('subtitle-delay');
  }

  @override
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  }) async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> clearFramePreview() async {
    commands.add('preview-clear');
  }

  @override
  Future<bool> enterPictureInPicture(
    PlaybackPictureInPictureRequest request,
  ) async {
    commands.add('pip');
    _update((state) => state.copyWith(inPictureInPicture: true));
    return true;
  }

  @override
  Future<void> stopPictureInPicture() async {
    commands.add('pip-stop');
    _update((state) => state.copyWith(inPictureInPicture: false));
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    _update(
      (state) =>
          state.copyWith(lifecycle: PlaybackLifecycle.stopped, playing: false),
    );
  }

  @override
  Widget buildSurface({BoxFit fit = BoxFit.contain}) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> dispose() async {
    commands.add('dispose');
    notifier.dispose();
  }
}
