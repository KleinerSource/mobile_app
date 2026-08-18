import 'dart:async';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 播放器共用的系统亮度/音量作用域。
///
/// 两种播放器内核都使用系统输出能力，但手势实现分别在 Flutter 和
/// KSPlayer 原生层。这里统一初始化、串行更新、系统音量提示和离场恢复，
/// 避免不同页面留下不同的系统状态。
final class PlayerSystemLevels {
  double brightness = 0.5;
  double volume = 0.5;
  bool brightnessReady = false;

  Future<void> _brightnessOperations = Future<void>.value();
  Future<void> _volumeOperations = Future<void>.value();
  Future<void>? _initializeFuture;
  double? _initialBrightness;
  bool _scopeStarted = false;

  Future<void> initialize() => _initializeFuture ??= _initializeInternal();

  Future<void> _initializeInternal() async {
    _scopeStarted = true;
    unawaited(FlutterVolumeController.updateShowSystemUI(false));
    await _queueBrightnessOperation(() async {
      try {
        _initialBrightness = await ScreenBrightness.instance.application;
        brightness = _initialBrightness ?? brightness;
      } catch (_) {}
      brightnessReady = true;
    });
    try {
      volume = await FlutterVolumeController.getVolume() ?? volume;
    } catch (_) {}
  }

  void adjustBrightness(double delta) {
    if (!brightnessReady) return;
    brightness = (brightness + delta).clamp(0.0, 1.0);
    final value = brightness;
    unawaited(
      _queueBrightnessOperation(
        () => ScreenBrightness.instance.setApplicationScreenBrightness(value),
      ),
    );
  }

  void adjustVolume(double delta) {
    volume = (volume + delta).clamp(0.0, 1.0);
    final value = volume;
    unawaited(
      _queueVolumeOperation(() => FlutterVolumeController.setVolume(value)),
    );
  }

  void restore() {
    unawaited(FlutterVolumeController.updateShowSystemUI(true));
    if (!_scopeStarted) return;
    unawaited(
      _queueBrightnessOperation(() async {
        final initialBrightness = _initialBrightness;
        if (initialBrightness != null) {
          await ScreenBrightness.instance.setApplicationScreenBrightness(
            initialBrightness,
          );
        } else {
          await ScreenBrightness.instance.resetApplicationScreenBrightness();
        }
      }),
    );
  }

  Future<void> _queueBrightnessOperation(Future<void> Function() operation) {
    final next = _brightnessOperations.then<void>((_) async {
      try {
        await operation();
      } catch (_) {}
    });
    _brightnessOperations = next;
    return next;
  }

  Future<void> _queueVolumeOperation(Future<void> Function() operation) {
    final next = _volumeOperations.then<void>((_) async {
      try {
        await operation();
      } catch (_) {}
    });
    _volumeOperations = next;
    return next;
  }
}
