import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_badge.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('AppBadge shows icon and label', (tester) async {
    await tester.pumpWidget(wrap(const AppBadge(
      icon: Icons.refresh,
      label: '已更新',
      background: Color(0xFFF59E0B),
    )));
    expect(find.text('已更新'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('AppBadge without label only shows icon', (tester) async {
    await tester.pumpWidget(wrap(const AppBadge(
      icon: Icons.closed_caption_outlined,
      background: Color(0xFFF59E0B),
    )));
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });
}
