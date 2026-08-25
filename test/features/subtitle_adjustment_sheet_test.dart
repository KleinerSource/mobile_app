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

  testWidgets('长按步进按钮会连续调节并在松开后停止', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.up();
    await tester.pump();

    expect(adjustments.delayMs, greaterThan(100));
    final afterRelease = adjustments.delayMs;
    await tester.pump(const Duration(milliseconds: 360));
    expect(adjustments.delayMs, afterRelease);
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
