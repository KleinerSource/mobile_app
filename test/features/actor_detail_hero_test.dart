import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/core/models/actor.dart';
import 'package:md_center/features/home/hero_backdrop.dart';
import 'package:md_center/features/movies/movies_providers.dart';
import 'package:md_center/features/person_detail/person_detail_page.dart';
import 'package:md_center/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GlobalKey<NavigatorState>> pumpActorPage(
    WidgetTester tester,
    Widget page,
  ) async {
    tester.view.physicalSize = const Size(600, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          imageUrlBuilderProvider.overrideWithValue((uuid) => ''),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          // 模拟 44px 状态栏: 头图应穿透到屏幕顶部,按钮行避开状态栏
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.fromLTRB(0, 44, 0, 0)),
            child: child!,
          ),
          theme: ThemeData(brightness: Brightness.dark),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: Center(child: Text('root'))),
        ),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  Future<void> expectUnifiedHeroBehavior(
    WidgetTester tester,
    Key heroKey,
  ) async {
    // 封面显示在版面上部约 42%: 展开高度 = 视口高度 * 0.42
    final heroHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.42;
    final hero = find.byKey(heroKey);
    var rect = tester.getRect(hero);
    expect(rect.height, moreOrLessEquals(heroHeight, epsilon: 1));
    expect(rect.top, 0, reason: '封面应穿透到状态栏底下');

    // 封面自 40% 分界线单一渐变淡出,透出页面底层毛玻璃;
    // 头图内不叠加任何额外渐变/模糊层(避免名称区出现分割线)
    expect(
      find.descendant(of: hero, matching: find.byType(ShaderMask)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.byType(ImageFiltered)),
      findsNothing,
    );
    expect(find.byType(HeroBackdrop), findsOneWidget);

    // 上滑约 100px(触摸 slop 损耗约 20px): 封面按滚动量收窄,顶部锚定
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    rect = tester.getRect(hero);
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(offset, closeTo(100, 25), reason: '上滑手势应产生滚动');
    expect(
      rect.height,
      moreOrLessEquals(
        (heroHeight - offset).clamp(heroHeight * 0.62, heroHeight),
        epsilon: 1,
      ),
      reason: '收窄量应等于滚动量,不低于最小高度',
    );
    // 收窄阶段顶部锚定;超过收窄范围后开始整体推出(top 上移超出量)
    final overshoot = (offset - (heroHeight - heroHeight * 0.62)).clamp(
      0.0,
      heroHeight,
    );
    expect(rect.top, moreOrLessEquals(-overshoot, epsilon: 1));

    // 悬浮返回按钮避开状态栏区域,点击可正常返回上一页
    final backButtonRect = tester.getRect(find.byIcon(Icons.arrow_back));
    expect(backButtonRect.top, greaterThanOrEqualTo(44));
  }

  testWidgets('PersonDetailPage 头图收窄渐隐且悬浮返回可用', (tester) async {
    final navigatorKey = await pumpActorPage(
      tester,
      PersonDetailPage(
        actor: ActorItem(
          id: 7,
          name: 'Test Actor',
          actorType: '演员',
          biography: List.filled(40, '这是一段用于撑高页面内容的演员简介文本。').join(),
        ),
      ),
    );

    await expectUnifiedHeroBehavior(tester, const ValueKey('person-hero'));
    // 信息层: 姓名 + 类型胶囊压封面底部
    expect(find.text('Test Actor'), findsOneWidget);
    expect(find.text('演员'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(PersonDetailPage), findsNothing);
    expect(find.text('root'), findsOneWidget);
    expect(navigatorKey.currentState, isNotNull);
  });

  testWidgets('avatar_path 多张时封面自动淡入淡出轮播且禁止手动', (tester) async {
    await pumpActorPage(
      tester,
      const PersonDetailPage(
        actor: ActorItem(
          id: 7,
          name: 'Carousel Actor',
          avatarPaths: ['a.jpg', 'b.jpg', 'c.jpg'],
        ),
      ),
    );

    final hero = find.byKey(const ValueKey('person-hero'));
    // 禁止手动: 无可滑动 PageView,也无圆点指示条
    expect(
      find.descendant(of: hero, matching: find.byType(PageView)),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.byType(AnimatedContainer)),
      findsNothing,
    );

    // 推进超过自动轮播间隔与淡入时长,自动切换交叉淡化不崩溃
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    // 再经历一轮完整切换仍稳定
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  });
}
