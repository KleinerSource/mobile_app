import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_ksplayer/omm_ksplayer.dart';

import '../../core/platform/app_log_store.dart';
import 'playback_engine.dart';

class KsPlayerPlaybackEngine implements PlaybackEngine {
  KsPlayerPlaybackEngine()
    : _playerFuture = OmmKsPlayer.create(),
      _state = ValueNotifier(
        const PlaybackViewState(engineKind: PlaybackEngineKind.ksPlayer),
      );

  final Future<OmmKsPlayer> _playerFuture;
  final ValueNotifier<PlaybackViewState> _state;
  OmmKsPlayer? _player;
  StreamSubscription<KsPlayerEvent>? _eventSubscription;
  PlaybackPictureInPictureRequest? _pictureInPictureRequest;
  List<_WebVttCue> _subtitleCues = const [];
  Duration _subtitleDelay = Duration.zero;
  bool _disposed = false;
  bool _suppressErrorsUntilOpen = false;
  int _preloadBytes = 250 * 1024 * 1024;
  bool _hardwareAcceleration = true;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.ksPlayer;

  @override
  PlaybackEngineCapabilities get capabilities =>
      const PlaybackEngineCapabilities.ksPlayer();

  @override
  ValueListenable<PlaybackViewState> get state => _state;

  Future<OmmKsPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = await _playerFuture;
    if (_disposed) {
      await player.dispose();
      throw StateError('播放器已释放');
    }
    _player = player;
    appLog('[KsPlayer] 原生播放器已创建: id=${player.playerId}');
    _eventSubscription = player.events.listen(_onEvent);
    return player;
  }

  void _update(PlaybackViewState Function(PlaybackViewState) update) {
    if (!_disposed) _state.value = update(_state.value);
  }

  void _onEvent(KsPlayerEvent event) {
    switch (event.type) {
      case KsPlayerEventType.ready:
        appLog('[KsPlayer] 收到 ready 事件');
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.ready,
            buffering: false,
          ),
        );
        unawaited(_refreshAudioTracks());
      case KsPlayerEventType.playing:
        _update((state) => state.copyWith(playing: event.boolValue ?? false));
      case KsPlayerEventType.buffering:
        _update((state) => state.copyWith(buffering: event.boolValue ?? false));
      case KsPlayerEventType.position:
        final position = Duration(
          milliseconds: (event.numberValue ?? 0).round(),
        );
        _update(
          (state) => state.copyWith(
            position: position,
            subtitleText: _subtitleAt(position),
          ),
        );
      case KsPlayerEventType.duration:
        _update(
          (state) => state.copyWith(
            duration: Duration(milliseconds: (event.numberValue ?? 0).round()),
          ),
        );
      case KsPlayerEventType.size:
        final nativeMediaInfo = PlaybackMediaInfo.fromJsonString(
          event.stringValue,
        );
        _update(
          (state) => state.copyWith(
            videoSize: Size(
              event.numberValue ?? 0,
              event.secondaryNumberValue ?? 0,
            ),
            mediaInfo: _mergeMediaInfo(state.mediaInfo, nativeMediaInfo),
          ),
        );
      case KsPlayerEventType.completed:
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.completed,
            playing: false,
          ),
        );
      case KsPlayerEventType.error:
        appLog('[KsPlayer] 收到 error 事件: ${event.stringValue ?? '未知错误'}');
        // KSPlayer 在已出首帧并开始推进时间后，底层播放器切换时可能迟到回调
        // 一次错误；此时画面仍在正常播放，不能把它变成统一播放失败状态。
        // stop() 到下一次 open() 之间的旧媒体错误同样不能污染新会话。
        if (_suppressErrorsUntilOpen ||
            shouldIgnoreKsPlayerError(_state.value)) {
          return;
        }
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.failed,
            error: event.stringValue ?? 'KSPlayer 播放失败',
          ),
        );
      case KsPlayerEventType.firstFrame:
        appLog('[KsPlayer] 收到 firstFrame 事件');
        _update((state) => state.copyWith(firstFrameRendered: true));
      case KsPlayerEventType.pictureInPicture:
        final active = event.boolValue ?? false;
        _update((state) => state.copyWith(inPictureInPicture: active));
        if (!active) {
          final request = _pictureInPictureRequest;
          _pictureInPictureRequest = null;
          if (request?.onStopped != null) {
            unawaited(request!.onStopped!(_state.value.position));
          }
        }
    }
  }

  Future<void> _refreshAudioTracks() async {
    final player = await _ensurePlayer();
    final tracks = await player.audioTracks();
    if (_disposed) return;
    String? selected;
    final mapped = <PlaybackAudioTrackState>[
      for (final track in tracks)
        PlaybackAudioTrackState(
          id: track.id,
          title: track.title,
          language: track.language,
          isSelected: track.selected,
        ),
    ];
    for (final track in mapped) {
      if (track.isSelected) {
        selected = track.id;
        break;
      }
    }
    _update(
      (state) => state.copyWith(
        audioTracks: mapped,
        selectedAudioTrackId: selected,
        clearSelectedAudioTrackId: selected == null,
      ),
    );
  }

  @override
  Future<void> open(PlaybackOpenRequest request) async {
    _suppressErrorsUntilOpen = false;
    _subtitleCues = const [];
    _update(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.opening,
        playing: false,
        buffering: true,
        position: request.startAt ?? Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        videoSize: Size.zero,
        mediaInfo: _initialMediaInfo(request),
        clearMediaInfo: true,
        subtitleText: const [],
        firstFrameRendered: false,
        clearError: true,
      ),
    );
    final player = await _ensurePlayer();
    appLog(
      '[KsPlayer] 调用原生 open: id=${player.playerId} '
      'url=${request.url} formatHint=${request.formatHint ?? ''} '
      'hw=$_hardwareAcceleration',
    );
    try {
      await player.open(
        request.url,
        startAt: request.startAt,
        autoplay: request.play,
        headers: request.headers,
        formatHint: request.formatHint,
        videoCodec: request.mediaInfo?.videoCodec,
        preloadBytes: _preloadBytes,
        hardwareAcceleration: _hardwareAcceleration,
      );
      appLog('[KsPlayer] 原生 open 已返回: id=${player.playerId}');
    } catch (error, stackTrace) {
      appLog('[KsPlayer] 原生 open 失败: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> play() async => (await _ensurePlayer()).play();

  @override
  Future<void> pause() async => (await _ensurePlayer()).pause();

  @override
  Future<void> playOrPause() => _state.value.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async =>
      (await _ensurePlayer()).seek(position);

  @override
  Future<void> setRate(double rate) async {
    await (await _ensurePlayer()).setRate(rate);
    _update((state) => state.copyWith(rate: rate));
  }

  @override
  Future<void> configure({
    bool? hardwareAcceleration,
    int? preloadBytes,
  }) async {
    if (preloadBytes != null && preloadBytes > 0) {
      _preloadBytes = preloadBytes;
    }
    if (hardwareAcceleration != null) {
      _hardwareAcceleration = hardwareAcceleration;
    }
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    await (await _ensurePlayer()).selectAudioTrack(id);
    await _refreshAudioTracks();
  }

  @override
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  }) async {
    await (await _ensurePlayer()).selectSubtitleTrack(id, fallbackIndex);
    _update((state) => state.copyWith(selectedSubtitleTrackId: id));
  }

  @override
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  }) async {
    _subtitleCues = _parseWebVtt(content);
    _update(
      (state) => state.copyWith(subtitleText: _subtitleAt(state.position)),
    );
  }

  @override
  Future<void> clearSubtitle() async {
    _subtitleCues = const [];
    final player = _player;
    if (player != null) await player.clearSubtitleTrack();
    _update(
      (state) => state.copyWith(
        subtitleText: const [],
        clearSelectedSubtitleTrackId: true,
      ),
    );
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    _subtitleDelay = delay;
    _update(
      (state) => state.copyWith(subtitleText: _subtitleAt(state.position)),
    );
  }

  List<String> _subtitleAt(Duration position) {
    final adjusted = position - _subtitleDelay;
    return [
      for (final cue in _subtitleCues)
        if (adjusted >= cue.start && adjusted < cue.end) cue.text,
    ];
  }

  @override
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  }) async => (await _ensurePlayer()).captureFrame(position);

  @override
  Future<void> clearFramePreview() async {
    final player = _player;
    if (player != null) await player.cancelFramePreview();
  }

  @override
  Future<bool> enterPictureInPicture(
    PlaybackPictureInPictureRequest request,
  ) async {
    _pictureInPictureRequest = request;
    final player = await _ensurePlayer();
    if (request.autoplay) {
      await player.play();
    } else {
      await player.pause();
    }
    final started = await player.startPictureInPicture();
    if (!started) _pictureInPictureRequest = null;
    return started;
  }

  @override
  Future<void> stopPictureInPicture() async {
    final player = _player;
    if (player != null) await player.stopPictureInPicture();
  }

  @override
  Future<void> stop() async {
    _suppressErrorsUntilOpen = true;
    await (await _ensurePlayer()).stop();
    _update(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.stopped,
        playing: false,
        buffering: false,
      ),
    );
  }

  @override
  Widget buildSurface({BoxFit fit = BoxFit.contain}) {
    return FutureBuilder<OmmKsPlayer>(
      future: _playerFuture,
      builder: (_, snapshot) {
        final player = snapshot.data;
        return player == null
            ? const ColoredBox(color: Colors.black)
            : player.buildView(fit: fit);
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSubscription?.cancel();
    final player = _player ?? await _playerFuture;
    await player.dispose();
    _state.dispose();
  }

  PlaybackMediaInfo _initialMediaInfo(PlaybackOpenRequest request) {
    final initial =
        request.mediaInfo ??
        PlaybackMediaInfo.fromSource(
          url: request.url,
          formatHint: request.formatHint,
        );
    final inferredInternalPlayer =
        PlaybackMediaInfo.inferInternalPlayer(
          request.url,
          request.formatHint,
          videoCodec: initial.videoCodec,
        ) ??
        PlaybackMediaInfo.inferInternalPlayer('', initial.container);
    return initial.copyWith(internalPlayer: inferredInternalPlayer);
  }

  PlaybackMediaInfo? _mergeMediaInfo(
    PlaybackMediaInfo? current,
    PlaybackMediaInfo? incoming,
  ) {
    if (incoming == null) return current;
    final info = current ?? const PlaybackMediaInfo();
    return info.copyWith(
      container: incoming.container,
      videoCodec: incoming.videoCodec,
      videoBitrate: incoming.videoBitrate,
      videoFps: incoming.videoFps,
      videoDecoder: incoming.videoDecoder,
      audioCodec: incoming.audioCodec,
      audioBitrate: incoming.audioBitrate,
      internalPlayer: incoming.internalPlayer,
    );
  }
}

/// 判断 KSPlayer 的错误回调是否属于已成功开始播放后的迟到错误。
///
/// 打开期间的错误由 [PlaybackEngine.open] 的 Future 返回；播放期间已出首帧
/// 的迟到错误则不能把仍在工作的会话标记为失败。
bool shouldIgnoreKsPlayerError(PlaybackViewState state) =>
    state.lifecycle == PlaybackLifecycle.opening ||
    (state.firstFrameRendered &&
        (state.playing || state.position > Duration.zero));

@immutable
class _WebVttCue {
  const _WebVttCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

List<_WebVttCue> _parseWebVtt(String content) {
  final lines = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final cues = <_WebVttCue>[];
  for (var index = 0; index < lines.length; index++) {
    var timeline = lines[index].trim();
    if (!timeline.contains('-->') && index + 1 < lines.length) {
      final next = lines[index + 1].trim();
      if (next.contains('-->')) {
        index++;
        timeline = next;
      }
    }
    if (!timeline.contains('-->')) continue;
    final parts = timeline.split('-->');
    if (parts.length != 2) continue;
    final start = _parseWebVttTime(parts[0].trim());
    final endToken = parts[1].trim().split(RegExp(r'\s+')).first;
    final end = _parseWebVttTime(endToken);
    if (start == null || end == null || end <= start) continue;
    final text = <String>[];
    while (index + 1 < lines.length && lines[index + 1].trim().isNotEmpty) {
      text.add(lines[++index]);
    }
    if (text.isNotEmpty) {
      cues.add(_WebVttCue(start: start, end: end, text: text.join('\n')));
    }
  }
  return cues;
}

Duration? _parseWebVttTime(String value) {
  final parts = value.replaceAll(',', '.').split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final seconds = double.tryParse(parts.last);
  final minutes = int.tryParse(parts[parts.length - 2]);
  final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
  if (seconds == null || minutes == null || hours == null) return null;
  return Duration(
    milliseconds: ((hours * 3600 + minutes * 60 + seconds) * 1000).round(),
  );
}
