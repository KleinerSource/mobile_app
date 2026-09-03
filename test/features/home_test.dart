// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/home_providers_test.dart
//   - test/features/home_movie_view_state_test.dart
//   - test/features/home_hero_test.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_libraries_section.dart';
import 'package:omm/features/home/home_movie_view_state.dart';
import 'package:omm/features/home/home_providers.dart';
import 'package:omm/features/home/recommend_carousel.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

// ==================== 原 test/features/home_providers_test.dart ====================
void _main_0() {
  test('continue watching 过滤未完成且有有效进度的影片', () {
    expect(
      isContinueWatchingMovie(
        const MovieListItem(
          id: 1,
          watchRecord: WatchRecordSummary(progressRatio: 0.4),
        ),
      ),
      isTrue,
    );
    expect(
      isContinueWatchingMovie(
        const MovieListItem(
          id: 2,
          watchRecord: WatchRecordSummary(progressRatio: 0.4, completed: true),
        ),
      ),
      isFalse,
    );
    expect(
      isContinueWatchingMovie(
        const MovieListItem(
          id: 3,
          watchRecord: WatchRecordSummary(progressRatio: 0.01),
        ),
      ),
      isFalse,
    );
  });

  test('首页刷新不会因单个区块失败而跳过其它区块', () async {
    final refreshed = <String>[];

    await refreshHomeProviders(
      refreshRecentlyAdded: () async {
        refreshed.add('recent');
        throw StateError('recent failed');
      },
      refreshContinueWatching: () async {
        refreshed.add('continue');
        return null;
      },
      refreshLibraries: () async {
        refreshed.add('libraries');
        return null;
      },
      refreshRecommendCarousel: () async {
        refreshed.add('carousel');
        return null;
      },
    );

    expect(
      refreshed,
      containsAll(<String>['recent', 'continue', 'libraries', 'carousel']),
    );
  });
}

// ==================== 原 test/features/home_movie_view_state_test.dart ====================
void _main_1() {
  test('最近加入且未打开的影片显示 NEW', () {
    final now = DateTime.utc(2026, 8, 12, 12);
    final movie = MovieListItem(
      id: 1,
      title: '新影片',
      movieCreatedAt: now.subtract(const Duration(hours: 6)),
    );

    expect(isUnreadRecentlyAddedMovie(movie, <int>{}, now: now), isTrue);
    expect(isUnreadRecentlyAddedMovie(movie, <int>{1}, now: now), isFalse);
    expect(
      isUnreadRecentlyAddedMovie(
        movie.copyWith(movieCreatedAt: now.subtract(const Duration(days: 3))),
        <int>{},
        now: now,
      ),
      isFalse,
    );
  });

  test('已打开影片的状态会持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = HomeMovieViewState(prefs);

    await state.markMovieViewed(42);

    expect(state.viewedMovieIds(), contains(42));
  });
}

// ==================== 原 test/features/home_hero_test.dart ====================
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

void _main_2() {
  testWidgets('半屏 hero 上滑先收窄再整体推出', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
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
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
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
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
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
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
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
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RecommendCarousel(
              items: carouselItems,
              urlBuilder: (uuid) => 'http://test/$uuid.jpg',
              onMovieReturned: (_) {},
              pagePosition: position,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildCarousel(items));
    await tester.pumpAndSettle();
    expect(position.value, 0.0);
    expect(
      tester.widget<Text>(find.text('A')).style?.shadows ?? const <Shadow>[],
      isEmpty,
    );

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
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: RecommendCarousel(
                items: items,
                urlBuilder: (uuid) => 'http://test/$uuid.jpg',
                onMovieReturned: (_) {},
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

    // 封面底部通过 dstIn 渐隐溶入氛围背景,不再渐变到纯色底
    expect(
      find.descendant(
        of: find.byType(RecommendCarousel),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );

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
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: HeroBackdrop(arts: arts, position: position),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('dbonline 首页轮播封面适配隐私模式并支持点击揭示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyShieldProvider.overrideWith(() => _PrivacyOn())],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: RecommendCarousel.dbOnline(
                items: const [
                  DbOnlineMovie(id: 'db-id', number: 'ABC-001', title: '示例影片'),
                ],
                imageUrlBuilder: (_) => 'http://test/cover.jpg',
                onMovieTap: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2));
    expect(find.text('▆▆▆▆▆'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('▆▆▆▆▆')).style?.shadows ??
          const <Shadow>[],
      isEmpty,
    );

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.text('示例影片'), findsOneWidget);
  });
}

class _PrivacyOn extends PrivacyShieldNotifier {
  @override
  bool build() => true;
}

// ==================== Emby/Jellyfin 媒体库入口卡片隐私 ====================
void _main_3() {
  testWidgets('媒体库入口卡片适配隐私模式:遮罩库名且首点只揭示', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyShieldProvider.overrideWith(() => _PrivacyOn())],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: HomeLibrariesSection(
              entries: [
                HomeLibraryCardEntry(
                  id: 'lib-7',
                  name: '私人媒体库',
                  onTap: () => opened = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 库名遮罩成方块,卡片盖揭示图标
    expect(find.text('▆▆▆▆▆'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // 首次点击只揭开当前卡片,不进入媒体库
    await tester.tap(find.byType(PrivacyAwareInkWell));
    await tester.pump();
    expect(find.text('▆▆▆▆▆'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(opened, isFalse);

    // 揭开后再次点击进入媒体库
    await tester.tap(find.byType(PrivacyAwareInkWell));
    await tester.pump();
    expect(opened, isTrue);
  });
}

Future<void> _pumpHomeLibraryCard(
  WidgetTester tester,
  HomeLibraryCardEntry entry,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: HomeLibrariesSection(entries: [entry])),
      ),
    ),
  );
  await tester.pump();
}

void _main_4() {
  testWidgets('媒体库卡片长按显示刷新菜单并可点击外部关闭', (tester) async {
    var refreshCount = 0;
    await _pumpHomeLibraryCard(
      tester,
      HomeLibraryCardEntry(
        id: 'library-refresh',
        name: '可刷新媒体库',
        onTap: () {},
        onRefresh: () => refreshCount++,
      ),
    );

    final card = find.byType(PrivacyAwareInkWell);
    await tester.longPress(card);
    await tester.pump();
    expect(find.text('刷新'), findsOneWidget);

    await tester.tapAt(const Offset(300, 300));
    await tester.pump();
    expect(find.text('刷新'), findsNothing);

    await tester.longPress(card);
    await tester.pump();
    await tester.tap(find.text('刷新'));
    await tester.pump();
    expect(refreshCount, 1);
  });

  testWidgets('媒体库卡片刷新时显示确定或不确定圆形进度且禁止重复触发', (tester) async {
    var refreshCount = 0;
    final refreshing = HomeLibraryCardEntry(
      id: 'library-progress',
      name: '刷新中的媒体库',
      onTap: () {},
      onRefresh: () => refreshCount++,
      isRefreshing: true,
      refreshProgress: 0.42,
    );
    await _pumpHomeLibraryCard(tester, refreshing);

    final determinate = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(determinate.value, closeTo(0.42, 0.0001));
    expect(find.text('42%'), findsOneWidget);

    await tester.longPress(find.byType(PrivacyAwareInkWell));
    await tester.pump();
    expect(find.text('刷新'), findsOneWidget);
    await tester.tap(find.text('刷新'));
    await tester.pump();
    expect(refreshCount, 0);

    await _pumpHomeLibraryCard(
      tester,
      refreshing.copyWithForTest(refreshProgress: null),
    );
    final indeterminate = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indeterminate.value, isNull);
    expect(find.text('42%'), findsNothing);
  });
}

extension on HomeLibraryCardEntry {
  HomeLibraryCardEntry copyWithForTest({double? refreshProgress}) {
    return HomeLibraryCardEntry(
      id: id,
      name: name,
      coverUrl: coverUrl,
      onTap: onTap,
      imageHeaders: imageHeaders,
      category: category,
      onRefresh: onRefresh,
      isRefreshing: isRefreshing,
      refreshProgress: refreshProgress,
    );
  }
}

void main() {
  group('home_providers', _main_0);
  group('home_movie_view_state', _main_1);
  group('home_hero', _main_2);
  group('home_libraries_section', _main_3);
  group('home_libraries_refresh', _main_4);
}
