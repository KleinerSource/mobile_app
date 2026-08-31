import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import '../../../core/platform/app_theme.dart';
import '../../../core/platform/app_log_store.dart';
import 'audio_metadata.dart';
import 'audio_playback_service.dart';
import '../common/playback_engine.dart';
import '../common/player_queue.dart';

/// 将 audio_service 的后台状态接入现有播放器页面。
///
/// [dispose] 只解除 UI isolate 的监听，不会停止 AudioHandler，因此退出
/// 全屏页面后音频仍可继续在后台播放。
class AudioPlaybackEngine
    implements PlaybackEngine, AudioMetadataSink, ScratchPlaybackEngine {
  static const _scratchPositionPollInterval = Duration(milliseconds: 33);

  AudioPlaybackEngine({required audio_service.AudioHandler handler})
    : _handler = handler,
      _state = ValueNotifier(
        const PlaybackViewState(engineKind: PlaybackEngineKind.audio),
      ) {
    _subscriptions.add(_handler.playbackState.listen(_handlePlaybackState));
    _subscriptions.add(_handler.mediaItem.listen(_handleMediaItem));
    _handlePlaybackState(_handler.playbackState.valueOrNull);
    _handleMediaItem(_handler.mediaItem.valueOrNull);
    unawaited(_restoreScratchMode());
  }

  final audio_service.AudioHandler _handler;
  final ValueNotifier<PlaybackViewState> _state;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  audio_service.MediaItem? _currentItem;
  bool _disposed = false;
  String? _scratchSource;
  String? _scratchSourceId;
  Map<String, String>? _scratchHeaders;
  Future<bool>? _scratchPrepareFuture;
  int _scratchSourceGeneration = 0;
  int _scratchStartGeneration = 0;
  bool _scratchActive = false;
  bool _scratchMainPlaybackPaused = false;
  bool _scratchResumePlayback = false;
  bool _scratchModeStatusKnown = false;
  double _pendingScratchRate = 0;
  Timer? _scratchPositionPollTimer;
  bool _scratchPositionPollInFlight = false;
  int _scratchPositionPollGeneration = 0;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.audio;

  @override
  PlaybackEngineCapabilities get capabilities =>
      const PlaybackEngineCapabilities(
        pictureInPicture: false,
        framePreview: false,
        audioTracks: false,
        textSubtitles: false,
        bitmapSubtitles: false,
        customBuffering: false,
        playbackRate: false,
      );

  @override
  ValueListenable<PlaybackViewState> get state => _state;

  @override
  Future<void> open(PlaybackOpenRequest request) async {
    if (_disposed) return;
    final items = request.queue
        .where((item) => item.type == PlayerQueueItemType.audio)
        .toList();
    final queue = items.isEmpty
        ? [
            PlayerQueueItem(
              title: _titleFromUrl(request.url),
              type: PlayerQueueItemType.audio,
              mediaId: request.url,
              directUrl: request.url,
              directHeaders: request.headers,
              directFormatHint: request.formatHint,
              directPlaybackFileName: _titleFromUrl(request.url),
            ),
          ]
        : items;
    var index = request.queueIndex;
    if (index < 0 || index >= queue.length) index = 0;
    _setScratchSource(
      queue[index].safeMediaId,
      queue[index].directUrl ?? request.url,
      queue[index].directHeaders ?? request.headers,
    );
    final queueKey = playerQueueKey(queue);
    final dispose = request.onQueueDispose;
    if (dispose != null) {
      AudioPlaybackService.registerResources(queueKey, dispose);
    }
    try {
      await _handler.customAction(audioOpenQueueAction, <String, dynamic>{
        'queue': queue.map((item) => item.toAudioPayload()).toList(),
        'queueIndex': index,
        'positionMs': (request.startAt ?? Duration.zero).inMilliseconds,
        'play': request.play,
        'queueKey': queueKey,
      });
      _warmScratchAudio();
    } catch (_) {
      AudioPlaybackResourceRegistry.instance.handleEvent(<String, dynamic>{
        'type': 'queue_resources',
        'queueKey': queueKey,
      });
      rethrow;
    }
  }

  @override
  Future<void> play() => _handler.play();

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> playOrPause() =>
      _state.value.playing ? _handler.pause() : _handler.play();

  @override
  Future<void> skipToPrevious() => _handler.skipToPrevious();

  @override
  Future<void> skipToNext() => _handler.skipToNext();

  @override
  Future<void> setShuffleMode(bool enabled) => _handler.setShuffleMode(
    enabled
        ? audio_service.AudioServiceShuffleMode.all
        : audio_service.AudioServiceShuffleMode.none,
  );

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) =>
      _handler.setRepeatMode(switch (mode) {
        PlaybackRepeatMode.one => audio_service.AudioServiceRepeatMode.one,
        PlaybackRepeatMode.all => audio_service.AudioServiceRepeatMode.all,
        PlaybackRepeatMode.off => audio_service.AudioServiceRepeatMode.none,
      });

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Future<void> setRate(double rate) => _handler.setSpeed(rate);

  @override
  Future<bool> startScratch(
    Duration position, {
    required bool resumePlayback,
  }) async {
    if (!OmmScratchAudio.isSupported) return false;
    final source = _scratchSource;
    final sourceId = _scratchSourceId;
    if (source == null ||
        source.isEmpty ||
        sourceId == null ||
        sourceId.isEmpty) {
      return false;
    }
    if (_scratchActive) {
      _scratchResumePlayback = resumePlayback;
      try {
        final state = await OmmScratchAudio.state();
        if (state.ready && state.sourceId == sourceId) {
          await OmmScratchAudio.setRate(_pendingScratchRate);
          await OmmScratchAudio.play();
          await _handler.customAction(audioSetScratchModeAction, {
            'active': true,
            'playbackIntent': resumePlayback,
            'sourceId': sourceId,
          });
          return true;
        }
      } catch (_) {}
      _scratchActive = false;
      _stopScratchPositionPolling();
      try {
        await OmmScratchAudio.stop();
      } catch (_) {}
      try {
        await _handler.customAction(audioSetScratchModeAction, {
          'active': false,
        });
      } catch (_) {}
    }
    final sourceGeneration = _scratchSourceGeneration;
    final startGeneration = ++_scratchStartGeneration;
    _scratchResumePlayback = resumePlayback;
    try {
      // 先切断 just_audio 的输出，再等待 PCM 准备。否则远程音频准备期间
      // 主播放器仍在发声，手指已经按住唱片却听到另一套未受控的声音。
      _scratchMainPlaybackPaused = true;
      await _handler.pause();
      final prepare = _scratchPrepareFuture ??= _prepareScratchAudio(
        source: source,
        sourceId: sourceId,
        headers: _scratchHeaders,
      );
      var timedOut = false;
      final ready = await prepare.timeout(
        // 当前 native MVP 需要先把音轨解码为 PCM。180ms 对远程直链和较大
        // 音频几乎必然过短，会让每次手势都静默退回 seek；给同一个准备任务
        // 足够时间，才能确保真正切入 Scratch 输出通道。
        const Duration(seconds: 30),
        onTimeout: () {
          timedOut = true;
          return false;
        },
      );
      if (startGeneration != _scratchStartGeneration) return false;
      if (!ready || sourceGeneration != _scratchSourceGeneration) {
        if (!ready && !timedOut && identical(_scratchPrepareFuture, prepare)) {
          _scratchPrepareFuture = null;
        }
        if (timedOut) {
          appLog('[AudioScratch] PCM 准备超过 30 秒，已回退普通播放');
        }
        if (resumePlayback) {
          // audio_service 的 play Future 可能持续到曲目结束，不能在这里 await。
          unawaited(_handler.play().catchError((_) {}));
        }
        _scratchMainPlaybackPaused = false;
        return false;
      }
      await OmmScratchAudio.setRate(_pendingScratchRate);
      await OmmScratchAudio.start(
        position: position,
        sourceId: sourceId,
        autoplay: true,
      );
      if (startGeneration != _scratchStartGeneration) {
        await OmmScratchAudio.stop();
        return false;
      }
      _scratchActive = true;
      _scratchMainPlaybackPaused = false;
      await _handler.customAction(audioSetScratchModeAction, {
        'active': true,
        'playbackIntent': resumePlayback,
        'sourceId': sourceId,
      });
      _startScratchPositionPolling();
      return true;
    } catch (error) {
      _stopScratchPositionPolling();
      try {
        await OmmScratchAudio.stop();
      } catch (_) {}
      _scratchActive = false;
      _scratchMainPlaybackPaused = false;
      appLog('[AudioScratch] native Scratch 启动失败: $error');
      if (resumePlayback) {
        unawaited(_handler.play().catchError((_) {}));
      }
      return false;
    }
  }

  @override
  Future<void> setScratchRate(double rate) async {
    if (!rate.isFinite) return;
    _pendingScratchRate = rate.clamp(-8.0, 8.0).toDouble();
    if (!_scratchActive || !OmmScratchAudio.isSupported) return;
    try {
      await OmmScratchAudio.setRate(_pendingScratchRate);
    } catch (_) {}
  }

  @override
  Future<void> cancelScratchStart() async {
    _scratchStartGeneration++;
    _stopScratchPositionPolling();
    final shouldResume =
        _scratchResumePlayback &&
        (_scratchMainPlaybackPaused || _scratchActive);
    if (_scratchActive) {
      try {
        await OmmScratchAudio.stop();
      } catch (_) {}
      _scratchActive = false;
      try {
        await _handler.customAction(audioSetScratchModeAction, {
          'active': false,
        });
      } catch (_) {}
    }
    _scratchMainPlaybackPaused = false;
    if (shouldResume) {
      // audio_service 的 play Future 可能持续到曲目结束，不能在这里 await。
      unawaited(_handler.play().catchError((_) {}));
    }
  }

  @override
  Future<Duration?> finishScratch({required bool resumePlayback}) async {
    _scratchStartGeneration++;
    if (!_scratchActive) {
      final shouldResume = resumePlayback && _scratchMainPlaybackPaused;
      _scratchMainPlaybackPaused = false;
      if (shouldResume) {
        unawaited(_handler.play().catchError((_) {}));
      }
      return null;
    }
    try {
      final state = await OmmScratchAudio.state();
      if (!state.ready || state.sourceId != _scratchSourceId) {
        await OmmScratchAudio.stop();
        _scratchActive = false;
        _scratchMainPlaybackPaused = false;
        await _handler.customAction(audioSetScratchModeAction, {
          'active': false,
        });
        return null;
      }
      _scratchResumePlayback = resumePlayback;
      if (!resumePlayback) await OmmScratchAudio.pause();
      _scratchMainPlaybackPaused = false;
      await _handler.customAction(audioSetScratchModeAction, {
        'active': true,
        'playbackIntent': resumePlayback,
        'sourceId': state.sourceId,
      });
      _publishScratchPosition(state: state);
      return state.position;
    } catch (_) {
      try {
        await OmmScratchAudio.stop();
      } catch (_) {}
      _scratchActive = false;
      _scratchMainPlaybackPaused = false;
      try {
        await _handler.customAction(audioSetScratchModeAction, {
          'active': false,
        });
      } catch (_) {}
      if (resumePlayback) {
        unawaited(_handler.play().catchError((_) {}));
      }
      return null;
    }
  }

  void _startScratchPositionPolling() {
    _stopScratchPositionPolling();
    final generation = _scratchPositionPollGeneration;
    _scratchPositionPollTimer = Timer.periodic(
      _scratchPositionPollInterval,
      (_) => unawaited(_pollScratchPosition(generation)),
    );
  }

  void _stopScratchPositionPolling() {
    _scratchPositionPollTimer?.cancel();
    _scratchPositionPollTimer = null;
    _scratchPositionPollGeneration++;
  }

  Future<void> _pollScratchPosition(int generation) async {
    if (_disposed ||
        !_scratchActive ||
        _scratchPositionPollInFlight ||
        generation != _scratchPositionPollGeneration) {
      return;
    }
    _scratchPositionPollInFlight = true;
    try {
      final scratchState = await OmmScratchAudio.state();
      if (_disposed ||
          !_scratchActive ||
          generation != _scratchPositionPollGeneration) {
        return;
      }
      if (!scratchState.ready || scratchState.sourceId != _scratchSourceId) {
        _stopScratchPositionPolling();
        _scratchActive = false;
        try {
          await OmmScratchAudio.stop();
        } catch (_) {}
        try {
          await _handler.customAction(audioSetScratchModeAction, {
            'active': false,
          });
        } catch (_) {}
        return;
      }
      _publishScratchPosition(state: scratchState);
    } catch (_) {
      if (generation == _scratchPositionPollGeneration) {
        _stopScratchPositionPolling();
      }
    } finally {
      _scratchPositionPollInFlight = false;
    }
  }

  void _publishScratchPosition({
    required ScratchAudioState state,
    Duration? position,
  }) {
    if (_disposed) return;
    final current = _state.value;
    final duration = state.duration > Duration.zero
        ? state.duration
        : current.duration;
    var nextPosition = position ?? state.position;
    if (nextPosition < Duration.zero) {
      nextPosition = Duration.zero;
    }
    if (duration > Duration.zero && nextPosition > duration) {
      nextPosition = duration;
    }
    if (nextPosition == current.position && duration == current.duration) {
      return;
    }
    _state.value = current.copyWith(position: nextPosition, duration: duration);
  }

  void _warmScratchAudio() {
    if (!_scratchModeStatusKnown ||
        _scratchActive ||
        !OmmScratchAudio.isSupported ||
        _scratchSource == null) {
      return;
    }
    if (_scratchPrepareFuture != null) return;
    final source = _scratchSource!;
    final sourceId = _scratchSourceId;
    if (sourceId == null || sourceId.isEmpty) return;
    final future = _prepareScratchAudio(
      source: source,
      sourceId: sourceId,
      headers: _scratchHeaders,
    );
    _scratchPrepareFuture = future;
    unawaited(future);
  }

  Future<bool> _prepareScratchAudio({
    required String source,
    required String sourceId,
    Map<String, String>? headers,
  }) async {
    if (source.isEmpty) return false;
    try {
      final state = await OmmScratchAudio.prepare(
        source: source,
        sourceId: sourceId,
        headers: headers,
      );
      return state.ready && state.sourceId == sourceId;
    } catch (error) {
      appLog('[AudioScratch] PCM 准备失败: $error');
      return false;
    }
  }

  Future<void> _restoreScratchMode() async {
    try {
      final result = await _handler.customAction(audioGetScratchModeAction);
      if (_disposed) return;
      if (result is Map && result['active'] == true) {
        if (result['sourceId'] == _scratchSourceId) {
          _scratchActive = true;
          _scratchResumePlayback = result['playbackIntent'] == true;
          _startScratchPositionPolling();
        } else {
          try {
            await OmmScratchAudio.stop();
          } catch (_) {}
          await _handler.customAction(audioSetScratchModeAction, {
            'active': false,
          });
        }
      }
    } catch (_) {
      // 旧版或测试 handler 不支持查询时，继续按普通预热路径工作。
    } finally {
      if (!_disposed) {
        _scratchModeStatusKnown = true;
        if (!_scratchActive) _warmScratchAudio();
      }
    }
  }

  @override
  Future<void> configure({
    bool? hardwareAcceleration,
    int? preloadBytes,
  }) async {}

  @override
  Future<void> setAudioTrackById(String id) async {}

  @override
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  }) async {}

  @override
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  }) async {}

  @override
  Future<void> clearSubtitle() async {}

  @override
  Future<void> setSubtitleDelay(Duration delay) async {}

  @override
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  }) async => null;

  @override
  Future<void> clearFramePreview() async {}

  @override
  Future<bool> enterPictureInPicture(
    PlaybackPictureInPictureRequest request,
  ) async => false;

  @override
  Future<void> stopPictureInPicture() async {}

  @override
  Future<void> updateCurrentMetadata(AudioTrackMetadata metadata) async {
    final current = _currentItem;
    if (current == null) return;
    await _handler.customAction(audioUpdateMetadataAction, <String, dynamic>{
      'mediaId': current.id,
      'artworkUri': _localArtworkUri(metadata.artworkPath) ?? '',
      'artist': metadata.artist ?? '',
      'album': metadata.album ?? '',
    });
  }

  String? _localArtworkUri(String? artworkPath) {
    final path = artworkPath?.trim();
    if (path == null || path.isEmpty) return null;

    final isWindowsPath =
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path) || path.startsWith(r'\\');
    final parsed = Uri.tryParse(path);
    if (!isWindowsPath && parsed != null && parsed.scheme.isNotEmpty) {
      if (parsed.scheme != 'file' || parsed.hasQuery || parsed.hasFragment) {
        return null;
      }
      return parsed.toString();
    }

    return Uri.file(path, windows: isWindowsPath).toString();
  }

  @override
  Future<void> stop() => _handler.stop();

  @override
  Widget buildSurface({BoxFit fit = BoxFit.contain}) {
    return Builder(
      builder: (context) => ColoredBox(color: appColors(context).bg),
    );
  }

  void _handleMediaItem(audio_service.MediaItem? item) {
    if (_disposed) return;
    final previous = _currentItem;
    _currentItem = item;
    final current = _state.value;
    final itemChanged = previous?.id != item?.id;
    if (itemChanged) {
      _scratchActive = false;
      _scratchMainPlaybackPaused = false;
      _stopScratchPositionPolling();
      final source = item?.extras?['audioUrl']?.toString().trim();
      if (item != null && source != null && source.isNotEmpty) {
        _setScratchSource(item.id, source, _scratchHeadersFor(item));
        _warmScratchAudio();
      }
    }
    _state.value = current.copyWith(
      currentTitle: item?.title,
      artworkPath: _artworkPath(item?.artUri),
      clearArtworkPath: item?.artUri == null,
      clearMediaInfo: false,
      duration:
          item?.duration ?? (itemChanged ? Duration.zero : current.duration),
    );
  }

  String? _artworkPath(Uri? uri) {
    if (uri == null || uri.scheme != 'file') return null;
    return uri.toFilePath();
  }

  Map<String, String>? _scratchHeadersFor(audio_service.MediaItem item) {
    final raw = item.extras?['headersJson']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  void _setScratchSource(
    String sourceId,
    String source,
    Map<String, String>? headers,
  ) {
    if (_scratchSourceId == sourceId &&
        _scratchSource == source &&
        _sameHeaders(_scratchHeaders, headers)) {
      return;
    }
    _scratchSourceId = sourceId;
    _scratchSource = source;
    _scratchHeaders = headers;
    _scratchPrepareFuture = null;
    _scratchSourceGeneration++;
    _scratchStartGeneration++;
    _scratchActive = false;
    _scratchMainPlaybackPaused = false;
    _stopScratchPositionPolling();
  }

  bool _sameHeaders(Map<String, String>? left, Map<String, String>? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null || left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _handlePlaybackState(audio_service.PlaybackState? playback) {
    if (_disposed || playback == null) return;
    final preserveScratchPosition =
        _scratchActive || _scratchMainPlaybackPaused;
    final processing = playback.processingState;
    final lifecycle = switch (processing) {
      audio_service.AudioProcessingState.idle => PlaybackLifecycle.idle,
      audio_service.AudioProcessingState.loading => PlaybackLifecycle.opening,
      audio_service.AudioProcessingState.buffering => PlaybackLifecycle.ready,
      audio_service.AudioProcessingState.ready => PlaybackLifecycle.ready,
      audio_service.AudioProcessingState.completed =>
        PlaybackLifecycle.completed,
      audio_service.AudioProcessingState.error => PlaybackLifecycle.failed,
    };
    _state.value = _state.value.copyWith(
      lifecycle: lifecycle,
      playing: playback.playing,
      buffering:
          processing == audio_service.AudioProcessingState.loading ||
          processing == audio_service.AudioProcessingState.buffering,
      position: preserveScratchPosition
          ? _state.value.position
          : playback.position,
      duration: _currentItem?.duration ?? _state.value.duration,
      buffered: playback.bufferedPosition,
      rate: playback.speed,
      firstFrameRendered:
          processing == audio_service.AudioProcessingState.ready ||
          processing == audio_service.AudioProcessingState.completed,
      currentTitle: _currentItem?.title,
      queueIndex: playback.queueIndex,
      shuffleEnabled:
          playback.shuffleMode == audio_service.AudioServiceShuffleMode.all,
      repeatMode: switch (playback.repeatMode) {
        audio_service.AudioServiceRepeatMode.one => PlaybackRepeatMode.one,
        audio_service.AudioServiceRepeatMode.all => PlaybackRepeatMode.all,
        _ => PlaybackRepeatMode.off,
      },
      error: playback.errorMessage,
      clearError: playback.errorMessage == null,
    );
  }

  String _titleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final name = path.split('/').last.trim();
    return name.isEmpty ? '音频' : Uri.decodeComponent(name);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopScratchPositionPolling();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _state.dispose();
  }
}
