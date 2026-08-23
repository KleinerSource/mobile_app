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
  testWidgets('按钮贴卡片尾缘滑入，中途无空隙', (tester) async {
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() {})],
          child: const SizedBox(
            key: ValueKey('card'),
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    // 半展开（60px < 按钮宽 78px）时按住不放：按钮块左缘应与卡片右缘重合。
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('行内容')),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final cardRight = tester.getTopRight(find.byKey(const ValueKey('card'))).dx;
    final iconLeft = tester.getTopLeft(find.byIcon(Icons.delete_outline)).dx;
    // 图标 20px 居中于 78px 磁贴内。
    final tileLeft = iconLeft - (78 - 20) / 2;
    expect(tileLeft, closeTo(cardRight, 1.0));
    await gesture.up();
    await tester.pumpAndSettle();
  });

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

  // 测试视口 800 宽：慢拖提交点 = 拖满整行（800px）；快甩按速度触发。

  testWidgets('拖满整行拉长提交默认操作并回弹', (tester) async {
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

    // 拖到整行宽度，磁贴铺满那一刻提交执行。
    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-800, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(fired, 1);
    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('快速左甩带惯性飞到满宽执行', (tester) async {
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

    await tester.fling(find.text('行内容'), const Offset(-300, 0), 2000);
    await tester.pumpAndSettle();

    expect(fired, 1);
    expect(group.value, isNull);
  });

  testWidgets('未拖满整行滑回不提交（回滑撤销）', (tester) async {
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

    // 拖到 720px（未满 800）后滑回再松手 → 不执行。
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('行内容')),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(-36, 0));
      await tester.pump(const Duration(milliseconds: 10));
    }
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0);
  });
}
