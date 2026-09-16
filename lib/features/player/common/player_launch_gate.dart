import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/single_flight_gate.dart';

/// 播放器页面全局只允许同时存在一个启动/播放路由。
final playerPageOpenGate = SingleFlightGate();

typedef PlaybackTaskStopCallback = Future<void> Function();

final playbackTaskCoordinatorProvider = Provider<PlaybackTaskCoordinator>((_) {
  return PlaybackTaskCoordinator();
});

class PlaybackTaskCoordinator {
  final Set<PlaybackTaskStopCallback> _callbacks = {};
  Future<void>? _stopping;

  VoidCallback register(PlaybackTaskStopCallback callback) {
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }

  Future<void> stopAll() {
    final active = _stopping;
    if (active != null) return active;
    late final Future<void> stopping;
    stopping = _stopRegistered().whenComplete(() {
      if (identical(_stopping, stopping)) _stopping = null;
    });
    _stopping = stopping;
    return stopping;
  }

  Future<void> _stopRegistered() async {
    final callbacks = _callbacks.toList(growable: false);
    await Future.wait([for (final callback in callbacks) _stopOne(callback)]);
  }

  Future<void> _stopOne(PlaybackTaskStopCallback callback) async {
    try {
      await callback().timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
