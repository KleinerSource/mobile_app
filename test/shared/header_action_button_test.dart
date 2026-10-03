import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/header_action_button.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

GlassMenuEntry<String> _entry(String value) => GlassMenuEntry<String>.action(
  value: value,
  builder: (context, selected, onTap) =>
      GlassMenuRow(label: value, selected: selected, onTap: onTap),
);

/// 波纹裁剪区域：在 48 点击区域内居中的可见圆。
Rect _rippleBounds(WidgetTester tester, Finder button) {
  final ink = tester.widget<InkWell>(
    find.descendant(of: button, matching: find.byType(InkWell)),
  );
  return ink.customBorder!
      .getOuterPath(const Rect.fromLTWH(0, 0, 48, 48))
      .getBounds();
}

void main() {
  for (final style in HeaderActionStyle.values) {
    testWidgets('${style.name} 波纹裁剪为可见圆并绘制在圆底之上', (tester) async {
      await tester.pumpWidget(
        _app(
          HeaderActionButton(
            icon: Icons.settings,
            tooltip: '设置',
            style: style,
            onPressed: () {},
          ),
        ),
      );
      final button = find.byType(HeaderActionButton);
      expect(tester.getSize(button), const Size.square(48));
      expect(
        _rippleBounds(tester, button),
        Rect.fromCircle(
          center: const Offset(24, 24),
          radius: style.diameter / 2,
        ),
      );
      final circle = find.descendant(of: button, matching: find.byType(Ink));
      expect(tester.getSize(circle), Size.square(style.diameter));
      expect(tester.getCenter(circle), tester.getCenter(button));
      // 圆底由 Ink 绘制；不再用 Container 盖住 Material 上的波纹。
      expect(
        find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('普通操作长按显示 tooltip，点击圆外留白仍触发', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        HeaderActionButton(
          icon: Icons.settings,
          tooltip: '设置',
          onPressed: () => taps++,
        ),
      ),
    );
    final button = find.byType(HeaderActionButton);
    await tester.tapAt(tester.getRect(button).topLeft + const Offset(2, 2));
    expect(taps, 1);
    await tester.longPress(button);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('设置'), findsOneWidget);
    expect(taps, 1);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('禁用与加载时不响应点击，禁用图标使用弱化颜色', (tester) async {
    await tester.pumpWidget(
      _app(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeaderActionButton(
              icon: Icons.tune_rounded,
              tooltip: '筛选',
              onPressed: null,
            ),
            HeaderActionButton(
              icon: Icons.refresh,
              tooltip: '刷新',
              loading: true,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
    for (final ink in tester.widgetList<InkWell>(find.byType(InkWell))) {
      expect(ink.onTap, isNull);
    }
    final context = tester.element(find.byIcon(Icons.tune_rounded));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color,
      appColors(context).muted,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('菜单入口复用圆形波纹，点击打开且长按保留滑动选择', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      _app(
        HeaderMenuButton<String>(
          icon: Icons.more_vert_rounded,
          tooltip: '更多',
          menuWidth: 200,
          entries: [_entry('甲'), _entry('乙')],
          onSelected: selected.add,
        ),
      ),
    );
    final button = find.byType(HeaderMenuButton<String>);
    expect(tester.getSize(button), const Size.square(48));
    expect(
      _rippleBounds(tester, button),
      Rect.fromCircle(center: const Offset(24, 24), radius: 18),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('甲'), findsOneWidget);
    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();
    expect(selected, ['乙']);
    expect(find.text('甲'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('甲'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.text('甲')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, ['乙', '甲']);
    expect(find.text('甲'), findsNothing);
  });

  testWidgets('菜单入口禁用时不打开菜单', (tester) async {
    await tester.pumpWidget(
      _app(
        HeaderMenuButton<String>(
          icon: Icons.more_vert_rounded,
          tooltip: '更多',
          menuWidth: 200,
          enabled: false,
          entries: [_entry('甲')],
          onSelected: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(HeaderMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('甲'), findsNothing);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });
}
