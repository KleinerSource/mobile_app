import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'audio_metadata.dart';
import 'audio_playback_service.dart';
import '../common/playback_engine.dart';
import '../common/player_queue.dart';

/// 将 audio_service 的后台状态接入现有播放器页面。
///
/// [dispose] 只解除 UI isolate 的监听，不会停止 AudioHandler，因此退出
/// 全屏页面后音频仍可继续在后台播放。
class AudioPlaybackEngine implements PlaybackEngine, AudioMetadataSink {
  AudioPlaybackEngine({required audio_service.AudioHandler handler})
    : _handler = handler,
      _state = ValueNotifier(
        const PlaybackViewState(engineKind: PlaybackEngineKind.audio),
      ) {
    _subscriptions.add(_handler.playbackState.listen(_handlePlaybackState));
    _subscriptions.add(_handler.mediaItem.listen(_handleMediaItem));
    _handlePlaybackState(_handler.playbackState.valueOrNull);
    _handleMediaItem(_handler.mediaItem.valueOrNull);
  }

  final audio_service.AudioHandler _handler;
  final ValueNotifier<PlaybackViewState> _state;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  audio_service.MediaItem? _currentItem;
  bool _disposed = false;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final background = scheme.surface;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Color.alphaBlend(
          (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          background,
        );
        final iconColor = scheme.onSurface.withValues(alpha: 0.08);
        final cardSize = (constraints.maxWidth - 48)
            .clamp(0.0, 420.0)
            .toDouble();
        return ColoredBox(
          color: background,
          child: Align(
            alignment: const Alignment(0, -0.1),
            child: SizedBox(
              width: cardSize,
              height: cardSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.1,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: iconColor,
                    size: cardSize * 0.34,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMediaItem(audio_service.MediaItem? item) {
    if (_disposed) return;
    final previous = _currentItem;
    _currentItem = item;
    final current = _state.value;
    final itemChanged = previous?.id != item?.id;
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

  void _handlePlaybackState(audio_service.PlaybackState? playback) {
    if (_disposed || playback == null) return;
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
      position: playback.position,
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
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _state.dispose();
  }
}
