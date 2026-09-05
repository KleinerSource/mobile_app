import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'player_settings.dart';

const double playerOrientationMinAxisAcceleration = 6.5;
const double playerOrientationDominanceRatio = 1.25;

/// 将用户看到的“摄像头在左/右”转换为平台实际需要的横屏枚举。
///
/// Android 当前与 Flutter 的横屏枚举方向一致；iOS 的 UIKit 方向命名在
/// 设备物理侧表现相反，因此这里只对 iOS 做适配。
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
/// 这里只返回左右横屏；竖屏、倒置、平放或两条轴接近 45 度时返回 null，
/// 让调用方等待下一批更明确的横屏采样。
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
    final side = x < 0
        ? PlayerLandscapeSide.cameraLeft
        : PlayerLandscapeSide.cameraRight;
    return playerLandscapeOrientationForPlatform(side, platform: platform);
  }

  return null;
}
