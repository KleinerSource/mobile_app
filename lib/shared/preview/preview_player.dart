import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 预览视频播放器的最小协议，供不同媒体模块复用并便于测试注入。
abstract interface class PreviewPlayer {
  ValueListenable<Duration> get duration;

  ValueListenable<Duration> get position;

  Widget buildVideo({BoxFit fit = BoxFit.cover});

  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoplay = true,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

typedef PreviewPlayerFactory = PreviewPlayer Function();

/// 使用 media_kit 播放静音预览视频。
class MediaKitPreviewPlayer implements PreviewPlayer {
  MediaKitPreviewPlayer()
    : _player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          bufferSize: 8 * 1024 * 1024,
        ),
      ) {
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        _duration.value = value;
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        _position.value = value;
      }),
    );
  }

  final Player _player;
  late final VideoController _controller;
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  ValueListenable<Duration> get duration => _duration;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  Widget buildVideo({BoxFit fit = BoxFit.cover}) => Video(
    controller: _controller,
    controls: NoVideoControls,
    fit: fit,
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoplay = true,
  }) async {
    await _player
        .open(
          Media(url, httpHeaders: headers?.isEmpty == true ? null : headers),
          play: autoplay,
        )
        .timeout(const Duration(seconds: 3));
    try {
      await _controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // 某些平台不回报首帧，但播放器可能已经可以正常显示。
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    _duration.dispose();
    _position.dispose();
  }
}

/// 页面级预览协调器，保证同一媒体列表同时只有一个预览播放器。
class PreviewCoordinator {
  VoidCallback? _activeRelease;

  void claim(VoidCallback release) {
    if (identical(_activeRelease, release)) return;
    _activeRelease?.call();
    _activeRelease = release;
  }

  void release(VoidCallback release) {
    if (identical(_activeRelease, release)) _activeRelease = null;
  }

  void dispose() {
    _activeRelease?.call();
    _activeRelease = null;
  }
}

/// 为媒体列表提供页面级预览协调器。
class PreviewScope extends StatefulWidget {
  const PreviewScope({super.key, required this.child});

  final Widget child;

  static PreviewCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_PreviewInherited>()
      ?.coordinator;

  @override
  State<PreviewScope> createState() => _PreviewScopeState();
}

class _PreviewScopeState extends State<PreviewScope> {
  final _coordinator = PreviewCoordinator();

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _PreviewInherited(coordinator: _coordinator, child: widget.child);
}

class _PreviewInherited extends InheritedWidget {
  const _PreviewInherited({required this.coordinator, required super.child});

  final PreviewCoordinator coordinator;

  @override
  bool updateShouldNotify(_PreviewInherited oldWidget) =>
      coordinator != oldWidget.coordinator;
}
