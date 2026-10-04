import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/floating_tab_bar.dart';

void main() {
  const icons = [
    Icons.home_rounded,
    Icons.leaderboard_outlined,
    Icons.video_library_rounded,
    Icons.search_rounded,
    Icons.settings_outlined,
  ];

  List<FloatingTabSpec<int>> specs(int count) => [
    for (var i = 0; i < count; i++)
      FloatingTabSpec<int>(label: '标签$i', icon: icons[i]),
  ];

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: const SizedBox.expand(), bottomNavigationBar: child),
  );

  testWidgets('五格导航自动把中间项渲染为圆形仅图标按钮', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      host(
        FloatingTabBar<int>(
          tabs: specs(5),
          active: 2,
          onTap: (index) => tapped = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 中间项（第 3 格）即使激活也只显示图标，不出现标题文字。
    expect(find.text('标签2'), findsNothing);
    // 点按胶囊正中命中中间圆形按钮。
    await tester.tap(find.byType(FloatingTabBar<int>));
    expect(tapped, 2);
  });

  testWidgets('五格导航其余项激活时仍显示图标与标题', (tester) async {
    await tester.pumpWidget(
      host(FloatingTabBar<int>(tabs: specs(5), active: 0, onTap: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('标签0'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('四格以内导航不出现圆形中间按钮', (tester) async {
    await tester.pumpWidget(
      host(FloatingTabBar<int>(tabs: specs(4), active: 1, onTap: (_) {})),
    );
    await tester.pumpAndSettle();

    // 四格布局没有正中间项，激活项正常带出标题。
    expect(find.text('标签1'), findsOneWidget);
  });
}
