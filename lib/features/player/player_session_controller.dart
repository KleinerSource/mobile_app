import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/playback.dart' as playback_models;
import 'engine_playback_route.dart';
import 'playback_engine.dart';

typedef PlaybackEngineFactory = PlaybackEngine Function();

/// 播放页面与具体内核之间唯一的会话边界。
///
/// 页面只读取统一状态并发送统一命令；内核失败切换、状态恢复、旧事件隔离
/// 都在此处完成。
class PlayerSessionController implements ValueListenable<PlaybackViewState> {
  PlayerSessionController({
    required PlaybackEngine engine,
    PlaybackEngineFactory? libmpvFallbackFactory,
    this.onFallback,
  }) : _engine = engine,
       _libmpvFallbackFactory = libmpvFallbackFactory,
       _state = ValueNotifier(engine.state.value) {
    _bindEngine();
  }

  PlaybackEngine _engine;
  final PlaybackEngineFactory? _libmpvFallbackFactory;
  final ValueChanged<String>? onFallback;
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

  PlaybackOpenRequest? _lastOpenRequest;
  int _generation = 0;
  bool _fallbackAttempted = false;
  bool _fallbackInProgress = false;
  Future<void>? _fallbackFuture;
  bool _disposed = false;
  String? _selectedAudioTrackId;
  String? _selectedSubtitleTrackId;

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
  bool get mainMediaLoaded => value.mainMediaLoaded;
  bool get usesBackendSubtitleSelection =>
      _engine.kind == PlaybackEngineKind.avPlayer;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get completedStream => _completedController.stream;
  Stream<String> get errorStream => _errorController.stream;

  EnginePlaybackRoute playbackRoute({
    required String quality,
    required playback_models.PlaybackDecision decision,
  }) {
    return playbackRouteForEngine(
      engineKind: _engine.kind,
      quality: quality,
      decision: decision,
    );
  }

  playback_models.PlaybackClientCaps clientCaps({
    required String quality,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) {
    final os = kIsWeb
        ? 'flutter-web'
        : defaultTargetPlatform.name.toLowerCase();
    return _engine.kind == PlaybackEngineKind.avPlayer
        ? playback_models.PlaybackClientCaps.avPlayer(
            qualityPreset: quality,
            userAgent: 'md_center/$os',
            audioStreamIndex: audioStreamIndex,
            subtitleTrackId: subtitleTrackId,
          )
        : playback_models.PlaybackClientCaps.mediaKit(
            qualityPreset: quality,
            userAgent: 'md_center/$os',
            audioStreamIndex: audioStreamIndex,
            subtitleTrackId: subtitleTrackId,
          );
  }

  bool shouldReloadForSubtitle(
    playback_models.SubtitleTrack? track, {
    required bool hasBackendSelection,
  }) {
    if (_engine.kind != PlaybackEngineKind.avPlayer) return false;
    return track == null
        ? hasBackendSelection
        : subtitleRequiresBackendDecision(_engine.kind, track);
  }

  Future<bool> trySelectAudioTrack(
    playback_models.AudioTrack track,
    playback_models.PlaybackDecision? decision,
  ) async {
    if (_engine.kind != PlaybackEngineKind.avPlayer) {
      await setAudioTrackById(track.index.toString());
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
      _completedController.add(true);
    }
    final error = next.error;
    if (error != null && error.isNotEmpty && error != previous.error) {
      if (_canFallback) {
        unawaited(_fallbackToLibmpv(error));
      } else {
        _errorController.add(error);
      }
    }
  }

  bool get _fallbackAvailable =>
      !_fallbackAttempted &&
      !_fallbackInProgress &&
      _engine.kind == PlaybackEngineKind.avPlayer &&
      _libmpvFallbackFactory != null;

  bool get _canFallback => _fallbackAvailable && _lastOpenRequest != null;

  Future<void> open(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
    bool play = true,
  }) async {
    final request = PlaybackOpenRequest(
      url: url,
      startAt: startAt,
      headers: headers,
      play: play,
    );
    _lastOpenRequest = request;
    final generation = ++_generation;
    try {
      await _engine.open(request);
    } catch (error) {
      if (generation != _generation || _disposed) return;
      final activeFallback = _fallbackFuture;
      if (activeFallback != null) {
        await activeFallback;
        return;
      }
      if (_canFallback) {
        await _fallbackToLibmpv(error.toString());
        return;
      }
      rethrow;
    }
  }

  Future<void> _fallbackToLibmpv(String reason) async {
    final active = _fallbackFuture;
    if (active != null) return active;
    if (!_canFallback) return;
    final future = _performFallbackToLibmpv(reason);
    _fallbackFuture = future;
    return future;
  }

  /// AVPlayer 播放决策在首次 [open] 前失败时，切换到 libmpv 供调用方
  /// 使用 libmpv capabilities 重新请求播放决策。
  Future<bool> fallbackToLibmpvForReload(String reason) async {
    final active = _fallbackFuture;
    if (active != null) {
      await active;
      return _engine.kind == PlaybackEngineKind.libmpv;
    }
    if (!_fallbackAvailable) return false;

    _fallbackAttempted = true;
    _fallbackInProgress = true;
    ++_generation;
    final oldEngine = _engine;
    try {
      final fallback = _libmpvFallbackFactory!();
      _unbindEngine();
      _engine = fallback;
      _lastOpenRequest = null;
      _bindEngine();
      _surfaceRevision.value++;
      try {
        await oldEngine.dispose();
      } catch (_) {}
      onFallback?.call('AVPlayer 播放失败，已切换至 libmpv');
      return true;
    } catch (error) {
      _errorController.add(
        error.toString().isEmpty ? reason : error.toString(),
      );
      return false;
    } finally {
      _fallbackInProgress = false;
    }
  }

  Future<void> _performFallbackToLibmpv(String reason) async {
    _fallbackAttempted = true;
    _fallbackInProgress = true;
    final generation = ++_generation;
    final oldEngine = _engine;
    final snapshot = oldEngine.state.value;
    final request = _lastOpenRequest!;
    try {
      try {
        await oldEngine.pause();
      } catch (_) {}
      final fallback = _libmpvFallbackFactory!();
      _unbindEngine();
      _engine = fallback;
      _bindEngine();
      _surfaceRevision.value++;
      await fallback.open(
        PlaybackOpenRequest(
          url: request.url,
          headers: request.headers,
          startAt: snapshot.position > Duration.zero
              ? snapshot.position
              : request.startAt,
          play: snapshot.playing,
        ),
      );
      await _waitForFirstFrame(fallback, generation);
      if (_disposed || generation != _generation) {
        await fallback.dispose();
        return;
      }
      if (snapshot.rate != 1) await fallback.setRate(snapshot.rate);
      final audioId = _selectedAudioTrackId;
      if (audioId != null) {
        try {
          await fallback.setAudioTrackById(audioId);
        } catch (_) {}
      }
      final subtitleId = _selectedSubtitleTrackId;
      if (subtitleId != null) {
        try {
          await fallback.setSubtitleTrackById(subtitleId);
        } catch (_) {}
      }
      await oldEngine.dispose();
      onFallback?.call('AVPlayer 播放失败，已切换至 libmpv');
    } catch (error) {
      _errorController.add(
        error.toString().isEmpty ? reason : error.toString(),
      );
    } finally {
      _fallbackInProgress = false;
    }
  }

  Future<void> _waitForFirstFrame(PlaybackEngine engine, int generation) async {
    if (engine.state.value.firstFrameRendered) return;
    final completer = Completer<void>();
    void listener() {
      if (engine.state.value.firstFrameRendered && !completer.isCompleted) {
        completer.complete();
      }
    }

    engine.state.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // 某些 libmpv 平台不回报首帧事件，保持已有超时降级行为。
    } finally {
      engine.state.removeListener(listener);
    }
    if (_disposed || generation != _generation) return;
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

  Future<void> play() => _engine.play();
  Future<void> pause() => _engine.pause();
  Future<void> playOrPause() => _engine.playOrPause();
  Future<void> seek(Duration position) => _engine.seek(position);
  Future<void> setRate(double rate) => _engine.setRate(rate);

  Future<void> setAudioTrackById(String id) async {
    await _engine.setAudioTrackById(id);
    _selectedAudioTrackId = id;
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
    _selectedSubtitleTrackId = id;
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
    _selectedSubtitleTrackId = null;
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
    ++_generation;
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
    ++_generation;
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
