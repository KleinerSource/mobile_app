import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_chip_row.dart';
import 'package:md_center/core/ui/app_search_field.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('AppSearchField shows placeholder', (tester) async {
    await tester.pumpWidget(wrap(AppSearchField(
      placeholder: '搜索片名',
      onSubmitted: (_) {},
    )));
    expect(find.text('搜索片名'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('AppSearchField onSubmitted fires with value', (tester) async {
    String? submitted;
    await tester.pumpWidget(wrap(AppSearchField(
      placeholder: 'p',
      onSubmitted: (v) => submitted = v,
    )));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, 'hello');
  });

  testWidgets('AppChipRow renders chips and fires onTap with index',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: AppChipRow(
        labels: const ['全部', '未看', '收藏'],
        activeIndex: 0,
        onTap: (i) => tapped = i,
      ),
    )));
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    await tester.tap(find.text('收藏'));
    expect(tapped, 2);
  });
}
