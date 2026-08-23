import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 用户语言偏好
/// - system: 跟随系统 (返回 null 让 MaterialApp 用 supportedLocales 协商)
/// - zh: 简体中文
/// - en: English
enum AppLocale {
  system(value: 'system', label: '跟随系统'),
  zh(value: 'zh', label: '简体中文'),
  en(value: 'en', label: 'English');

  const AppLocale({required this.value, required this.label});
  final String value;
  final String label;

  static AppLocale fromValue(String? v) {
    return AppLocale.values.firstWhere(
      (e) => e.value == v,
      orElse: () => AppLocale.system,
    );
  }

  /// 转成 Flutter Locale · system → null
  Locale? toLocale() {
    switch (this) {
      case AppLocale.system:
        return null;
      case AppLocale.zh:
        return const Locale('zh');
      case AppLocale.en:
        return const Locale('en');
    }
  }
}

class LocaleNotifier extends Notifier<AppLocale> {
  static const _key = 'app.locale';

  @override
  AppLocale build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    return AppLocale.fromValue(raw);
  }

  Future<void> set(AppLocale v) async {
    await ref.read(sharedPrefsProvider).setString(_key, v.value);
    state = v;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);
