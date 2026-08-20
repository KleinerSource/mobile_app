import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/stacked_badges.dart';

Widget _pill(String text) => Container(
      padding: const EdgeInsets.all(6),
      color: const Color(0xFF22C55E),
      child: Text(text),
    );

Widget _app({required Widget child, ScrollController? controller}) {
  return MaterialApp(
    home: Scaffold(
      body: controller == null
          ? Align(alignment: Alignment.bottomLeft, child: child)
          : ListView(
              controller: controller,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(alignment: Alignment.centerLeft, child: child),
                ),
                for (var i = 0; i < 30; i++) ListTile(title: Text('ITEM-$i')),
              ],
            ),
    ),
  );
}

void main() {
  testWidgets('点按展开为浮层,不影响兄弟徽章位置;点击空白收起', (tester) async {
    await tester.pumpWidget(
      _app(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StackedBadges(
              tooltip: '规格 ×3（点按展开）',
              children: [for (final t in ['A', 'B', 'C']) _pill(t)],
            ),
            const SizedBox(width: 8),
            _pill('SIBLING'),
          ],
        ),
      ),
    );

    final siblingBefore = tester.getTopRight(find.text('SIBLING'));
    // 收起时后方徽章已在树中(叠加错边)
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    // 点按堆面展开
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    // 兄弟徽章位置不变(展开为浮层,不改变布局占位)
    expect(tester.getTopRight(find.text('SIBLING')), siblingBefore);
    // 浮层出现: 堆面 A 在占位与浮层底部各一次;
    // 收起态错边随展开隐藏,B/C 仅存在于浮层中
    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // 点击空白处收起
    await tester.tapAt(const Offset(600, 100));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(tester.getTopRight(find.text('SIBLING')), siblingBefore);
  });

  testWidgets('单个徽章时直接显示,无叠加交互', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: StackedBadges(children: [_pill('ONLY')]))),
      ),
    );

    expect(find.text('ONLY'), findsOneWidget);
  });

  testWidgets('空分组与空徽章安全渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: StackedBadges(children: []))),
      ),
    );

    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('展开后空白处拖动可正常滚动列表,浮层随之收起', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      _app(
        controller: controller,
        child: StackedBadges(
          tooltip: '规格 ×3（点按展开）',
          children: [for (final t in ['A', 'B', 'C']) _pill(t)],
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // 在列表空白项上起手拖动: 不再被全屏遮罩拦截,列表正常滚动
    await tester.drag(find.text('ITEM-5'), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    // 触摸堆外即收起 (首项已滚出视口, 以浮层构建器消失为准)
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('从浮层徽章上起手拖动即收起,随后的拖动正常滚动', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      _app(
        controller: controller,
        child: StackedBadges(
          tooltip: '规格 ×3（点按展开）',
          children: [for (final t in ['A', 'B', 'C']) _pill(t)],
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // 展开后浮层底部徽章恰好盖住堆面,在其上拖动应立即收起浮层
    await tester.drag(find.text('A').last, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

    // 无需额外点按,下一次拖动即可滚动
    await tester.drag(find.text('ITEM-5'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('从堆面本身起手拖动列表,滚动开始即收起', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      _app(
        controller: controller,
        // 向下展开: 堆面不被浮层遮挡,可直接从堆面拖动列表
        child: StackedBadges(
          tooltip: '规格 ×3（点按展开）',
          expandUpward: false,
          children: [for (final t in ['A', 'B', 'C']) _pill(t)],
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // 堆面在 TapRegion 内,触摸不触发 onTapOutside,由滚动位置监听收起
    await tester.drag(find.text('A').first, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('点开一个堆再点另一个堆,先展开的保持不动(独立开合)', (tester) async {
    await tester.pumpWidget(
      _app(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StackedBadges(
              tooltip: '规格 ×3（点按展开）',
              children: [for (final t in ['A', 'B', 'C']) _pill(t)],
            ),
            const SizedBox(width: 60),
            StackedBadges(
              tooltip: '字幕 ×3（点按展开）',
              children: [for (final t in ['D', 'E', 'F']) _pill(t)],
            ),
          ],
        ),
      ),
    );

    // 点开第一个堆
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNWidgets(2));
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // 点另一个堆: 直接展开第二个,第一个不收起
    await tester.tap(find.text('D'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('D'), findsNWidgets(2));
    expect(find.byType(TweenAnimationBuilder<double>), findsNWidgets(2));

    // 点击空白处两个堆一起收起
    await tester.tapAt(const Offset(600, 100));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('点按浮层内容收起', (tester) async {
    await tester.pumpWidget(
      _app(
        child: StackedBadges(
          tooltip: '规格 ×3（点按展开）',
          children: [for (final t in ['A', 'B', 'C']) _pill(t)],
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // C 仅存在于浮层顶部,点按浮层即收起
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });
}
