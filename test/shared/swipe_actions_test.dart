import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/swipe_actions.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: ListView(children: [child])),
);

SwipeActionData _action(VoidCallback onPressed) => SwipeActionData(
  icon: Icons.delete_outline,
  label: '删除',
  color: Colors.red,
  onPressed: onPressed,
);

void main() {
  testWidgets('向左拖动展开操作，点击执行并收起', (tester) async {
    var tapped = false;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() => tapped = true)],
          child: const SizedBox(height: 60, child: Text('行内容')),
        ),
      ),
    );

    // 慢速向左拖过半程 → 展开并露出操作
    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-60, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除').hitTestable(), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('向右拖动不会展开操作', (tester) async {
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() {})],
          child: const SizedBox(height: 60, child: Text('行内容')),
        ),
      ),
    );

    await tester.timedDrag(
      find.text('行内容'),
      const Offset(80, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('拖过阈值拉长提交默认操作并回弹', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [
            SwipeActionData(
              icon: Icons.delete_outline,
              label: '删除',
              color: Colors.red,
              onPressed: () => fired++,
            ),
          ],
          child: const SizedBox(height: 60, child: Text('行内容')),
        ),
      ),
    );

    // 展开宽度 78 + 触发阈值 44 = 122px，拖 320px 必然越过阈值提交。
    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-320, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    expect(fired, 1);
    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);
  });
}
