import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HapticIntensity {
  off('off', '关闭'),
  low('low', '轻'),
  standard('standard', '标准'),
  high('high', '强');

  const HapticIntensity(this.storageValue, this.label);

  final String storageValue;
  final String label;

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
    _intensity = HapticIntensity.fromStorage(
      prefs.getString(preferenceKey),
    );
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
    _send(_selectionEffect());
  }

  static void light() {
    if (_intensity == HapticIntensity.off) return;
    _send(_lightEffect());
  }

  static void medium() {
    if (_intensity == HapticIntensity.off) return;
    _send(_mediumEffect());
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

  static Future<void> _selectionEffect() {
    return switch (_intensity) {
      HapticIntensity.off => Future<void>.value(),
      HapticIntensity.low => HapticFeedback.selectionClick(),
      HapticIntensity.standard => HapticFeedback.lightImpact(),
      HapticIntensity.high => HapticFeedback.mediumImpact(),
    };
  }

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
