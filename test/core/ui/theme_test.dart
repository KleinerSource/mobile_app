import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/tokens.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  test('AppColors.of returns light tokens for Brightness.light', () {
    final c = AppColors.of(Brightness.light);
    expect(c.bg, const Color(0xFFFFFFFF));
    expect(c.text, const Color(0xFF0F0F14));
    expect(c.brand, const Color(0xFF4F6DF0));
  });

  test('AppColors.of returns dark tokens for Brightness.dark', () {
    final c = AppColors.of(Brightness.dark);
    expect(c.bg, const Color(0xFF000000));
    expect(c.text, const Color(0xFFFFFFFF));
    expect(c.brand, const Color(0xFF4F6DF0));
  });

  test('AppColors badge state colors are identical across themes', () {
    final l = AppColors.of(Brightness.light);
    final d = AppColors.of(Brightness.dark);
    expect(l.badgeUpdated, d.badgeUpdated);
    expect(l.badgeFavorited, d.badgeFavorited);
    expect(l.badgeCompleted, d.badgeCompleted);
    expect(l.badgeSubtitle, d.badgeSubtitle);
  });

  test('appTheme light brightness is light and scaffoldBackground=bg', () {
    final t = appTheme(Brightness.light);
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, AppColors.light.bg);
  });

  test('appTheme dark brightness is dark and scaffoldBackground=bg', () {
    final t = appTheme(Brightness.dark);
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, AppColors.dark.bg);
  });

  testWidgets('Theme.of(context).extension<AppColors>() resolves',
      (tester) async {
    AppColors? captured;
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(Brightness.light),
      home: Builder(builder: (ctx) {
        captured = Theme.of(ctx).extension<AppColors>();
        return const SizedBox();
      }),
    ));
    expect(captured, isNotNull);
    expect(captured!.brand, AppColors.light.brand);
  });
}
