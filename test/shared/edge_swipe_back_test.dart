import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/edge_swipe_back.dart';

void main() {
  testWidgets('左边缘向右滑动触发返回动作', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EdgeSwipeBack(
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveTo(const Offset(100, 300));
    await gesture.up();

    expect(triggered, 1);
  });

  testWidgets('非左边缘、向左或垂直滑动不触发返回动作', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EdgeSwipeBack(
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final outsideEdge = await tester.startGesture(const Offset(80, 300));
    await outsideEdge.moveTo(const Offset(180, 300));
    await outsideEdge.up();

    final leftward = await tester.startGesture(const Offset(2, 300));
    await leftward.moveTo(const Offset(-100, 300));
    await leftward.up();

    final vertical = await tester.startGesture(const Offset(2, 300));
    await vertical.moveTo(const Offset(35, 430));
    await vertical.up();

    expect(triggered, 0);
  });

  testWidgets('未启用时不触发返回动作', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EdgeSwipeBack(
          enabled: false,
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveTo(const Offset(100, 300));
    await gesture.up();

    expect(triggered, 0);
  });
}
