import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class PlayerPlatformCapabilities {
  static const _channel = MethodChannel('md_center/player_capabilities');

  static Future<bool> enterPictureInPicture() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPictureInPicture') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
