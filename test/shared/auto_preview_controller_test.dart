import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/preview/auto_preview_controller.dart';

void main() {
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
