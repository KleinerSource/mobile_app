import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_scaffold.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
        theme: appTheme(b),
        home: child,
      );

  testWidgets('AppScaffold renders Material Scaffold on light', (tester) async {
    await tester.pumpWidget(wrap(const AppScaffold(body: Text('x'))));
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('AppScaffold renders Material Scaffold on dark', (tester) async {
    await tester.pumpWidget(
        wrap(const AppScaffold(body: Text('x')), b: Brightness.dark));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
