import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_scaffold.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
        theme: appTheme(b),
        home: child,
      );

  testWidgets('AppScaffold renders Scaffold and child', (tester) async {
    await tester.pumpWidget(wrap(
      const AppScaffold(body: Text('hello')),
    ));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('AppPage shows title and subtitle', (tester) async {
    await tester.pumpWidget(wrap(
      const AppPage(
        title: '影片库',
        subtitle: '2341 部',
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 100))],
      ),
    ));
    expect(find.text('影片库'), findsOneWidget);
    expect(find.text('2341 部'), findsOneWidget);
  });

  testWidgets('AppPage without subtitle does not crash', (tester) async {
    await tester.pumpWidget(wrap(
      const AppPage(
        title: '设置',
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 100))],
      ),
    ));
    expect(find.text('设置'), findsOneWidget);
  });
}
