import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/playback.dart' as playback_models;
import 'engine_playback_route.dart';
import 'playback_engine.dart';

/// 播放页面与具体内核之间唯一的会话边界。
///
/// 页面只读取统一状态并发送统一命令，具体内核的状态事件都在此处归一化。
class PlayerSessionController implements ValueListenable<PlaybackViewState> {
  PlayerSessionController({required PlaybackEngine engine})
    : _engine = engine,
      _state = ValueNotifier(engine.state.value) {
    _playbackIntent = engine.state.value.playing;
    _bindEngine();
  }

  final PlaybackEngine _engine;
  final ValueNotifier<PlaybackViewState> _state;
  final ValueNotifier<int> _surfaceRevision = ValueNotifier(0);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  bool _playbackIntent = false;
  bool _disposed = false;

  @override
  PlaybackViewState get value => _state.value;

  @override
  void addListener(VoidCallback listener) => _state.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _state.removeListener(listener);

  PlaybackEngineKind get kind => _engine.kind;
  PlaybackEngineCapabilities get capabilities => _engine.capabilities;
  Duration get position => value.position;
  Duration get duration => value.duration;
  bool get playing => value.playing;
  bool get playbackIntent => _playbackIntent;
  bool get mainMediaLoaded => value.mainMediaLoaded;
  bool get usesBackendSubtitleSelection =>
      _engine.kind == PlaybackEngineKind.ksPlayer;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get completedStream => _completedController.stream;
  Stream<String> get errorStream => _errorController.stream;
  EnginePlaybackRoute playbackRoute({
    required String quality,
    required playback_models.PlaybackDecision decision,
    bool forceServerRoute = false,
  }) {
    return playbackRouteForQuality(
      quality: quality,
      decision: decision,
      forceServerRoute: forceServerRoute,
    );
  }

  playback_models.PlaybackClientCaps clientCaps({
    required String quality,
    bool forceVideoTranscode = false,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) {
    final os = kIsWeb
        ? 'flutter-web'
        : defaultTargetPlatform.name.toLowerCase();
    switch (_engine.kind) {
      case PlaybackEngineKind.ksPlayer:
        return playback_models.PlaybackClientCaps.ksPlayer(
          qualityPreset: quality,
          forceVideoTranscode: forceVideoTranscode,
          userAgent: 'omm/$os',
          audioStreamIndex: audioStreamIndex,
          subtitleTrackId: subtitleTrackId,
        );
      case PlaybackEngineKind.libmpv:
        return playback_models.PlaybackClientCaps.mediaKit(
          qualityPreset: quality,
          forceVideoTranscode: forceVideoTranscode,
          userAgent: 'omm/$os',
          audioStreamIndex: audioStreamIndex,
          subtitleTrackId: subtitleTrackId,
        );
    }
  }

  bool shouldReloadForSubtitle(
    playback_models.SubtitleTrack? track, {
    required bool hasBackendSelection,
  }) {
    if (_engine.kind != PlaybackEngineKind.ksPlayer) {
      return false;
    }
    return track == null
        ? hasBackendSelection
        : subtitleRequiresBackendDecision(_engine.kind, track);
  }

  Future<bool> trySelectAudioTrack(
    playback_models.AudioTrack track,
    playback_models.PlaybackDecision? decision,
  ) async {
    if (_engine.kind == PlaybackEngineKind.libmpv) {
      await setAudioTrackById(track.index.toString());
      return true;
    }
    if (decision != null && decision.audioTracks.length <= 1) {
      // 单音轨没有可切换目标，原生播放器已自动选中该轨；不要为了等待
      // 不存在的原生音轨选择组阻塞起播。
      return true;
    }

    var nativeTracks = value.audioTracks;
    if (nativeTracks.isEmpty) {
      try {
        await positionStream
            .firstWhere((_) => value.audioTracks.isNotEmpty)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      nativeTracks = value.audioTracks;
    }
    PlaybackAudioTrackState? match;
    final language = track.language.trim().toLowerCase();
    final title = track.title.trim().toLowerCase();
    for (final native in nativeTracks) {
      final languageMatches =
          language.isNotEmpty &&
          native.language.trim().toLowerCase() == language;
      final titleMatches =
          title.isNotEmpty && native.title.trim().toLowerCase() == title;
      if (languageMatches && (title.isEmpty || titleMatches)) {
        match = native;
        break;
      }
      if (match == null && titleMatches) match = native;
    }
    if (match == null && decision != null) {
      final ordinal = decision.audioTracks.indexOf(track);
      if (ordinal >= 0 && ordinal < nativeTracks.length) {
        match = nativeTracks[ordinal];
      }
    }
    if (match == null) return false;
    await setAudioTrackById(match.id);
    return true;
  }

  void _bindEngine() {
    _engine.state.addListener(_handleEngineState);
    _handleEngineState();
  }

  void _unbindEngine() {
    _engine.state.removeListener(_handleEngineState);
  }

  void _handleEngineState() {
    if (_disposed) return;
    final previous = _state.value;
    final next = _engine.state.value;
    _state.value = next;
    if (next.position != previous.position) {
      _positionController.add(next.position);
    }
    if (next.duration != previous.duration) {
      _durationController.add(next.duration);
    }
    if (next.lifecycle == PlaybackLifecycle.completed &&
        previous.lifecycle != PlaybackLifecycle.completed) {
      _playbackIntent = false;
      _completedController.add(true);
    }
    final error = next.error;
    if (error != null && error.isNotEmpty && error != previous.error) {
      _errorController.add(error);
    }
  }

  Future<void> open(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
    bool play = true,
    String? formatHint,
    PlaybackMediaInfo? mediaInfo,
  }) async {
    _playbackIntent = play;
    final request = PlaybackOpenRequest(
      url: url,
      startAt: startAt,
      headers: headers,
      play: play,
      formatHint: formatHint,
      mediaInfo: mediaInfo,
    );
    await _engine.open(request);
  }

  Future<void> configure({
    bool? hardwareAcceleration,
    int? preloadBytes,
  }) async {
    await _engine.configure(
      hardwareAcceleration: hardwareAcceleration,
      preloadBytes: preloadBytes,
    );
    _surfaceRevision.value++;
  }

  Future<void> play() {
    _playbackIntent = true;
    return _engine.play();
  }

  Future<void> pause() {
    _playbackIntent = false;
    return _engine.pause();
  }

  Future<void> playOrPause() => _playbackIntent ? pause() : play();

  /// 定位期间部分内核会先进入 buffering，并清掉底层的播放状态。
  ///
  /// 会话层保存的是用户的播放意图，因此定位完成后必须显式恢复播放；
  /// 暂停状态的定位仍保持暂停，不改变用户操作语义。
  Future<void> seek(Duration position) async {
    final shouldPlay = _playbackIntent;
    await _engine.seek(position);
    if (shouldPlay && !_disposed) {
      await _engine.play();
    }
  }

  Future<void> setRate(double rate) => _engine.setRate(rate);

  Future<void> setAudioTrackById(String id) async {
    await _engine.setAudioTrackById(id);
  }

  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  }) async {
    await _engine.setSubtitleTrackById(
      id,
      fallbackIndex: fallbackIndex,
      nativeRendering: nativeRendering,
    );
  }

  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  }) async {
    await _engine.setSubtitleData(content, title: title, language: language);
  }

  Future<void> clearSubtitle() async {
    await _engine.clearSubtitle();
  }

  Future<void> setSubtitleDelay(Duration delay) =>
      _engine.setSubtitleDelay(delay);

  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  }) {
    return _engine.captureFrame(
      position,
      sourceUrl: sourceUrl,
      headers: headers,
    );
  }

  Future<void> clearFramePreview() => _engine.clearFramePreview();

  Future<bool> enterPictureInPicture(PlaybackPictureInPictureRequest request) =>
      _engine.enterPictureInPicture(request);

  Future<void> stopPictureInPicture() => _engine.stopPictureInPicture();

  Future<void> stop() async {
    _playbackIntent = false;
    await _engine.stop();
  }

  Widget buildSurface({BoxFit fit = BoxFit.contain}) {
    return ValueListenableBuilder<int>(
      valueListenable: _surfaceRevision,
      builder: (_, __, ___) => _engine.buildSurface(fit: fit),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _unbindEngine();
    await _engine.dispose();
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
    await _errorController.close();
    _surfaceRevision.dispose();
    _state.dispose();
  }
}
