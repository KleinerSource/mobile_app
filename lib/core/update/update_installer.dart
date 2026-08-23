import 'dart:io';

import 'package:flutter/services.dart';

class AndroidUpdateInstaller {
  AndroidUpdateInstaller._();

  static const _channel = MethodChannel('md_center/app_update');

  static Future<bool> install(File apk) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('installApk', <String, Object>{
            'path': apk.path,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }
}

class IosUpdateInstaller {
  IosUpdateInstaller._();

  static Uri installUri(String downloadUrl) {
    return Uri(
      scheme: 'apple-magnifier',
      host: 'install',
      queryParameters: {'url': downloadUrl},
    );
  }
}
