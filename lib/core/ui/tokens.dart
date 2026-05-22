import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceVariant,
    required this.text,
    required this.textMuted,
    required this.divider,
    required this.tabBarBg,
    required this.tabBarBorder,
    required this.tabIdle,
    required this.posterBorder,
    required this.progressTrack,
    required this.shade,
    required this.brand,
    required this.brandOn,
    required this.badgeUpdated,
    required this.badgeFavorited,
    required this.badgeCompleted,
    required this.badgeSubtitle,
  });

  final Color bg;
  final Color surface;
  final Color surfaceVariant;
  final Color text;
  final Color textMuted;
  final Color divider;
  final Color tabBarBg;
  final Color tabBarBorder;
  final Color tabIdle;
  final Color posterBorder;
  final Color progressTrack;
  final Color shade;
  final Color brand;
  final Color brandOn;
  final Color badgeUpdated;
  final Color badgeFavorited;
  final Color badgeCompleted;
  final Color badgeSubtitle;

  static const _brand = Color(0xFF4F6DF0);
  static const _brandOn = Color(0xFFFFFFFF);
  static const _badgeUpdated = Color(0xFFF59E0B);
  static const _badgeFavorited = Color(0xFFEF4444);
  static const _badgeCompleted = Color(0xFF14B8A6);
  static const _badgeSubtitle = Color(0xFFF59E0B);

  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F6),
    surfaceVariant: Color(0xFFECECEF),
    text: Color(0xFF0F0F14),
    textMuted: Color(0xFF6B6B75),
    divider: Color(0x14000000),
    tabBarBg: Color(0xFFFFFFFF),
    tabBarBorder: Color(0x14000000),
    tabIdle: Color(0xFF8A8A92),
    posterBorder: Color(0x0F000000),
    progressTrack: Color(0x1F000000),
    shade: Color(0xB8000000),
    brand: _brand,
    brandOn: _brandOn,
    badgeUpdated: _badgeUpdated,
    badgeFavorited: _badgeFavorited,
    badgeCompleted: _badgeCompleted,
    badgeSubtitle: _badgeSubtitle,
  );

  static const dark = AppColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF1A1A1C),
    surfaceVariant: Color(0xFF2A2A2E),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF98989F),
    divider: Color(0x1AFFFFFF),
    tabBarBg: Color(0xFF111113),
    tabBarBorder: Color(0x1AFFFFFF),
    tabIdle: Color(0xFF7A7A82),
    posterBorder: Color(0x0FFFFFFF),
    progressTrack: Color(0x2EFFFFFF),
    shade: Color(0xC7000000),
    brand: _brand,
    brandOn: _brandOn,
    badgeUpdated: _badgeUpdated,
    badgeFavorited: _badgeFavorited,
    badgeCompleted: _badgeCompleted,
    badgeSubtitle: _badgeSubtitle,
  );

  static AppColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => this;
}

class AppRadius {
  static const double poster = 10;
  static const double card = 12;
  static const double pill = 999;
  static const double badge = 4;
}

class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}
