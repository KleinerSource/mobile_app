import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/status_bar_scroll_to_top.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

ListView _longList() {
  return ListView(
    primary: true,
    children: List.generate(
      40,
      (index) => SizedBox(height: 60, child: Text('$index')),
    ),
  );
}

void main() {
  testWidgets('状态栏点击回顶：primary 滚动视图挂接自建控制器', (tester) async {
    await tester.pumpWidget(_wrap(StatusBarScrollToTop(child: _longList())));
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(500);
    await tester.pump();

    final dynamic state = tester.state(find.byType(StatusBarScrollToTop));
    state.handleStatusBarTap();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scrollable.position.pixels, greaterThan(0));
    expect(scrollable.position.pixels, lessThan(500));

    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
  });

  testWidgets('状态栏点击回顶：注入自定义控制器的滚动视图同样生效', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      _wrap(
        StatusBarScrollToTop(
          scrollController: controller,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverFixedExtentList(
                itemExtent: 60,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Text('$index'),
                  childCount: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    controller.jumpTo(500);
    await tester.pump();

    final dynamic state = tester.state(find.byType(StatusBarScrollToTop));
    state.handleStatusBarTap();

    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets('非激活 Tab（ActiveTabScope.active=false）不响应状态栏点击', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ActiveTabScope(
          active: false,
          child: StatusBarScrollToTop(child: _longList()),
        ),
      ),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(500);
    await tester.pump();

    final dynamic state = tester.state(find.byType(StatusBarScrollToTop));
    state.handleStatusBarTap();

    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 500);
  });

  testWidgets('控制器无挂载客户端时点击不抛异常（如双层包裹的壳层）', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusBarScrollToTop(child: SizedBox.expand())),
    );
    await tester.pump();

    final dynamic state = tester.state(find.byType(StatusBarScrollToTop));
    state.handleStatusBarTap();

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('已在顶部时点击为空操作', (tester) async {
    await tester.pumpWidget(_wrap(StatusBarScrollToTop(child: _longList())));
    await tester.pump();

    final dynamic state = tester.state(find.byType(StatusBarScrollToTop));
    state.handleStatusBarTap();

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
