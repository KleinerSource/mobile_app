import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/preview/auto_preview_controller.dart';

void main() {
  testWidgets('库页保留240ms延迟，重置后清空预览并取消待执行候选', (tester) async {
    var calls = 0;
    final controller = AutoPreviewController<int>(
      debounce: const Duration(milliseconds: 240),
      candidate: () => ++calls,
    );
    controller.schedule();
    await tester.pump(const Duration(milliseconds: 239));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.value, 1);
    controller.schedule();
    controller.reset();
    expect(controller.value, isNull);
    await tester.pump(const Duration(milliseconds: 240));
    expect(calls, 1);
    controller.dispose();
  });

  testWidgets('搜索页仅合并帧末请求，不增加防抖延迟', (tester) async {
    var calls = 0;
    final controller = AutoPreviewController<int>(
      debounce: Duration.zero,
      candidate: () => ++calls,
    );
    controller.schedule();
    controller.schedule();
    await tester.pump();
    expect(controller.value, 1);
    controller.schedule();
    controller.reset();
    controller.schedule();
    await tester.pump();
    expect(controller.value, 2);
    controller.schedule();
    controller.dispose();
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('预览在最后一次滚动180ms后帧末计算，销毁后不回调', (tester) async {
    var calls = 0;
    final controller = AutoPreviewController<int>(candidate: () => ++calls);
    controller.schedule();
    await tester.pump(const Duration(milliseconds: 100));
    controller.schedule();
    await tester.pump(const Duration(milliseconds: 179));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.value, 1);
    controller.schedule();
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
