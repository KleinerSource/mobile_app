import 'package:flutter/material.dart';

import '../api/server_compatibility.dart';

/// omm 设计令牌 (Brand Spec v5)
///
/// 双版本 · Light + Dark · 系统跟随
/// 多彩集合派 · Inter 字体 · 紫粉 accent
class AppColors {
  AppColors._({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.text2,
    required this.muted,
    required this.muted2,
    required this.accent,
    required this.cardBorder,
    required this.chipBg,
    required this.chipBgActive,
    required this.chipTextActive,
    required this.tabBg,
    required this.tabBorder,
    required this.tabActiveBg,
    required this.tabActiveText,
    required this.glow1,
    required this.glow2,
    required this.divider,
    required this.danger,
    required this.warning,
    required this.sheetBackground,
    required this.sheetBorder,
    required this.sheetHandle,
    required this.sheetBarrier,
  });

  /// Light · 浅灰紫主题
  static final AppColors light = AppColors._(
    bg: const Color(0xFFF3F2F8),
    surface: const Color(0xFFFFFFFF),
    surfaceAlt: const Color(0xFFF2EDE5),
    text: const Color(0xFF1A1A22),
    text2: const Color(0xFF3A3A45),
    muted: const Color(0xFF6E6E7A),
    muted2: const Color(0xFF9A96A8),
    accent: const Color(0xFF7C4DFF),
    cardBorder: const Color(0x0D000000),
    chipBg: const Color(0x0D000000),
    chipBgActive: const Color(0xFF1A1A22),
    chipTextActive: Colors.white,
    tabBg: const Color(0xD9FFFFFF),
    tabBorder: const Color(0x0F000000),
    tabActiveBg: const Color(0xFF1A1A22),
    tabActiveText: Colors.white,
    glow1: const Color(0x8C7C4DFF),
    glow2: const Color(0x8CFF6B9D),
    divider: const Color(0x0F000000),
    danger: const Color(0xFFD93025),
    warning: const Color(0xFFB89968),
    sheetBackground: const Color(0xCCFFFFFF),
    sheetBorder: const Color(0x66FFFFFF),
    sheetHandle: const Color(0x809A96A8),
    sheetBarrier: const Color(0x73000000),
  );

  /// Dark · 墨夜紫粉光晕主题
  static final AppColors dark = AppColors._(
    bg: const Color(0xFF0F0E14),
    surface: const Color(0x0AFFFFFF),
    surfaceAlt: const Color(0x14FFFFFF),
    text: Colors.white,
    text2: const Color(0xFFD8D4E0),
    muted: const Color(0xFF9A96A8),
    muted2: const Color(0xFF6E6A7A),
    accent: const Color(0xFFB888FF),
    cardBorder: const Color(0x0FFFFFFF),
    chipBg: const Color(0x14FFFFFF),
    chipBgActive: Colors.white,
    chipTextActive: const Color(0xFF1A1A22),
    tabBg: const Color(0xD9141220),
    tabBorder: const Color(0x14FFFFFF),
    tabActiveBg: Colors.white,
    tabActiveText: const Color(0xFF1A1A22),
    glow1: const Color(0x2E7C4DFF),
    glow2: const Color(0x2EFF6B9D),
    divider: const Color(0x0FFFFFFF),
    danger: const Color(0xFFFF6B6B),
    warning: const Color(0xFFD4A574),
    sheetBackground: const Color(0xCC1B1A24),
    sheetBorder: const Color(0x33FFFFFF),
    sheetHandle: const Color(0x99FFFFFF),
    sheetBarrier: const Color(0x99000000),
  );

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color text2;
  final Color muted;
  final Color muted2;
  final Color accent;
  final Color cardBorder;
  final Color chipBg;
  final Color chipBgActive;
  final Color chipTextActive;
  final Color tabBg;
  final Color tabBorder;
  final Color tabActiveBg;
  final Color tabActiveText;
  final Color glow1;
  final Color glow2;
  final Color divider;
  final Color danger;
  final Color warning;
  final Color sheetBackground;
  final Color sheetBorder;
  final Color sheetHandle;
  final Color sheetBarrier;

  AppColors withAccent(Color accent) => AppColors._(
    bg: bg,
    surface: surface,
    surfaceAlt: surfaceAlt,
    text: text,
    text2: text2,
    muted: muted,
    muted2: muted2,
    accent: accent,
    cardBorder: cardBorder,
    chipBg: chipBg,
    chipBgActive: chipBgActive,
    chipTextActive: chipTextActive,
    tabBg: tabBg,
    tabBorder: tabBorder,
    tabActiveBg: tabActiveBg,
    tabActiveText: tabActiveText,
    glow1: glow1,
    glow2: glow2,
    divider: divider,
    danger: danger,
    warning: warning,
    sheetBackground: sheetBackground,
    sheetBorder: sheetBorder,
    sheetHandle: sheetHandle,
    sheetBarrier: sheetBarrier,
  );
}

/// 当前媒体管理器的主题强调色，复用服务器头像徽标使用的品牌色。
Color mediaManagerAccentForProject(ServerProject? project) {
  return switch (project) {
    ServerProject.dbOnline => const Color(0xFF0E7490),
    ServerProject.emby => const Color(0xFF52B54B),
    ServerProject.jellyfin => const Color(0xFFAA5CC3),
    ServerProject.feiniu => const Color(0xFF2979FF),
    ServerProject.stash => const Color(0xFF8B5CF6),
    _ => AppColors.light.accent,
  };
}

Color _accentForProject(ServerProject? project, Brightness brightness) {
  if (project == null ||
      project == ServerProject.ohMyMedia ||
      project.isFileSource) {
    return brightness == Brightness.dark
        ? AppColors.dark.accent
        : AppColors.light.accent;
  }
  return mediaManagerAccentForProject(project);
}

Color _onAccent(Color accent) {
  return ThemeData.estimateBrightnessForColor(accent) == Brightness.light
      ? const Color(0xFF1A1A22)
      : Colors.white;
}

@immutable
class AppThemeAccent extends ThemeExtension<AppThemeAccent> {
  const AppThemeAccent(this.color);

  final Color color;

  @override
  AppThemeAccent copyWith({Color? color}) {
    return AppThemeAccent(color ?? this.color);
  }

  @override
  AppThemeAccent lerp(covariant AppThemeAccent? other, double t) {
    if (other == null) return this;
    return AppThemeAccent(Color.lerp(color, other.color, t) ?? color);
  }
}

/// 一个 brightness 配套的 6 个 collection hue —— 用于多彩 collection 卡片 / genre chips。
class AppHues {
  static const int lavender = 270;
  static const int coral = 0;
  static const int mint = 145;
  static const int sky = 220;
  static const int solar = 50;
  static const int magenta = 320;

  static const all = [lavender, coral, mint, sky, solar, magenta];

  /// HSL(h, 70%, 55%) — 卡片主调
  static Color top(int hue) =>
      HSLColor.fromAHSL(1, hue.toDouble(), 0.70, 0.55).toColor();

  /// HSL(h+30, 75%, 35%) — 卡片渐变底
  static Color bottom(int hue) =>
      HSLColor.fromAHSL(1, (hue + 30) % 360, 0.75, 0.35).toColor();

  /// HSL(h, 90%, 70%) 40% alpha — 高光圆球
  static Color highlight(int hue) =>
      HSLColor.fromAHSL(0.4, hue.toDouble(), 0.90, 0.70).toColor();

  /// chip 用 · light: hue 70% 30% / dark: hue 85% 80%
  static Color chipText(int hue, Brightness brightness) {
    return brightness == Brightness.light
        ? HSLColor.fromAHSL(1, hue.toDouble(), 0.70, 0.30).toColor()
        : HSLColor.fromAHSL(1, hue.toDouble(), 0.85, 0.80).toColor();
  }

  /// chip 背景 · 半透 hue
  static Color chipBg(int hue, Brightness brightness) {
    final opacity = brightness == Brightness.light ? 0.18 : 0.25;
    return HSLColor.fromAHSL(opacity, hue.toDouble(), 0.70, 0.55).toColor();
  }

  /// chip 描边 · 半透 hue
  static Color chipBorder(int hue) =>
      HSLColor.fromAHSL(0.4, hue.toDouble(), 0.70, 0.55).toColor();
}

/// 取当前 brightness 对应的色板。
AppColors appColors(BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final accent = theme.extension<AppThemeAccent>()?.color;
  return accent == null ? colors : colors.withAccent(accent);
}

ThemeData buildAppTheme(Brightness brightness, {ServerProject? project}) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final accent = _accentForProject(project, brightness);
  final base = brightness == Brightness.dark
      ? ThemeData.dark()
      : ThemeData.light();

  final textTheme = base.textTheme.apply(
    fontFamily: 'Inter',
    bodyColor: c.text,
    displayColor: c.text,
  );

  // 浮层 (popup menu / dropdown / dialog / bottom sheet) 必须用不透明色 ——
  // 用 surface token (半透白) 在透明 scaffold 上看不见。
  // 用 bg 比真实更亮一档作为浮层底色。
  final Color overlayBg = brightness == Brightness.dark
      ? const Color(0xFF1B1A24)
      : Colors.white;

  return base.copyWith(
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: _onAccent(accent),
      secondary: accent,
      onSecondary: _onAccent(accent),
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.cardBorder,
    ),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: [AppThemeAccent(accent)],
    dividerColor: c.divider,
    iconTheme: IconThemeData(color: c.text),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: c.text,
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
      ),
    ),
    // 浮层一致使用 overlayBg 不透明色 + 强阴影,告别透明无法辨识
    popupMenuTheme: PopupMenuThemeData(
      color: overlayBg,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.cardBorder, width: 1),
      ),
      textStyle: TextStyle(
        color: c.text,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(overlayBg),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: c.cardBorder, width: 1),
          ),
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(overlayBg),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: overlayBg,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.sheetBackground,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.sheetBackground,
      elevation: 0,
      dragHandleColor: c.sheetHandle,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: overlayBg,
      contentTextStyle: TextStyle(
        color: c.text,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: accent,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// 字体相关 helpers —— 与设计稿字号节奏一致。
class AppText {
  AppText._();

  static TextStyle pageTitle(BuildContext c) => TextStyle(
    color: appColors(c).text,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w800,
    fontSize: 28,
    letterSpacing: -0.84,
    height: 1.05,
  );

  static TextStyle sectionTitle(BuildContext c) => TextStyle(
    color: appColors(c).text,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w800,
    fontSize: 20,
    letterSpacing: -0.5,
  );

  static TextStyle cardTitle(BuildContext c) => TextStyle(
    color: appColors(c).text,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 14,
    letterSpacing: -0.14,
    height: 1.2,
  );

  static TextStyle body(BuildContext c) => TextStyle(
    color: appColors(c).text2,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.5,
  );

  static TextStyle meta(BuildContext c) => TextStyle(
    color: appColors(c).muted,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 12,
  );

  /// 影片卡片专用标题/元数据字号，OMM 与其他数据源卡片共用。
  static TextStyle movieCardTitle(BuildContext c) => TextStyle(
    color: appColors(c).text,
    fontFamily: 'Inter',
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static TextStyle movieCardMeta(BuildContext c) => TextStyle(
    color: appColors(c).muted,
    fontFamily: 'Inter',
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
  );

  static TextStyle eyebrow(BuildContext c, {Color? color}) => TextStyle(
    color: color ?? appColors(c).muted,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 0.22 * 11,
    height: 1.2,
  );

  /// 等宽 · 数据 / 角标 / 快捷键
  static TextStyle mono(BuildContext c, {double size = 11, Color? color}) =>
      TextStyle(
        color: color ?? appColors(c).muted,
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
        fontSize: size,
        letterSpacing: size * 0.05,
      );
}
