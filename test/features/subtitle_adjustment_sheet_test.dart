import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/subtitle_adjustment_sheet.dart';
import 'package:omm/features/player/subtitle_settings.dart';

void main() {
  testWidgets('字幕调节浮层使用紧凑步进控件并实时回调', (tester) async {
    var adjustments = const SubtitleAdjustments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitleAdjustmentSheet(
            initial: adjustments,
            onChanged: (value) => adjustments = value,
          ),
        ),
      ),
    );

    expect(find.text('字幕设置'), findsOneWidget);
    expect(find.text('字幕预览'), findsNothing);
    expect(find.text('延迟偏移'), findsOneWidget);
    expect(find.text('垂直偏移'), findsOneWidget);
    expect(find.text('大小缩放'), findsOneWidget);
    expect(find.text('不透明度'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);

    for (final text in ['字幕设置', '延迟偏移', '0.0 s']) {
      expect(
        tester.widget<Text>(find.text(text)).style?.decoration,
        TextDecoration.none,
      );
    }

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(adjustments.delayMs, 100);
    expect(find.text('0.1 s'), findsOneWidget);
  });

  testWidgets('点击数值可以直接输入并应用目标值', (tester) async {
    var adjustments = const SubtitleAdjustments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitleAdjustmentSheet(
            initial: adjustments,
            onChanged: (value) => adjustments = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('编辑延迟偏移'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2.3');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(adjustments.delayMs, 2300);
    expect(find.text('2.3 s'), findsOneWidget);
  });

  testWidgets('编辑对话框展示各调节项的阈值信息', (tester) async {
    var adjustments = const SubtitleAdjustments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitleAdjustmentSheet(
            initial: adjustments,
            onChanged: (value) => adjustments = value,
          ),
        ),
      ),
    );

    Future<void> openAndCheck(String tooltip, String expectedRange) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(find.textContaining('范围：$expectedRange'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }

    await openAndCheck('编辑延迟偏移', '无限制');
    await openAndCheck('编辑垂直偏移', '-1000 ~ 2000');
    await openAndCheck('编辑大小缩放', '50 ~ 400');
    await openAndCheck('编辑不透明度', '10 ~ 100');
  });

  testWidgets('长按超过 3 秒和 5 秒后连发速度逐级加快', (tester) async {
    var adjustments = const SubtitleAdjustments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitleAdjustmentSheet(
            initial: adjustments,
            onChanged: (value) => adjustments = value,
          ),
        ),
      ),
    );

    final plus = find.byTooltip('增加').first;
    final gesture = await tester.startGesture(tester.getCenter(plus));

    // 先越过 500ms 长按识别门槛，触发首次步进。
    await tester.pump(const Duration(milliseconds: 550));

    // 基础速度（120ms/次）：1.2 秒窗口约 10 次。
    var windowStart = adjustments.delayMs;
    await tester.pump(const Duration(milliseconds: 1200));
    final baseDelta = (adjustments.delayMs - windowStart) ~/ 100;

    // 再按住 1.9 秒越过 3 秒阈值，进入 ×2 档（60ms/次）：
    // 同样 1.2 秒窗口约 20 次。
    await tester.pump(const Duration(milliseconds: 1900));
    windowStart = adjustments.delayMs;
    await tester.pump(const Duration(milliseconds: 1200));
    final speedUp1Delta = (adjustments.delayMs - windowStart) ~/ 100;

    // 再按住 1.9 秒越过 5 秒阈值，进入 ×3 档（40ms/次）：
    // 同样 1.2 秒窗口约 30 次。
    await tester.pump(const Duration(milliseconds: 1900));
    windowStart = adjustments.delayMs;
    await tester.pump(const Duration(milliseconds: 1200));
    final speedUp2Delta = (adjustments.delayMs - windowStart) ~/ 100;

    expect(baseDelta, inInclusiveRange(9, 11));
    expect(speedUp1Delta, inInclusiveRange(19, 21));
    expect(speedUp2Delta, inInclusiveRange(29, 31));

    await gesture.up();
    await tester.pump();
    final afterRelease = adjustments.delayMs;
    await tester.pump(const Duration(milliseconds: 360));
    expect(adjustments.delayMs, afterRelease);
  });

  testWidgets('延迟偏移步进不再受上下限钳制', (tester) async {
    var adjustments = const SubtitleAdjustments(delayMs: 9900);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitleAdjustmentSheet(
            initial: adjustments,
            onChanged: (value) => adjustments = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(adjustments.delayMs, 10000);
  });

  test('垂直偏移使用运行时屏幕边界', () {
    const bounds = SubtitleVerticalOffsetBounds(min: -24, max: 736);

    expect(bounds.clamp(900), 736);
    expect(bounds.clamp(-200), -24);
    expect(bounds.clamp(120), 120);
    expect(clampSubtitleVerticalOffset(2500), subtitleVerticalOffsetMax);
    expect(clampSubtitleVerticalOffset(-1200), subtitleVerticalOffsetMin);
  });
}
