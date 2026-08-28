import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';

void main() {
  testWidgets('sheetMaxHeight 为灵动岛设备保留顶部状态栏和更大的余量', (tester) async {
    double? actual;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: Builder(
          builder: (context) {
            actual = sheetMaxHeight(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(actual, 733);
  });

  testWidgets('无滚动内容时，面板内容区下拉会带动面板并在释放后回弹', (tester) async {
    await _pumpSheet(
      tester,
      const SizedBox(
        key: ValueKey('static-sheet-content'),
        height: 140,
        child: Center(child: Text('静态内容')),
      ),
    );

    final initialTop = _sheetTop(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('static-sheet-content'))),
    );
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();

    expect(_sheetTop(tester), greaterThan(initialTop + 40));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_sheetTop(tester), closeTo(initialTop, 0.5));
  });

  testWidgets('滚动列表在顶部时，从内容区下拉会带动面板', (tester) async {
    await _pumpSheet(
      tester,
      ListView.builder(
        key: const ValueKey('top-sheet-list'),
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        itemExtent: 44,
        itemCount: 30,
        itemBuilder: (_, index) => ListTile(title: Text('项目 $index')),
      ),
    );

    final initialTop = _sheetTop(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('top-sheet-list'))),
    );
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();

    expect(_sheetTop(tester), greaterThan(initialTop + 30));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('滚动列表在中部时，下拉仍由列表消费且不会拖动面板', (tester) async {
    await _pumpSheet(
      tester,
      ListView.builder(
        key: const ValueKey('middle-sheet-list'),
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        itemExtent: 44,
        itemCount: 30,
        itemBuilder: (_, index) => ListTile(title: Text('项目 $index')),
      ),
    );

    final list = find.byKey(const ValueKey('middle-sheet-list'));
    await tester.drag(list, const Offset(0, -260));
    await tester.pumpAndSettle();
    final middleTop = _sheetTop(tester);

    final gesture = await tester.startGesture(tester.getCenter(list));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();

    expect(_sheetTop(tester), closeTo(middleTop, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('列表持续下拉到顶部后，同一手势继续下拉会接管面板', (tester) async {
    await _pumpSheet(
      tester,
      ListView.builder(
        key: const ValueKey('handoff-sheet-list'),
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        itemExtent: 44,
        itemCount: 30,
        itemBuilder: (_, index) => ListTile(title: Text('项目 $index')),
      ),
    );

    final list = find.byKey(const ValueKey('handoff-sheet-list'));
    await tester.drag(list, const Offset(0, -260));
    await tester.pumpAndSettle();
    final initialTop = _sheetTop(tester);

    final gesture = await tester.startGesture(tester.getCenter(list));
    await gesture.moveBy(const Offset(0, 350));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();

    expect(_sheetTop(tester), greaterThan(initialTop + 30));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('内容区下拉超过关闭阈值后会关闭面板', (tester) async {
    await _pumpSheet(
      tester,
      const SizedBox(
        key: ValueKey('dismissible-sheet-content'),
        height: 140,
        child: Center(child: Text('可关闭内容')),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('dismissible-sheet-content'))),
    );
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(GlassSheetHandle), findsNothing);
  });
}

Future<void> _pumpSheet(WidgetTester tester, Widget content) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: const ValueKey('open-sheet'),
                onPressed: () {
                  showGlassSheet<void>(
                    context: context,
                    builder: (_) => content,
                  );
                },
                child: const Text('打开面板'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-sheet')));
  await tester.pumpAndSettle();
}

double _sheetTop(WidgetTester tester) {
  return tester.getTopLeft(find.byType(GlassSheetHandle)).dy;
}
