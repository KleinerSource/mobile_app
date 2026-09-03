import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/audio/audio_player_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('亮色播放器使用纯白背景和黑色系统栏图标', (tester) async {
    await _pumpTheme(tester, Brightness.light);

    _expectTheme(
      tester,
      background: Colors.white,
      foreground: Colors.black,
      iconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );
  });

  testWidgets('暗色播放器使用纯黑背景和白色系统栏图标', (tester) async {
    await _pumpTheme(tester, Brightness.dark);

    _expectTheme(
      tester,
      background: Colors.black,
      foreground: Colors.white,
      iconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );
  });
}

Future<void> _pumpTheme(WidgetTester tester, Brightness brightness) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      locale: const Locale('zh'),
      theme: ThemeData(brightness: brightness),
      home: const AudioPlayerTheme(child: SafeArea(child: SizedBox.expand())),
    ),
  );
}

void _expectTheme(
  WidgetTester tester, {
  required Color background,
  required Color foreground,
  required Brightness iconBrightness,
  required Brightness statusBarBrightness,
}) {
  final playerTheme = tester.widget<Theme>(
    find.descendant(
      of: find.byType(AudioPlayerTheme),
      matching: find.byType(Theme),
    ),
  );
  final data = playerTheme.data;
  expect(data.scaffoldBackgroundColor, background);
  expect(data.canvasColor, background);
  expect(data.colorScheme.surface, background);
  expect(data.colorScheme.onSurface, foreground);
  expect(data.colorScheme.primary, foreground);

  final paintedBackground = tester.widget<ColoredBox>(
    find.descendant(
      of: find.byType(AudioPlayerTheme),
      matching: find.byType(ColoredBox),
    ),
  );
  expect(paintedBackground.color, background);

  final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.descendant(
      of: find.byType(AudioPlayerTheme),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    ),
  );
  final style = region.value;
  expect(style.statusBarColor, background);
  expect(style.systemNavigationBarColor, background);
  expect(style.systemNavigationBarDividerColor, background);
  expect(style.statusBarIconBrightness, iconBrightness);
  expect(style.systemNavigationBarIconBrightness, iconBrightness);
  expect(style.statusBarBrightness, statusBarBrightness);
  expect(style.systemNavigationBarContrastEnforced, isFalse);
}
