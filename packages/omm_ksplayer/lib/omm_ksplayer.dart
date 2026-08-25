import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/ks_player_api.g.dart';

export 'src/ks_player_api.g.dart'
    show KsPlayerAudioTrack, KsPlayerEvent, KsPlayerEventType;

class OmmKsPlayer {
  OmmKsPlayer._(this.playerId, this._events);

  static const viewType = 'omm_ksplayer/view';
  static final OmmKsPlayerHostApi _api = OmmKsPlayerHostApi();
  static final Map<int, StreamController<KsPlayerEvent>> _controllers = {};
  static int _nextPlayerId = 1;
  static bool _callbacksRegistered = false;

  final int playerId;
  final StreamController<KsPlayerEvent> _events;
  bool _disposed = false;

  Stream<KsPlayerEvent> get events => _events.stream;

  static Future<OmmKsPlayer> create() async {
    if (!_callbacksRegistered) {
      OmmKsPlayerFlutterApi.setUp(_KsPlayerCallbacks());
      _callbacksRegistered = true;
    }
    final id = _nextPlayerId++;
    final controller = StreamController<KsPlayerEvent>.broadcast();
    _controllers[id] = controller;
    try {
      await _api.create(id);
      return OmmKsPlayer._(id, controller);
    } catch (_) {
      _controllers.remove(id);
      await controller.close();
      rethrow;
    }
  }

  Widget buildView({BoxFit fit = BoxFit.contain}) {
    final gravity = switch (fit) {
      BoxFit.cover => 'cover',
      BoxFit.fill => 'fill',
      _ => 'contain',
    };
    return UiKitView(
      viewType: viewType,
      creationParams: <String, Object?>{
        'playerId': playerId,
        'videoGravity': gravity,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  Future<void> open(
    String url, {
    Duration? startAt,
    bool autoplay = true,
    Map<String, String>? headers,
    String? formatHint,
    String? videoCodec,
  }) => _api.open(
    playerId,
    url,
    startAt?.inMilliseconds.toDouble(),
    autoplay,
    headers,
    formatHint,
    videoCodec,
  );

  Future<void> play() => _api.play(playerId);
  Future<void> pause() => _api.pause(playerId);
  Future<void> stop() => _api.stop(playerId);
  Future<void> seek(Duration position) =>
      _api.seek(playerId, position.inMilliseconds.toDouble());
  Future<void> setRate(double rate) => _api.setRate(playerId, rate);
  Future<List<KsPlayerAudioTrack>> audioTracks() => _api.audioTracks(playerId);
  Future<void> selectAudioTrack(String id) =>
      _api.selectAudioTrack(playerId, id);
  Future<void> selectSubtitleTrack(String id, int? fallbackIndex) =>
      _api.selectSubtitleTrack(playerId, id, fallbackIndex);
  Future<void> clearSubtitleTrack() => _api.clearSubtitleTrack(playerId);
  Future<Uint8List?> captureFrame(Duration position) =>
      _api.captureFrame(playerId, position.inMilliseconds.toDouble());
  Future<void> cancelFramePreview() => _api.cancelFramePreview(playerId);
  Future<bool> startPictureInPicture() => _api.startPictureInPicture(playerId);
  Future<void> stopPictureInPicture() => _api.stopPictureInPicture(playerId);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controllers.remove(playerId);
    try {
      await _api.dispose(playerId);
    } finally {
      await _events.close();
    }
  }
}

class _KsPlayerCallbacks implements OmmKsPlayerFlutterApi {
  @override
  void onEvent(KsPlayerEvent event) {
    OmmKsPlayer._controllers[event.playerId]?.add(event);
  }
}
