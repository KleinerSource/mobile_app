import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/l10n/generated/app_localizations.dart';

enum HapticIntensity {
  off('off'),
  low('low'),
  standard('standard'),
  high('high');

  const HapticIntensity(this.storageValue);

  final String storageValue;

  String label(AppL10n l) => switch (this) {
    HapticIntensity.off => l.hapticIntensityOff,
    HapticIntensity.low => l.hapticIntensityLow,
    HapticIntensity.standard => l.hapticIntensityStandard,
    HapticIntensity.high => l.hapticIntensityHigh,
  };

  static HapticIntensity fromStorage(String? value) {
    for (final intensity in values) {
      if (intensity.storageValue == value) return intensity;
    }
    return HapticIntensity.standard;
  }
}

/// 应用级触觉反馈。
///
/// 只在状态切换、选择、提交和播放器操作等有明确结果的交互中调用，
/// 普通点击（例如播放器显隐控制栏）不触发反馈。
abstract final class AppHaptics {
  static const preferenceKey = 'app.haptic_intensity';

  static DateTime? _lastSelectionAt;
  static HapticIntensity _intensity = HapticIntensity.standard;

  static HapticIntensity get intensity => _intensity;

  static void setIntensity(HapticIntensity intensity) {
    _intensity = intensity;
  }

  static void configureFromPreferences(SharedPreferences prefs) {
    _intensity = HapticIntensity.fromStorage(prefs.getString(preferenceKey));
  }

  static void selection() {
    if (_intensity == HapticIntensity.off) return;
    final now = DateTime.now();
    final previous = _lastSelectionAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 35)) {
      return;
    }
    _lastSelectionAt = now;
    _send(_lightEffect());
  }

  static void light() {
    if (_intensity == HapticIntensity.off) return;
    _send(_lightEffect());
  }

  static void medium() {
    if (_intensity == HapticIntensity.off) return;
    _send(_mediumEffect());
  }

  /// 输入校验失败等错误场景的重震动反馈，不受强度设置降级。
  static void error() {
    if (_intensity == HapticIntensity.off) return;
    _send(switch (_intensity) {
      HapticIntensity.low => HapticFeedback.mediumImpact(),
      _ => HapticFeedback.heavyImpact(),
    });
  }

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

  /// 轻反馈（selection/light 共用）的档位映射：选择反馈额外带 35ms 节流。
  static Future<void> _lightEffect() {
    return switch (_intensity) {
      HapticIntensity.off => Future<void>.value(),
      HapticIntensity.low => HapticFeedback.selectionClick(),
      HapticIntensity.standard => HapticFeedback.lightImpact(),
      HapticIntensity.high => HapticFeedback.mediumImpact(),
    };
  }

  static Future<void> _mediumEffect() {
    return switch (_intensity) {
      HapticIntensity.off => Future<void>.value(),
      HapticIntensity.low => HapticFeedback.lightImpact(),
      HapticIntensity.standard => HapticFeedback.mediumImpact(),
      HapticIntensity.high => HapticFeedback.heavyImpact(),
    };
  }
}
