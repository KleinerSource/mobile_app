import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_scaffold.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('有封面时不显示封面放大入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: SizedBox(
            height: 320,
            child: MovieDetailHero(
              title: '示例影片',
              imageUrl: 'https://example.test/cover.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('查看封面大图'), findsNothing);
  });

  testWidgets('详情顶部封面上滑先收窄再整体推出,状态栏穿透且悬浮返回可用', (tester) async {
    tester.view.physicalSize = const Size(600, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 长剧情 + 标签保证页面内容足够高,能滚动到封面完全离屏
    final plot = List.filled(30, '这是一段用于撑高页面内容的剧情简介文本。').join();
    final movie = MovieDetail(
      id: 7,
      title: 'Test Movie',
      plot: plot,
      fanartUuid: 'fanart',
      tags: [for (var i = 0; i < 12; i++) ResourceItem(id: i, name: 'tag$i')],
    );

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          imageUrlBuilderProvider.overrideWithValue(
            (uuid) => 'http://test/$uuid.jpg',
          ),
          movieDetailProvider(7).overrideWith((ref) async => movie),
          mediaInfoProvider(7).overrideWith((ref) async => null),
          extraFanartsProvider(7).overrideWith((ref) async => const <String>[]),
          movieWatchRecordProvider(7).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          // 模拟 44px 状态栏: 封面应穿透到屏幕顶部,按钮行避开状态栏
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
        MaterialPageRoute<void>(
          builder: (_) => const MovieDetailPage(movieId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('detail-hero'));
    var rect = tester.getRect(hero);
    expect(rect.height, moreOrLessEquals(320, epsilon: 1));
    expect(rect.top, 0, reason: '封面应穿透到状态栏底下,而不是从状态栏下方开始');

    // 氛围背景挂载在页面最底层并使用封面 URL(下拉回弹时露出的是封面色调而非纯色底)
    expect(find.byType(HeroBackdrop), findsOneWidget);
    final backdropImages = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .where((w) => w.width == double.infinity)
        .map((w) => w.imageUrl)
        .toList();
    expect(backdropImages, ['http://test/fanart.jpg']);
    // 封面通过底部渐隐(dstIn ShaderMask)溶入氛围背景,不再渐变到纯色底
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('detail-hero')),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );

    // 上滑约 100px(触摸 slop 损耗约 20px): 封面按滚动量收窄,顶部保持锚定
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
      moreOrLessEquals(320 - offset, epsilon: 1),
      reason: '收窄量应等于滚动量',
    );
    expect(rect.height, greaterThan(320 * 0.62), reason: '此阶段尚未收窄到最小高度');
    expect(rect.top, 0);

    // 继续大幅上滑: 封面整体被推出视口(惰性构建,离屏即销毁)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-hero')), findsNothing);
    // 悬浮操作行不随内容滚动,返回/收藏/更多仍可达
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    // 滚回顶部: 封面恢复展开高度
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-hero')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('detail-hero'))).height,
      moreOrLessEquals(320, epsilon: 1),
    );

    // 悬浮返回按钮避开状态栏区域,点击可正常返回上一页
    final backButtonRect = tester.getRect(find.byIcon(Icons.arrow_back));
    expect(backButtonRect.top, greaterThanOrEqualTo(44));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(MovieDetailPage), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });
}
