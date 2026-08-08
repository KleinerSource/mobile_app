import 'dart:async';

import 'package:flutter/services.dart';

/// 播放器触觉反馈。将平台调用统一封装，避免手势回调遗漏 Future 处理。
abstract final class PlayerHaptics {
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

  static void _send(Future<void> effect) {
    unawaited(effect.catchError((_) {}));
  }
}
