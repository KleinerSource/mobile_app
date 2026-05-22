import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_bottom_nav.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(bottomNavigationBar: child, body: const SizedBox()),
      );

  testWidgets('renders 5 labels', (tester) async {
    await tester.pumpWidget(wrap(AppBottomNav(
      currentIndex: 0,
      onTap: (_) {},
      onMoreTap: () {},
    )));
    expect(find.text('仪表板'), findsOneWidget);
    expect(find.text('影片'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('tap on non-more tab fires onTap with index', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(wrap(AppBottomNav(
      currentIndex: 0,
      onTap: (i) => tappedIndex = i,
      onMoreTap: () {},
    )));
    await tester.tap(find.text('影片'));
    expect(tappedIndex, 1);
    await tester.tap(find.text('设置'));
    expect(tappedIndex, 4);
  });

  testWidgets('tap on More fires onMoreTap not onTap', (tester) async {
    int? tappedIndex;
    var moreCount = 0;
    await tester.pumpWidget(wrap(AppBottomNav(
      currentIndex: 0,
      onTap: (i) => tappedIndex = i,
      onMoreTap: () => moreCount++,
    )));
    await tester.tap(find.text('更多'));
    expect(moreCount, 1);
    expect(tappedIndex, isNull);
  });
}
