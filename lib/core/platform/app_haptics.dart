import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 应用级触觉反馈。
///
/// 只在状态切换、选择、提交和播放器操作等有明确结果的交互中调用，
/// 普通点击（例如播放器显隐控制栏）不触发反馈。
abstract final class AppHaptics {
  static DateTime? _lastSelectionAt;

  static void selection() {
    final now = DateTime.now();
    final previous = _lastSelectionAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 35)) {
      return;
    }
    _lastSelectionAt = now;
    _send(HapticFeedback.selectionClick());
  }

  static void light() => _send(HapticFeedback.lightImpact());

  static void medium() => _send(HapticFeedback.mediumImpact());

  /// 为开关统一添加反馈，禁用状态保持原来的 null 回调语义。
  static ValueChanged<bool>? wrapToggle(ValueChanged<bool>? onChanged) {
    if (onChanged == null) return null;
    return (value) {
      selection();
      onChanged(value);
    };
  }

  static void _send(Future<void> effect) {
    unawaited(effect.catchError((_) {}));
  }
}
