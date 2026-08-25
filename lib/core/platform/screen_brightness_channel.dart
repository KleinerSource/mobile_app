import 'package:flutter/services.dart';

/// 轻量亮度通道，是全 app 唯一的亮度读写入口。
///
/// - iOS：直接读写 `UIScreen.brightness`，即系统亮度本身。手势写入后
///   全局立即生效并自然保持——关闭播放器、退出 app 都不做任何恢复。
/// - Android：读写当前窗口的 `screenBrightness` 覆盖值（无权限要求，
///   不触碰系统设置；无覆盖时回退读取系统设置值）。
///
/// 有意不引入缓存、不监听生命周期、不提供恢复接口：除播放器手势外
/// 任何阶段都不允许改写设备亮度，避免后台/切换时的异常跳变。
class ScreenBrightnessChannel {
  ScreenBrightnessChannel._();

  static const MethodChannel _channel = MethodChannel(
    'omm/screen_brightness',
  );

  /// 当前亮度 (0.0–1.0)。平台未实现或读取失败时返回 null，
  /// 调用方应保留自己的默认值。
  static Future<double?> read() async {
    try {
      final value = await _channel.invokeMethod<double>('getBrightness');
      if (value == null) return null;
      return value.clamp(0.0, 1.0);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 设置亮度 (0.0–1.0)。设置失败静默处理：手势调节不应弹错打断播放。
  static Future<void> set(double brightness) async {
    try {
      await _channel.invokeMethod<void>('setBrightness', {
        'brightness': brightness.clamp(0.0, 1.0),
      });
    } on PlatformException {
      // 忽略：亮度写入失败不影响播放。
    } on MissingPluginException {
      // 忽略：平台未实现（桌面端等）时手势降级为空操作。
    }
  }
}
