import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 主题模式 · 跟随系统 / 亮色 / 暗色
enum AppThemeMode {
  system(value: 'system'),
  light(value: 'light'),
  dark(value: 'dark');

  const AppThemeMode({required this.value});
  final String value;

  static AppThemeMode fromValue(String? v) {
    return AppThemeMode.values.firstWhere(
      (e) => e.value == v,
      orElse: () => AppThemeMode.system,
    );
  }

  ThemeMode toMaterial() {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'app.themeMode';

  @override
  AppThemeMode build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    return AppThemeMode.fromValue(raw);
  }

  Future<void> set(AppThemeMode v) async {
    await ref.read(sharedPrefsProvider).setString(_key, v.value);
    state = v;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);
