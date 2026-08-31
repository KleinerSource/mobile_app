import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/playback.dart' as playback_models;
import 'engine_playback_route.dart';
import 'playback_engine.dart';
import 'player_queue.dart';

/// 播放页面与具体内核之间唯一的会话边界。
///
/// 页面只读取统一状态并发送统一命令，具体内核的状态事件都在此处归一化。
class PlayerSessionController implements ValueListenable<PlaybackViewState> {
  static const _seekPositionToleranceMs = 250;

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
  int _seekGeneration = 0;
  Duration? _pendingSeekTarget;
  int _pendingSeekDirection = 0;
  Duration? _seekGuardTarget;
  int _seekGuardDirection = 0;
  bool _seekGuardActive = false;

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
  bool get supportsScratch => _engine is ScratchPlaybackEngine;
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
      case PlaybackEngineKind.audio:
        return playback_models.PlaybackClientCaps.mediaKit(
          qualityPreset: quality,
          forceVideoTranscode: false,
          userAgent: 'omm/$os',
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
    final engineState = _engine.state.value;
    if (engineState.lifecycle == PlaybackLifecycle.opening ||
        engineState.lifecycle == PlaybackLifecycle.stopped ||
        engineState.lifecycle == PlaybackLifecycle.failed ||
        engineState.lifecycle == PlaybackLifecycle.completed) {
      _clearSeekPositionProtection();
    }

    var next = engineState;
    final pendingTarget = _pendingSeekTarget;
    if (pendingTarget != null) {
      if (_seekPositionConfirmsTarget(
        engineState.position,
        target: pendingTarget,
      )) {
        _pendingSeekTarget = null;
        _armSeekGuard(pendingTarget, _pendingSeekDirection);
      } else {
        // seek Future 返回前，部分内核仍会发出旧位置；继续向页面提供
        // 用户刚选择的目标，避免歌词和进度条回退到旧时间。
        next = engineState.copyWith(position: pendingTarget);
      }
    } else if (_seekGuardActive &&
        _seekPositionIsStale(
          engineState.position,
          target: _seekGuardTarget!,
          direction: _seekGuardDirection,
        )) {
      // 定位完成后仍可能有一个迟到的旧位置事件，直到出现目标方向的
      // 正常位置推进前，保持目标时间不被覆盖。
      next = engineState.copyWith(position: _seekGuardTarget);
    } else if (_seekGuardActive) {
      _clearSeekGuard();
    }

    _publishState(next);
  }

  void _publishState(PlaybackViewState next) {
    final previous = _state.value;
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

  void _clearSeekGuard() {
    _seekGuardTarget = null;
    _seekGuardDirection = 0;
    _seekGuardActive = false;
  }

  void _clearSeekPositionProtection() {
    _pendingSeekTarget = null;
    _pendingSeekDirection = 0;
    _clearSeekGuard();
  }

  void _invalidateSeek() {
    _seekGeneration++;
    _clearSeekPositionProtection();
  }

  void _armSeekGuard(Duration target, int direction) {
    if (direction == 0) {
      _clearSeekGuard();
      return;
    }
    _seekGuardTarget = target;
    _seekGuardDirection = direction;
    _seekGuardActive = true;
  }

  bool _seekPositionConfirmsTarget(
    Duration position, {
    required Duration target,
  }) {
    final deltaMs = position.inMilliseconds - target.inMilliseconds;
    return deltaMs.abs() <= _seekPositionToleranceMs;
  }

  bool _seekPositionIsStale(
    Duration position, {
    required Duration target,
    required int direction,
  }) {
    final deltaMs = position.inMilliseconds - target.inMilliseconds;
    if (direction > 0) {
      return deltaMs < -_seekPositionToleranceMs;
    }
    if (direction < 0) {
      return deltaMs > _seekPositionToleranceMs;
    }
    return false;
  }

  Future<void> open(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
    bool play = true,
    String? formatHint,
    PlaybackMediaInfo? mediaInfo,
    bool preferFfmpegForHls = false,
    List<PlayerQueueItem> queue = const <PlayerQueueItem>[],
    int queueIndex = 0,
    Future<void> Function()? onQueueDispose,
  }) async {
    _invalidateSeek();
    _playbackIntent = play;
    final request = PlaybackOpenRequest(
      url: url,
      startAt: startAt,
      headers: headers,
      play: play,
      formatHint: formatHint,
      mediaInfo: mediaInfo,
      preferFfmpegForHls: preferFfmpegForHls,
      queue: queue,
      queueIndex: queueIndex,
      onQueueDispose: onQueueDispose,
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

  Future<void> skipToPrevious() {
    _invalidateSeek();
    return _engine.skipToPrevious();
  }

  Future<void> skipToNext() {
    _invalidateSeek();
    return _engine.skipToNext();
  }

  Future<void> setShuffleMode(bool enabled) => _engine.setShuffleMode(enabled);

  Future<void> setRepeatMode(PlaybackRepeatMode mode) =>
      _engine.setRepeatMode(mode);

  /// 定位期间部分内核会先进入 buffering，并清掉底层的播放状态。
  ///
  /// 会话层保存的是用户的播放意图，因此定位完成后必须显式恢复播放；
  /// 暂停状态的定位仍保持暂停，不改变用户操作语义。交互式搓碟可将
  /// [waitForPlaybackResume] 设为 false，避免等待整首曲目结束的播放 Future。
  Future<void> seek(
    Duration position, {
    bool waitForPlaybackResume = true,
  }) async {
    final shouldPlay = _playbackIntent;
    final generation = ++_seekGeneration;
    final origin = _state.value.position;
    _pendingSeekTarget = position;
    _pendingSeekDirection = position.compareTo(origin);
    _clearSeekGuard();
    _publishState(_state.value.copyWith(position: position));
    try {
      await _engine.seek(position);
    } catch (_) {
      if (generation == _seekGeneration && !_disposed) {
        _clearSeekPositionProtection();
        _handleEngineState();
      }
      rethrow;
    }
    if (generation != _seekGeneration || _disposed) return;
    if (shouldPlay && _playbackIntent) {
      final playFuture = _engine.play();
      if (waitForPlaybackResume) {
        await playFuture;
      } else {
        unawaited(playFuture.catchError((_) {}));
      }
    }
  }

  Future<void> setRate(double rate) => _engine.setRate(rate);

  Future<bool> startScratch(Duration position, {required bool resumePlayback}) {
    final Object engine = _engine;
    if (engine is! ScratchPlaybackEngine) return Future<bool>.value(false);
    return engine.startScratch(position, resumePlayback: resumePlayback);
  }

  Future<void> setScratchRate(double rate) {
    final Object engine = _engine;
    if (engine is! ScratchPlaybackEngine) return Future<void>.value();
    return engine.setScratchRate(rate);
  }

  Future<void> cancelScratchStart() {
    final Object engine = _engine;
    if (engine is! ScratchPlaybackEngine) return Future<void>.value();
    return engine.cancelScratchStart();
  }

  Future<Duration?> finishScratch({required bool resumePlayback}) {
    final Object engine = _engine;
    if (engine is! ScratchPlaybackEngine) {
      return Future<Duration?>.value();
    }
    return engine.finishScratch(resumePlayback: resumePlayback);
  }

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
    _invalidateSeek();
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
