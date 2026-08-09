import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class PlayerPlatformCapabilities {
  static const _channel = MethodChannel('md_center/player_capabilities');
  static Future<void> Function(int positionMs)?
      _pictureInPictureStoppedHandler;

  static Future<bool> enterPictureInPicture({
    required String url,
    Map<String, String>? headers,
    required Duration position,
    bool autoplay = true,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      final arguments = <String, Object?>{
        'url': url,
        'position_ms': position.inMilliseconds,
        'autoplay': autoplay,
        if (headers != null && headers.isNotEmpty) 'headers': headers,
      };
      return await _channel.invokeMethod<bool>(
            'enterPictureInPicture',
            arguments,
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopPictureInPicture() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await _channel.invokeMethod<void>('stopPictureInPicture');
    } on MissingPluginException {
      // Android 当前由 Activity 系统生命周期管理 PiP，无需额外处理。
    } on PlatformException {
      // 原生桥接不可用时不影响播放器退出。
    } catch (_) {}
  }

  static void setPictureInPictureStoppedHandler(
    Future<void> Function(int positionMs) handler,
  ) {
    _pictureInPictureStoppedHandler = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'pictureInPictureStopped') return;
      final callback = _pictureInPictureStoppedHandler;
      if (callback == null) return;
      final arguments = call.arguments;
      final rawPosition = arguments is Map
          ? arguments['position_ms']
          : null;
      final positionMs = rawPosition is num
          ? rawPosition.toInt()
          : int.tryParse(rawPosition?.toString() ?? '') ?? 0;
      await callback(positionMs);
    });
  }

  static void clearPictureInPictureStoppedHandler() {
    _pictureInPictureStoppedHandler = null;
    _channel.setMethodCallHandler(null);
  }
}
