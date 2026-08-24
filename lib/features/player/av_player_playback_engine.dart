import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:md_center_avplayer/md_center_avplayer.dart';

import 'playback_engine.dart';

class AvPlayerPlaybackEngine implements PlaybackEngine {
  AvPlayerPlaybackEngine()
    : _playerFuture = MdCenterAvPlayer.create(),
      _state = ValueNotifier(
        const PlaybackViewState(engineKind: PlaybackEngineKind.avPlayer),
      );

  final Future<MdCenterAvPlayer> _playerFuture;
  final ValueNotifier<PlaybackViewState> _state;
  MdCenterAvPlayer? _player;
  StreamSubscription<AvPlayerEvent>? _eventSubscription;
  PlaybackPictureInPictureRequest? _pictureInPictureRequest;
  List<_WebVttCue> _subtitleCues = const [];
  Duration _subtitleDelay = Duration.zero;
  bool _disposed = false;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.avPlayer;

  @override
  PlaybackEngineCapabilities get capabilities =>
      const PlaybackEngineCapabilities.avPlayer();

  @override
  ValueListenable<PlaybackViewState> get state => _state;

  Future<MdCenterAvPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = await _playerFuture;
    if (_disposed) {
      await player.dispose();
      throw StateError('播放器已释放');
    }
    _player = player;
    _eventSubscription = player.events.listen(_onEvent);
    return player;
  }

  void _update(PlaybackViewState Function(PlaybackViewState) update) {
    if (!_disposed) _state.value = update(_state.value);
  }

  void _onEvent(AvPlayerEvent event) {
    switch (event.type) {
      case AvPlayerEventType.ready:
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.ready,
            buffering: false,
          ),
        );
        unawaited(_refreshAudioTracks());
      case AvPlayerEventType.playing:
        _update((state) => state.copyWith(playing: event.boolValue ?? false));
      case AvPlayerEventType.buffering:
        _update((state) => state.copyWith(buffering: event.boolValue ?? false));
      case AvPlayerEventType.position:
        final position = Duration(
          milliseconds: (event.numberValue ?? 0).round(),
        );
        _update(
          (state) => state.copyWith(
            position: position,
            subtitleText: _subtitleAt(position),
          ),
        );
      case AvPlayerEventType.duration:
        _update(
          (state) => state.copyWith(
            duration: Duration(milliseconds: (event.numberValue ?? 0).round()),
          ),
        );
      case AvPlayerEventType.buffered:
        _update(
          (state) => state.copyWith(
            buffered: Duration(milliseconds: (event.numberValue ?? 0).round()),
          ),
        );
      case AvPlayerEventType.size:
        _update(
          (state) => state.copyWith(
            videoSize: Size(
              event.numberValue ?? 0,
              event.secondaryNumberValue ?? 0,
            ),
          ),
        );
      case AvPlayerEventType.completed:
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.completed,
            playing: false,
          ),
        );
      case AvPlayerEventType.error:
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.failed,
            error: event.stringValue ?? 'AVPlayer 播放失败',
          ),
        );
      case AvPlayerEventType.firstFrame:
        _update((state) => state.copyWith(firstFrameRendered: true));
      case AvPlayerEventType.pictureInPicture:
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
    if (request.headers?.isNotEmpty == true) {
      throw UnsupportedError('AVPlayer 不接受非公开 HTTP header 注入');
    }
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
        subtitleText: const [],
        firstFrameRendered: false,
        clearError: true,
      ),
    );
    final player = await _ensurePlayer();
    await player.open(
      request.url,
      startAt: request.startAt,
      autoplay: request.play,
    );
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
  }) async {}

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
  }) {
    throw UnsupportedError('AVPlayer 内嵌字幕由后端 WebVTT 或烧录 HLS 提供');
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
    await pause();
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
    return FutureBuilder<MdCenterAvPlayer>(
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
}

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
