import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/floating_tab_bar.dart';

void main() {
  const icons = [
    Icons.home_rounded,
    Icons.leaderboard_outlined,
    Icons.video_library_rounded,
    Icons.search_rounded,
    Icons.settings_outlined,
  ];

  List<FloatingTabSpec<int>> specs(List<String> labels) => [
    for (var i = 0; i < labels.length; i++)
      FloatingTabSpec<int>(label: labels[i], icon: icons[i]),
  ];

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: const SizedBox.expand(), bottomNavigationBar: child),
  );

  /// 找到中间的圆形按钮（唯一 shape 为 circle 的 AnimatedContainer）。
  AnimatedContainer circleOf(WidgetTester tester) => tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .firstWhere(
        (widget) =>
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );

  testWidgets('五格窄屏导航完整显示标题，中间项为圆形仅图标', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const labels = ['首页', '排行榜', '影片库', '搜索', '订阅管理'];
    var tapped = -1;
    await tester.pumpWidget(
      host(
        FloatingTabBar<int>(
          tabs: specs(labels),
          active: 2,
          onTap: (index) => tapped = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 中间项（影片库）激活时也只显示图标，不出现标题文字。
    expect(find.text('影片库'), findsNothing);
    // 其余四格标题恒定完整显示（激活与未激活一致），不再截断。
    for (final label in ['首页', '排行榜', '搜索', '订阅管理']) {
      expect(find.text(label), findsOneWidget);
    }
    // 点按胶囊正中命中中间圆形按钮。
    await tester.tap(find.byType(FloatingTabBar<int>));
    expect(tapped, 2);
  });

  testWidgets('中间圆形按钮仅激活时使用强调色高亮', (tester) async {
    const labels = ['首页', '排行榜', '影片库', '搜索', '订阅管理'];

    await tester.pumpWidget(
      host(FloatingTabBar<int>(tabs: specs(labels), active: 0, onTap: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(
      (circleOf(tester).decoration as BoxDecoration).color,
      AppColors.light.chipBg,
    );

    await tester.pumpWidget(
      host(FloatingTabBar<int>(tabs: specs(labels), active: 2, onTap: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(
      (circleOf(tester).decoration as BoxDecoration).color,
      AppColors.light.accent,
    );
  });

  testWidgets('四格以内导航保持横向胶囊并在激活时带出标题', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        FloatingTabBar<int>(
          tabs: specs(['首页', '影片库', '搜索', '我的']),
          active: 1,
          onTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 四格布局没有圆形中间按钮，激活项完整显示三字标题。
    expect(find.text('影片库'), findsOneWidget);
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where(
            (widget) =>
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
      isEmpty,
    );
  });
}
