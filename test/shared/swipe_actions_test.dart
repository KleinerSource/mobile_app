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
            width: double.infinity,
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

  testWidgets('已展开行拖回一部分松手后回弹吸附，不卡在松手位置', (tester) async {
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
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    final cell = find.byType(SwipeActionCell);
    // 慢速拖到展开。
    await tester.timedDrag(
      cell,
      const Offset(-150, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(group.value, 1);

    // 已展开状态下往回拖一点（仍在展开区间），松手必须回弹到完全展开。
    await tester.timedDrag(
      cell,
      const Offset(24, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(group.value, 1);
    // 完全展开：磁贴左缘 = 行宽 800 - 按钮宽 78。
    final iconLeft = tester.getTopLeft(find.byIcon(Icons.delete_outline)).dx;
    expect(iconLeft - (78 - 20) / 2, closeTo(800 - 78, 1.0));
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
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
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
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
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

  // 测试视口 800 宽：慢拖提交点 = max(78+44, 800×55%) = 440px；快甩按速度触发。

  testWidgets('拖过提交点（行宽 55%）拉长提交默认操作', (tester) async {
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
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    // 拖 520px（扣除触摸判定消耗约 24px 后仍越过 440px 提交点），
    // 磁贴拉长越点即提交。
    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-520, 0),
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
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    await tester.fling(find.text('行内容'), const Offset(-300, 0), 2000);
    await tester.pumpAndSettle();

    expect(fired, 1);
    expect(group.value, isNull);
  });

  testWidgets('未过提交点滑回不提交（回滑撤销）', (tester) async {
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
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    // 拖到 240px（提交点 = max(78+44, 800×55%) = 440px）后滑回再松手 → 不执行。
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('行内容')),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 10));
    }
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0);
  });
}
