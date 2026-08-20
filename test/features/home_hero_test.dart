import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/features/home/hero_backdrop.dart';
import 'package:md_center/features/home/recommend_carousel.dart';
import 'package:md_center/features/privacy/privacy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 与 HomePage._HeroHeaderDelegate 相同的折叠数学
class _HeroDelegate extends SliverPersistentHeaderDelegate {
  _HeroDelegate({required this.minHeight, required this.maxHeight});

  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final height = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    return SizedBox(
      height: height,
      child: const KeyedSubtree(
        key: ValueKey('hero'),
        child: ColoredBox(color: Colors.red),
      ),
    );
  }

  @override
  bool shouldRebuild(_HeroDelegate oldDelegate) => true;
}

void main() {
  testWidgets('半屏 hero 上滑先收窄再整体推出', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: false,
                delegate: _HeroDelegate(minHeight: 186, maxHeight: 300),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );

    final hero = find.byKey(const ValueKey('hero'));
    var rect = tester.getRect(hero);
    expect(rect.height, moreOrLessEquals(300, epsilon: 1));
    expect(rect.top, 0);

    // 上滑 100px: hero 收窄约 100px (300 → ~200)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    rect = tester.getRect(hero);
    expect(rect.height, closeTo(200, 4), reason: '上滑应先收窄 hero');

    // 继续大幅上滑: hero 整体被推出视口(惰性构建,离屏即销毁),下方内容接管
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hero')), findsNothing);
  });

  testWidgets('背景随页面位置连续交叉淡入: 基础层保持,淡入层跟随进度', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final arts = ValueNotifier<List<HeroArt>>([
      const HeroArt(movieId: 1, url: 'http://test/a.jpg'),
      const HeroArt(movieId: 2, url: 'http://test/b.jpg'),
    ]);
    final position = ValueNotifier(0.0);
    addTearDown(arts.dispose);
    addTearDown(position.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: HeroBackdrop(arts: arts, position: position),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 页位 0: 仅当前封面
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'http://test/a.jpg',
    );

    // 拖动到一半: 基础层 + 淡入层(下一张)同时存在
    position.value = 0.5;
    await tester.pumpAndSettle();
    final images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((i) => i.imageUrl)
        .toList();
    expect(images, containsAll(['http://test/a.jpg', 'http://test/b.jpg']));

    // 翻页完成: 回到单层(下一张成为基础层)
    position.value = 1.0;
    await tester.pumpAndSettle();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'http://test/b.jpg',
    );
  });

  testWidgets('轮播拖动时连续页位逐帧更新并归一化', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final position = ValueNotifier(0.0);
    addTearDown(position.dispose);
    final items = [
      const MovieListItem(id: 1, title: 'A', fanartUuid: 'a'),
      const MovieListItem(id: 2, title: 'B', fanartUuid: 'b'),
    ];

    Widget buildCarousel(List<MovieListItem> carouselItems) => ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RecommendCarousel(
              items: carouselItems,
              urlBuilder: (uuid) => 'http://test/$uuid.jpg',
              pagePosition: position,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildCarousel(items));
    await tester.pumpAndSettle();
    expect(position.value, 0.0);

    // 拖到下一页: 从页面标题处发起手势(命中链完整),页位同步到 1
    await tester.fling(find.text('A'), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    expect(position.value, closeTo(1.0, 0.01));

    // 空列表同步不应崩溃
    await tester.pumpWidget(buildCarousel(const []));
    await tester.pumpAndSettle();
  });

  testWidgets('轮播拖动时封面保持原位并按边缘裁切', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final items = [
      const MovieListItem(id: 1, title: 'A', fanartUuid: 'a'),
      const MovieListItem(id: 2, title: 'B', fanartUuid: 'b'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: RecommendCarousel(
                items: items,
                urlBuilder: (uuid) => 'http://test/$uuid.jpg',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialCover = find.byType(CachedNetworkImage);
    expect(initialCover, findsOneWidget);
    final initialRect = tester.getRect(initialCover);

    await tester.drag(find.byType(PageView), const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    expect(find.byKey(const ValueKey('hero-cover-edge-clip')), findsOneWidget);
    expect(
      tester.getRect(find.byType(CachedNetworkImage).first),
      initialRect,
      reason: '拖动时封面图片应保持固定尺寸和位置',
    );
  });

  testWidgets('隐私模式开启且未揭开该影片时不显示封面背景', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final arts = ValueNotifier<List<HeroArt>>([
      const HeroArt(movieId: 7, url: 'http://test/fanart.jpg'),
    ]);
    final position = ValueNotifier(0.0);
    addTearDown(arts.dispose);
    addTearDown(position.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          privacyShieldProvider.overrideWith(() => _PrivacyOn()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroBackdrop(arts: arts, position: position),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}

class _PrivacyOn extends PrivacyShieldNotifier {
  @override
  bool build() => true;
}
