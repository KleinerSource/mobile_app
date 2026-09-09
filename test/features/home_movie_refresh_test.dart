import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/features/home/home_page.dart';
import 'package:omm/features/home/home_providers.dart';
import 'package:omm/features/home/recommend_carousel.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('首页编辑返回后依赖重载保持轮播页位和滚动位置', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final response = Completer<PagedResult<MovieListItem>>();
    final items = List.generate(
      12,
      (i) => MovieListItem(
        id: i + 1,
        title: '影片 ${i + 1}',
        posterUuid: 'poster-${i + 1}',
      ),
    );
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          imageUrlBuilderProvider.overrideWithValue((_) => ''),
          recentlyAddedProvider.overrideWith((ref) async {
            if (loads++ > 0) return response.future;
            return PagedResult(
              items: items,
              totalCount: 12,
              limit: 12,
              offset: 0,
            );
          }),
          continueWatchingProvider.overrideWith((ref) async => []),
          librariesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final carousel = find.byType(RecommendCarousel);
    final carouselState = tester.state(carousel);
    final onReturned = tester
        .widget<RecommendCarousel>(carousel)
        .onMovieReturned;
    final pageController = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    pageController.jumpToPage(pageController.page!.round() + 2);
    await tester.pumpAndSettle();
    final pageBefore = pageController.page;
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(80);
    await tester.pumpAndSettle();
    final offsetBefore = position.pixels;
    expect(offsetBefore, greaterThan(0));

    final before = MovieDataChanges.snapshot(movieId: 3);
    MovieDataChanges.bumpMetadata(movieId: 3);
    onReturned(before);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(carousel, findsOneWidget);
    expect(tester.state(carousel), same(carouselState));
    expect(position.pixels, offsetBefore);

    response.complete(
      PagedResult(
        items: [
          for (final item in items)
            item.id == 3 ? item.copyWith(title: '已编辑') : item,
        ],
        totalCount: 12,
        limit: 12,
        offset: 0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.state(carousel), same(carouselState));
    expect(pageController.page, pageBefore);
    expect(position.pixels, offsetBefore);
    expect(tester.widget<RecommendCarousel>(carousel).items[2].title, '已编辑');
    await tester.pumpWidget(const SizedBox());
  });
}
