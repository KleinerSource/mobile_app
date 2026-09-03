import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/edge_swipe_back.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('左边缘向右滑动触发返回动作', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
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
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
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
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
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

  testWidgets('真实页面栈返回拖动时显示父页，取消后可再次完成返回', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const _PageStackFixture(),
      ),
    );
    await tester.pumpAndSettle();

    final firstDrag = await tester.startGesture(const Offset(2, 300));
    await firstDrag.moveTo(const Offset(100, 300));
    await tester.pump();
    expect(find.text('父页面', skipOffstage: false), findsOneWidget);
    expect(find.text('子页面'), findsOneWidget);
    await firstDrag.moveTo(const Offset(2, 300));
    await firstDrag.up();
    await tester.pumpAndSettle();
    expect(find.text('子页面'), findsOneWidget);

    final secondDrag = await tester.startGesture(const Offset(2, 300));
    await secondDrag.moveTo(const Offset(500, 300));
    await secondDrag.up();
    await tester.pumpAndSettle();
    expect(find.text('父页面'), findsOneWidget);
    expect(find.text('子页面'), findsNothing);
  });
}

class _PageStackFixture extends StatefulWidget {
  const _PageStackFixture();

  @override
  State<_PageStackFixture> createState() => _PageStackFixtureState();
}

class _PageStackFixtureState extends State<_PageStackFixture> {
  bool _showChild = true;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: [
        const MaterialPage<void>(
          key: ValueKey('parent'),
          allowSnapshotting: false,
          child: ColoredBox(
            color: Colors.blue,
            child: Center(child: Text('父页面')),
          ),
        ),
        if (_showChild)
          const MaterialPage<void>(
            key: ValueKey('child'),
            allowSnapshotting: false,
            child: ColoredBox(
              color: Colors.green,
              child: Center(child: Text('子页面')),
            ),
          ),
      ],
      onDidRemovePage: (_) => setState(() => _showChild = false),
    );
  }
}
