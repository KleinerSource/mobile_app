import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 音频播放器专用单色主题。
///
/// 文件管理器使用带紫粉色氛围光的全局主题，音频播放器则保持独立的
/// 黑白视觉。系统栏和播放器内容共用同一个背景色，避免安全区出现断层。
class AudioPlayerTheme extends StatelessWidget {
  const AudioPlayerTheme({super.key, required this.child});

  final Widget child;

  static Color backgroundFor(Brightness brightness) {
    return brightness == Brightness.dark ? Colors.black : Colors.white;
  }

  static Color foregroundFor(Brightness brightness) {
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  static ThemeData data(BuildContext context) {
    final parent = Theme.of(context);
    final background = backgroundFor(parent.brightness);
    final foreground = foregroundFor(parent.brightness);
    final textTheme = parent.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
      decorationColor: foreground,
    );
    final popupTextStyle =
        (parent.popupMenuTheme.textStyle ??
                textTheme.labelLarge ??
                const TextStyle())
            .copyWith(color: foreground);

    return parent.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: parent.colorScheme.copyWith(
        primary: foreground,
        onPrimary: background,
        secondary: foreground,
        onSecondary: background,
        surface: background,
        onSurface: foreground,
        onSurfaceVariant: foreground,
        outline: foreground.withValues(alpha: 0.24),
        outlineVariant: foreground.withValues(alpha: 0.12),
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: parent.iconTheme.copyWith(color: foreground),
      popupMenuTheme: parent.popupMenuTheme.copyWith(
        color: background,
        surfaceTintColor: Colors.transparent,
        textStyle: popupTextStyle,
      ),
    );
  }

  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final background = backgroundFor(brightness);
    final iconBrightness = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: background,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: background,
      systemNavigationBarContrastEnforced: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: data(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyleFor(brightness),
        child: ColoredBox(color: backgroundFor(brightness), child: child),
      ),
    );
  }
}
