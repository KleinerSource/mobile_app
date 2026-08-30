import '../../../core/platform/app_haptics.dart';

/// 播放器触觉反馈。将平台调用统一封装，避免手势回调遗漏 Future 处理。
abstract final class PlayerHaptics {
  static void selection() => AppHaptics.selection();

  static void light() => AppHaptics.light();

  static void medium() => AppHaptics.medium();
}
