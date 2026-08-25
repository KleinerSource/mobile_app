import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/shared/status_bar_scroll_to_top.dart';

void main() {
  testWidgets('设置页响应 iOS 状态栏点击并滚动到顶部', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsFixedHeaderLayout(
            header: const SizedBox(height: 64),
            body: ListView(
              primary: true,
              children: List.generate(
                40,
                (index) => SizedBox(height: 60, child: Text('$index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(500);
    await tester.pump();
    expect(scrollable.position.pixels, 500);

    final dynamic layoutState = tester.state(
      find.descendant(
        of: find.byType(SettingsFixedHeaderLayout),
        matching: find.byType(StatusBarScrollToTop),
      ),
    );
    layoutState.handleStatusBarTap();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scrollable.position.pixels, greaterThan(0));
    expect(scrollable.position.pixels, lessThan(500));

    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
  });
}
