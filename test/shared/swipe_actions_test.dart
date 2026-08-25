import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/swipe_actions.dart';

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

  // 测试视口 800 宽：整行落点与 78px 展开落点的中点为 439px。

  testWidgets('投影越过整行落点中点后提交默认操作', (tester) async {
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

    // 拖动越过展开与整行两个落点的中点，松手后选择整行落点。
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

  testWidgets('短距离快甩只展开操作区，不执行默认动作', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() => fired++)],
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    await tester.fling(find.text('行内容'), const Offset(-120, 0), 2000);
    await tester.pumpAndSettle();

    expect(fired, 0);
    expect(group.value, 1);
    expect(find.text('删除').hitTestable(), findsOneWidget);
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

    // 拖到 240px 后滑回再松手，投影回到普通展开附近，不执行。
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

  testWidgets('越过全滑临界点时只预备，松手后才执行', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() => fired++)],
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('行内容')),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fired, 0);
    await gesture.up();
    expect(fired, 1);
    await tester.pumpAndSettle();
    expect(fired, 1);
  });

  testWidgets('多动作首动作位于尾缘且全滑只执行首动作', (tester) async {
    var firstFired = 0;
    var secondFired = 0;
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
              icon: Icons.delete_forever,
              label: '首动作',
              color: Colors.red,
              onPressed: () => firstFired++,
            ),
            SwipeActionData(
              icon: Icons.archive,
              label: '次动作',
              color: Colors.blue,
              onPressed: () => secondFired++,
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

    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-180, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    final firstLeft = tester.getTopLeft(find.byIcon(Icons.delete_forever)).dx;
    final secondLeft = tester.getTopLeft(find.byIcon(Icons.archive)).dx;
    expect(firstLeft, greaterThan(secondLeft));

    await tester.fling(
      find.byType(SwipeActionCell),
      const Offset(-300, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(firstFired, 1);
    expect(secondFired, 0);
  });

  testWidgets('allowsFullSwipe 为 false 时快速甩动只展开不执行', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          allowsFullSwipe: false,
          actions: [_action(() => fired++)],
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
    expect(fired, 0);
    expect(find.text('删除').hitTestable(), findsOneWidget);
  });

  testWidgets('同组新行开始滑动时立即关闭旧行', (tester) async {
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SwipeActionCell(
                group: group,
                cellKey: 1,
                enabled: true,
                actions: [_action(() {})],
                child: const SizedBox(height: 60, child: Text('第一行')),
              ),
              SwipeActionCell(
                group: group,
                cellKey: 2,
                enabled: true,
                actions: [_action(() {})],
                child: const SizedBox(height: 60, child: Text('第二行')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.text('第一行'),
      const Offset(-100, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(group.value, 1);

    await tester.timedDrag(
      find.text('第二行'),
      const Offset(-100, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(group.value, 2);
  });

  testWidgets('禁用状态不响应滑动', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: false,
          actions: [_action(() => fired++)],
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
    expect(fired, 0);
    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('DragStartBehavior.down 不丢失触摸判定前的首段位移', (tester) async {
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
            key: ValueKey('direct-card'),
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('direct-card'))),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(
      tester.getTopRight(find.byKey(const ValueKey('direct-card'))).dx,
      closeTo(770, 1),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('纵向滚动竞争不展开滑动菜单', (tester) async {
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SwipeActionCell(
                group: group,
                cellKey: 1,
                enabled: true,
                actions: [_action(() {})],
                child: const SizedBox(height: 100, child: Text('可滚动行')),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.text('可滚动行'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
  });

  testWidgets('松手速度反向时投影收起且不提交', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() => fired++)],
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('行内容')),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.moveBy(const Offset(260, 0));
    await tester.pump(const Duration(milliseconds: 8));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0);
    expect(group.value, anyOf(isNull, 1));
  });

  testWidgets('快速全滑松手立即执行，视觉仍继续推进', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() => fired++)],
          child: const SizedBox(
            key: ValueKey('fling-card'),
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    await tester.fling(
      find.byKey(const ValueKey('fling-card')),
      const Offset(-300, 0),
      2000,
    );
    final releasedRight = tester
        .getTopRight(find.byKey(const ValueKey('fling-card')))
        .dx;
    expect(fired, 1);
    await tester.pump(const Duration(milliseconds: 16));
    final nextRight = tester
        .getTopRight(find.byKey(const ValueKey('fling-card')))
        .dx;
    expect(nextRight, lessThan(releasedRight));
    expect(fired, 1);

    await tester.pumpAndSettle();
    expect(fired, 1);
  });

  testWidgets('吸附动画中途可重新抓取并反向收起', (tester) async {
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
      const Offset(-60, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipeActionCell)),
    );
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('展开行点击内容只收起，收起后恢复内容点击', (tester) async {
    var childTaps = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() {})],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => childTaps++,
            child: const SizedBox(
              width: double.infinity,
              height: 60,
              child: Text('行内容'),
            ),
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-60, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 30));
    await tester.pumpAndSettle();
    expect(childTaps, 0);
    expect(group.value, isNull);

    await tester.tap(find.text('行内容'));
    expect(childTaps, 1);
  });

  testWidgets('禁用和动作配置更新会立即收起', (tester) async {
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    var enabled = true;
    var label = '删除';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SwipeActionCell(
                group: group,
                cellKey: 1,
                enabled: enabled,
                actions: [
                  SwipeActionData(
                    icon: Icons.delete_outline,
                    label: label,
                    color: Colors.red,
                    onPressed: () {},
                  ),
                ],
                child: const SizedBox(height: 60, child: Text('行内容')),
              );
            },
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-60, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(group.value, 1);
    update(() => enabled = false);
    await tester.pump();
    expect(group.value, isNull);
    expect(find.text('删除'), findsNothing);

    update(() {
      enabled = true;
      label = '归档';
    });
    await tester.pump();
    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-60, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(find.text('归档').hitTestable(), findsOneWidget);
    update(() => label = '移除');
    await tester.pump();
    expect(group.value, isNull);
    expect(find.text('移除'), findsNothing);
  });

  testWidgets('group 更新会迁移监听并清理旧展开状态', (tester) async {
    final firstGroup = SwipeActionGroup(null);
    final secondGroup = SwipeActionGroup(null);
    addTearDown(firstGroup.dispose);
    addTearDown(secondGroup.dispose);
    var group = firstGroup;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SwipeActionCell(
                group: group,
                cellKey: 1,
                enabled: true,
                actions: [_action(() {})],
                child: const SizedBox(height: 60, child: Text('行内容')),
              );
            },
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-60, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(firstGroup.value, 1);

    update(() => group = secondGroup);
    await tester.pump();
    expect(firstGroup.value, isNull);
    expect(secondGroup.value, isNull);
    expect(find.text('删除'), findsNothing);

    secondGroup.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('删除').hitTestable(), findsOneWidget);
  });

  testWidgets('关闭系统动画时使用短促无回弹吸附', (tester) async {
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SwipeActionCell(
              group: group,
              cellKey: 1,
              enabled: true,
              actions: [_action(() {})],
              child: const SizedBox(height: 60, child: Text('行内容')),
            ),
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.text('行内容'),
      const Offset(-60, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(group.value, 1);
    expect(find.text('删除').hitTestable(), findsOneWidget);
  });

  testWidgets('辅助功能动作可以直接执行回调', (tester) async {
    var fired = 0;
    final group = SwipeActionGroup(null);
    addTearDown(group.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        SwipeActionCell(
          group: group,
          cellKey: 1,
          enabled: true,
          actions: [_action(() => fired++)],
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Text('行内容'),
          ),
        ),
      ),
    );

    tester.semantics.customAction(
      find.semantics.byLabel('行内容'),
      const CustomSemanticsAction(label: '删除'),
    );
    await tester.pumpAndSettle();
    expect(fired, 1);
    semantics.dispose();
  });
}
