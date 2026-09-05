import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'player_settings.dart';

const double playerOrientationMinAxisAcceleration = 6.5;
const double playerOrientationDominanceRatio = 1.25;

/// 将用户看到的“摄像头在左/右”转换为 Flutter 的横屏枚举。
///
/// Android 的 Flutter 枚举与物理摄像头侧一致；iOS 的横屏方向与物理侧
/// 相反，因此只在 iOS 上交换左右。竖屏方向不需要交换。
DeviceOrientation playerLandscapeOrientationForPlatform(
  PlayerLandscapeSide side, {
  TargetPlatform? platform,
}) {
  final isIos = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  final useLandscapeLeft = isIos
      ? side == PlayerLandscapeSide.cameraRight
      : side == PlayerLandscapeSide.cameraLeft;
  return useLandscapeLeft
      ? DeviceOrientation.landscapeLeft
      : DeviceOrientation.landscapeRight;
}

/// 从加速度计的重力分量推导横屏目标方向。
///
/// 识别四个设备方向；平放或两条轴接近 45 度时返回 null，
/// 让调用方等待下一批更明确的采样。
DeviceOrientation? playerOrientationFromAccelerometer(
  double x,
  double y, {
  TargetPlatform? platform,
  double minAxisAcceleration = playerOrientationMinAxisAcceleration,
  double dominanceRatio = playerOrientationDominanceRatio,
}) {
  if (!x.isFinite || !y.isFinite) return null;

  final absoluteX = x.abs();
  final absoluteY = y.abs();
  final dominantAxis = absoluteX > absoluteY ? absoluteX : absoluteY;
  if (dominantAxis < minAxisAcceleration) return null;

  if (absoluteX >= absoluteY * dominanceRatio) {
    // sensors_plus 在 iOS 侧已将加速度符号对齐 Android；按 Flutter 的
    // DeviceOrientation 定义，逆时针进入 landscapeLeft 时 x 为正值。
    final side = x > 0
        ? PlayerLandscapeSide.cameraLeft
        : PlayerLandscapeSide.cameraRight;
    return playerLandscapeOrientationForPlatform(side, platform: platform);
  }

  if (absoluteY >= absoluteX * dominanceRatio) {
    return y > 0
        ? DeviceOrientation.portraitUp
        : DeviceOrientation.portraitDown;
  }

  return null;
}
