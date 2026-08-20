import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/stacked_badges.dart';

Widget _pill(String text) => Container(
      padding: const EdgeInsets.all(6),
      color: const Color(0xFF22C55E),
      child: Text(text),
    );

void main() {
  testWidgets('点按展开为浮层,不影响兄弟徽章位置;点击空白收起', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
          ),
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
}
