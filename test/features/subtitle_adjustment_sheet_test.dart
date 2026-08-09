import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/features/player/subtitle_adjustment_sheet.dart';
import 'package:md_center/features/player/subtitle_settings.dart';

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

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(adjustments.delayMs, 100);
    expect(find.text('0.1 s'), findsOneWidget);
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
}
