import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/home/home_page.dart';
import 'package:omm/features/home/home_providers.dart';
import 'package:omm/features/home/recommend_carousel.dart';
import 'package:omm/features/oh_my_media/libraries/libraries_providers.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final action in ['编辑信息', '编辑封面', '自动获取']) {
    testWidgets('首页 $action 返回后保留位置且仅封面变更更新图片缓存', (tester) async {
      SharedPreferences.setMockInitialValues({
        'privacy.app_switcher_shield': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {'refreshed': true, 'resolution_tier': '4k'},
                },
              ),
            );
          },
        ),
      );
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
            ommMediaSourceProvider.overrideWithValue(
              OmmMediaSourceAdapter(ApiClient(dio)),
            ),
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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      final imageRevisionBefore = container.read(imageCacheRevisionProvider);
      if (action == '编辑封面') {
        MovieDataChanges.bumpImages(movieId: 3);
      } else if (action == '自动获取') {
        await tester.runAsync(
          () => container.read(mediaRepositoryProvider).mediaInfoDetail(3),
        );
      } else {
        MovieDataChanges.bumpMetadata(movieId: 3);
      }
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
      expect(
        container.read(imageCacheRevisionProvider),
        imageRevisionBefore + (action == '编辑封面' ? 1 : 0),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
