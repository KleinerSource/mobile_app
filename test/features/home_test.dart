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
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/home/hero_backdrop.dart';
import 'package:omm/features/home/home_movie_view_state.dart';
import 'package:omm/features/home/home_providers.dart';
import 'package:omm/features/home/recommend_carousel.dart';
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
void _main_2() {
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

void main() {
  group('home_providers', _main_0);
  group('home_movie_view_state', _main_1);
  group('home_hero', _main_2);
}
