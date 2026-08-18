import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/drag_selection.dart';

void main() {
  testWidgets('长按未选条目后滑动会连续添加且不会漏选', (tester) async {
    await _pumpHarness(tester, itemCount: 20);

    final gesture = await _longPress(tester, _target(0));
    final state = _harnessState(tester);
    expect(state.selected, {0});

    await gesture.moveTo(tester.getCenter(_target(6)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1, 2, 3, 4, 5, 6});
    expect(state.selectionEndCount, 1);
  });

  testWidgets('长按已选条目后沿途取消并回滑不会重复切换', (tester) async {
    await _pumpHarness(tester, itemCount: 20);

    var gesture = await _longPress(tester, _target(0));
    await gesture.moveTo(tester.getCenter(_target(6)));
    await gesture.up();
    await tester.pump();

    gesture = await _dragFromHandle(tester, _target(2));
    final secondStart = _handlePosition(tester, _target(2));
    await gesture.moveTo(secondStart + const Offset(12, 32));
    final state = _harnessState(tester);
    expect(state.selected, {0, 1, 3, 4, 5, 6});

    await gesture.moveTo(tester.getCenter(_target(6)));
    await tester.pump();
    expect(state.selected, {0, 1});

    await gesture.moveTo(tester.getCenter(_target(3)));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(_target(6)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1});
  });

  testWidgets('自动滚动跟随边缘方向并在边界停止', (tester) async {
    await _pumpHarness(tester, itemCount: 80, viewportHeight: 240);
    final controller = _harnessState(tester).controller;

    final gesture = await _longPress(tester, _target(2));
    await gesture.moveTo(const Offset(120, 232));
    await _pumpFrames(tester, const Duration(milliseconds: 400));
    final bottomOffset = controller.offset;
    expect(bottomOffset, greaterThan(0));

    await gesture.moveTo(const Offset(120, 8));
    await _pumpFrames(tester, const Duration(milliseconds: 250));
    expect(controller.offset, lessThan(bottomOffset));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('自动滚动到末端后分页增加范围可以继续滚动', (tester) async {
    await _pumpHarness(tester, itemCount: 12, viewportHeight: 240);
    final state = _harnessState(tester);
    final gesture = await _longPress(tester, _target(2));
    await gesture.moveTo(const Offset(120, 232));
    await _pumpFrames(tester, const Duration(seconds: 2));

    final oldMax = state.controller.position.maxScrollExtent;
    expect(state.controller.offset, closeTo(oldMax, 1));

    state.addItems(20);
    await tester.pump();
    await _pumpFrames(tester, const Duration(milliseconds: 400));

    expect(state.controller.offset, greaterThan(oldMax));
    await gesture.up();
    await tester.pump();
  });

  testWidgets('抬起后结束滑动并停止自动滚动', (tester) async {
    await _pumpHarness(tester, itemCount: 40, viewportHeight: 240);
    final state = _harnessState(tester);
    final gesture = await _longPress(tester, _target(1));
    await gesture.moveTo(const Offset(120, 232));
    await _pumpFrames(tester, const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump();

    final offset = state.controller.offset;
    await _pumpFrames(tester, const Duration(milliseconds: 500));
    expect(state.controller.offset, closeTo(offset, 0.01));
    expect(state.selectionEndCount, 1);
  });

  testWidgets('取消手势也会结束滑动并停止自动滚动', (tester) async {
    await _pumpHarness(tester, itemCount: 40, viewportHeight: 240);
    final state = _harnessState(tester);
    final gesture = await _longPress(tester, _target(1));
    await gesture.moveTo(const Offset(120, 232));
    await _pumpFrames(tester, const Duration(milliseconds: 100));
    await gesture.cancel();
    await tester.pump();

    final offset = state.controller.offset;
    await _pumpFrames(tester, const Duration(milliseconds: 300));
    expect(state.controller.offset, closeTo(offset, 0.01));
    expect(state.selectionEndCount, 1);
  });

  testWidgets('网格按手指命中的卡片选择连续范围', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.moveTo(tester.getCenter(_target(4)));
    await gesture.up();
    await tester.pump();
    expect(state.selected, {0, 1, 2, 3, 4});

    gesture = await _dragFromHandle(tester, _target(7));
    await gesture.moveTo(tester.getCenter(_target(8)));
    await gesture.moveTo(tester.getCenter(_target(9)));
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1, 2, 3, 4, 7, 8, 9});
  });

  testWidgets('网格回滑会撤销离开手指范围的卡片', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.moveTo(tester.getCenter(_target(4)));
    await tester.pump();
    expect(state.selected, {0, 1, 2, 3, 4});

    await gesture.moveTo(tester.getCenter(_target(1)));
    await tester.pump();
    expect(state.selected, {0, 1});
    await gesture.up();
    await tester.pump();
  });

  testWidgets('网格松手后从已选卡片滑动可以取消连续范围', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.moveTo(tester.getCenter(_target(4)));
    await gesture.up();
    await tester.pump();
    expect(state.selected, {0, 1, 2, 3, 4});

    gesture = await _dragFromHandle(tester, _target(0));
    await gesture.moveTo(tester.getCenter(_target(1)));
    await gesture.moveTo(tester.getCenter(_target(2)));
    await gesture.up();
    await tester.pump();

    expect(state.selected, {3, 4});
  });

  testWidgets('网格多选模式后从卡片任意位置横向拖动无需再次长按', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.up();
    await tester.pump();
    expect(state.selectionMode, isTrue);
    expect(state.selected, {0});

    gesture = await tester.startGesture(tester.getCenter(_target(1)));
    await gesture.moveTo(tester.getCenter(_target(2)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1, 2});
  });

  testWidgets('网格多选模式横向后纵向移动仍持续选择', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.up();
    await tester.pump();

    gesture = await tester.startGesture(tester.getCenter(_target(1)));
    await gesture.moveTo(tester.getCenter(_target(2)));
    await gesture.moveTo(tester.getCenter(_target(5)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1, 2, 3, 4, 5});
  });

  testWidgets('网格多选模式后纵向起手仍由列表滚动处理', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.up();
    await tester.pump();
    expect(state.selected, {0});

    await tester.timedDragFrom(
      tester.getCenter(_target(0)),
      const Offset(0, -120),
      const Duration(milliseconds: 150),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.selected, {0});
    expect(state.controller.offset, greaterThan(0));
  });

  testWidgets('列表多选模式后从复选框区域纵向拖动可继续选择', (tester) async {
    await _pumpHarness(tester, itemCount: 40, viewportHeight: 240);
    final state = _harnessState(tester);

    var gesture = await _longPress(tester, _target(0));
    await gesture.up();
    await tester.pump();
    expect(state.selected, {0});

    gesture = await _dragFromHandle(tester, _target(1));
    await gesture.moveTo(tester.getCenter(_target(4)));
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1, 2, 3, 4});
  });

  testWidgets('网格首次长按后纵向拖动也按命中范围选择', (tester) async {
    await _pumpGridHarness(tester);
    final state = _gridHarnessState(tester);

    final gesture = await _longPress(tester, _target(0));
    await gesture.moveTo(tester.getCenter(_target(3)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.selected, {0, 1, 2, 3});
  });

  testWidgets('列表多选模式后非复选框区域纵向拖动仍由列表滚动处理', (tester) async {
    await _pumpHarness(tester, itemCount: 40, viewportHeight: 240);
    final state = _harnessState(tester);

    final gesture = await _longPress(tester, _target(1));
    await gesture.up();
    await tester.pump();
    expect(state.selected, {1});

    await tester.timedDragFrom(
      tester.getCenter(_target(1)),
      const Offset(0, -52),
      const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.selected, {1});
    expect(state.controller.offset, greaterThan(0));
  });
}

Finder _target(int id) => find.byKey(ValueKey<int>(id));

Future<void> _pumpHarness(
  WidgetTester tester, {
  required int itemCount,
  double viewportHeight = 320,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _SelectionHarness(
          itemCount: itemCount,
          viewportHeight: viewportHeight,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpGridHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: _GridSelectionHarness())),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _longPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  return gesture;
}

Future<TestGesture> _dragFromHandle(WidgetTester tester, Finder target) {
  return tester.startGesture(_handlePosition(tester, target));
}

Offset _handlePosition(WidgetTester tester, Finder target) =>
    tester.getRect(target).topLeft + const Offset(12, 12);

_SelectionHarnessState _harnessState(WidgetTester tester) =>
    tester.state<_SelectionHarnessState>(find.byType(_SelectionHarness));

_GridSelectionHarnessState _gridHarnessState(WidgetTester tester) => tester
    .state<_GridSelectionHarnessState>(find.byType(_GridSelectionHarness));

Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
    await tester.pump(frame);
  }
}

class _SelectionHarness extends StatefulWidget {
  const _SelectionHarness({
    required this.itemCount,
    required this.viewportHeight,
  });

  final int itemCount;
  final double viewportHeight;

  @override
  State<_SelectionHarness> createState() => _SelectionHarnessState();
}

class _SelectionHarnessState extends State<_SelectionHarness> {
  late final ScrollController controller;
  final Set<int> selected = <int>{};
  var itemCount = 0;
  var selectionEndCount = 0;
  var selectionMode = false;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    itemCount = widget.itemCount;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void addItems(int count) {
    setState(() => itemCount += count);
  }

  void _setSelection(int id, bool value) {
    if (value) {
      selected.add(id);
    } else {
      selected.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.viewportHeight,
      child: DragSelectionScope<int>(
        scrollController: controller,
        selectionLayout: DragSelectionLayout.list,
        isSelected: selected.contains,
        selectionMode: selectionMode,
        onSelectionStart: (id, value) {
          setState(() {
            selectionMode = true;
            _setSelection(id, value);
          });
        },
        onSelectionChanged: (id, value) {
          setState(() => _setSelection(id, value));
        },
        onSelectionEnd: () {
          setState(() => selectionEndCount++);
        },
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverList.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) => DragSelectionTarget<int>(
                key: ValueKey<int>(index),
                id: index,
                child: SizedBox(
                  height: 48,
                  child: ColoredBox(
                    color: selected.contains(index)
                        ? Colors.blue
                        : Colors.transparent,
                    child: Center(child: Text('$index')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSelectionHarness extends StatefulWidget {
  const _GridSelectionHarness();

  @override
  State<_GridSelectionHarness> createState() => _GridSelectionHarnessState();
}

class _GridSelectionHarnessState extends State<_GridSelectionHarness> {
  final controller = ScrollController();
  final Set<int> selected = <int>{};
  var selectionMode = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _setSelection(int id, bool value) {
    if (value) {
      selected.add(id);
    } else {
      selected.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 360,
      child: DragSelectionScope<int>(
        scrollController: controller,
        selectionLayout: DragSelectionLayout.grid,
        isSelected: selected.contains,
        selectionMode: selectionMode,
        onSelectionStart: (id, value) {
          setState(() {
            selectionMode = true;
            _setSelection(id, value);
          });
        },
        onSelectionChanged: (id, value) {
          setState(() => _setSelection(id, value));
        },
        onSelectionEnd: () {},
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => DragSelectionTarget<int>(
                  key: ValueKey<int>(index),
                  id: index,
                  selectionIndex: index,
                  child: ColoredBox(
                    color: selected.contains(index)
                        ? Colors.blue
                        : Colors.transparent,
                    child: Center(child: Text('$index')),
                  ),
                ),
                childCount: 18,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 72,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
