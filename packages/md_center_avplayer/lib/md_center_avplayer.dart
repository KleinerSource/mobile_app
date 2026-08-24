import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/av_player_api.g.dart';

export 'src/av_player_api.g.dart'
    show AvPlayerAudioTrack, AvPlayerEvent, AvPlayerEventType;

class MdCenterAvPlayer {
  MdCenterAvPlayer._(this.playerId, this._events);

  static const viewType = 'md_center_avplayer/view';
  static final MdCenterAvPlayerHostApi _api = MdCenterAvPlayerHostApi();
  static final Map<int, StreamController<AvPlayerEvent>> _controllers = {};
  static int _nextPlayerId = 1;
  static bool _callbacksRegistered = false;

  final int playerId;
  final StreamController<AvPlayerEvent> _events;
  bool _disposed = false;

  Stream<AvPlayerEvent> get events => _events.stream;

  static Future<MdCenterAvPlayer> create() async {
    if (!_callbacksRegistered) {
      MdCenterAvPlayerFlutterApi.setUp(_AvPlayerCallbacks());
      _callbacksRegistered = true;
    }
    final id = _nextPlayerId++;
    final controller = StreamController<AvPlayerEvent>.broadcast();
    _controllers[id] = controller;
    try {
      await _api.create(id);
      return MdCenterAvPlayer._(id, controller);
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

  Future<void> open(String url, {Duration? startAt, bool autoplay = true}) =>
      _api.open(playerId, url, startAt?.inMilliseconds.toDouble(), autoplay);

  Future<void> play() => _api.play(playerId);
  Future<void> pause() => _api.pause(playerId);
  Future<void> seek(Duration position) =>
      _api.seek(playerId, position.inMilliseconds.toDouble());
  Future<void> setRate(double rate) => _api.setRate(playerId, rate);
  Future<List<AvPlayerAudioTrack>> audioTracks() => _api.audioTracks(playerId);
  Future<void> selectAudioTrack(String id) =>
      _api.selectAudioTrack(playerId, id);
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

class _AvPlayerCallbacks implements MdCenterAvPlayerFlutterApi {
  @override
  void onEvent(AvPlayerEvent event) {
    MdCenterAvPlayer._controllers[event.playerId]?.add(event);
  }
}
