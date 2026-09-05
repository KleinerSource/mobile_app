import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('sheetMaxHeight 为灵动岛设备保留顶部状态栏和更大的余量', (tester) async {
    double? actual;
    double? minimum;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: Builder(
          builder: (context) {
            actual = sheetMaxHeight(context);
            minimum = sheetMinHeight(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(actual, 733);
    expect(minimum, closeTo(337.6, 0.1));
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

  testWidgets('键盘弹出后，面板底部会避让键盘', (tester) async {
    await _pumpSheet(
      tester,
      const SizedBox(
        key: ValueKey('keyboard-sheet-content'),
        height: 140,
        child: Center(child: Text('输入内容')),
      ),
    );

    final view = tester.view;
    final originalViewInsets = view.viewInsets;
    final keyboardHeight = 300.0;
    view.viewInsets = FakeViewPadding(
      bottom: keyboardHeight * view.devicePixelRatio,
    );

    try {
      await tester.pumpAndSettle();

      final screenHeight = view.physicalSize.height / view.devicePixelRatio;
      final keyboardTop = screenHeight - keyboardHeight;
      expect(
        tester.getBottomLeft(find.byType(GlassPanel)).dy,
        lessThanOrEqualTo(keyboardTop),
      );
    } finally {
      view.viewInsets = originalViewInsets;
      await tester.pumpAndSettle();
    }
  });

  testWidgets('内容尺寸变化时面板平滑展开而非瞬间跳变', (tester) async {
    final grown = ValueNotifier(false);
    addTearDown(grown.dispose);
    await _pumpSheet(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: grown,
        builder: (_, value, __) => SizedBox(
          key: ValueKey(value ? 'grown-content' : 'small-content'),
          height: value ? 360 : 140,
          child: Center(child: Text(value ? '已补全' : '加载中')),
        ),
      ),
    );

    final smallTop = _sheetTop(tester);
    final smallBottom = tester.getBottomLeft(find.byType(GlassPanel)).dy;

    // 模拟异步数据到达后内容长高 220。首帧仅启动尺寸动画,再推进时间
    // 进入动画中间态:顶边应已上移但尚未到达最终位置。
    grown.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final midTop = _sheetTop(tester);
    expect(midTop, lessThan(smallTop));
    expect(midTop, greaterThan(smallTop - 220));
    expect(tester.getBottomLeft(find.byType(GlassPanel)).dy, smallBottom);

    await tester.pumpAndSettle();
    expect(smallTop - _sheetTop(tester), closeTo(220, 0.5));
    expect(tester.getBottomLeft(find.byType(GlassPanel)).dy, smallBottom);
  });

  testWidgets('指定最小高度时，短内容面板不会低于最小展示高度', (tester) async {
    await _pumpSheet(
      tester,
      const SizedBox(height: 40, child: Text('加载中')),
      minHeight: 300,
    );

    expect(tester.getSize(find.byType(GlassPanel)).height, closeTo(300, 0.5));
  });

  testWidgets('最小高度不会把带 Flexible 的短列表撑到最大高度', (tester) async {
    await _pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: const [SizedBox(height: 40)],
            ),
          ),
        ],
      ),
      minHeight: 300,
    );

    expect(tester.getSize(find.byType(GlassPanel)).height, closeTo(300, 0.5));
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

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget content, {
  double? minHeight,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: const ValueKey('open-sheet'),
                onPressed: () {
                  showGlassSheet<void>(
                    context: context,
                    minHeight: minHeight,
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
