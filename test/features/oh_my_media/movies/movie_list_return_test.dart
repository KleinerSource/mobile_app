import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_editor_sheet.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/search/search_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final entry in <String, Widget>{
    '影片库': const MoviesPage(),
    '媒体库': const MoviesPage(initialFilter: MovieFilter(libraryId: 7)),
    '搜索': const SearchPage(),
    '收藏夹': const FavoritesPage(),
  }.entries) {
    testWidgets('${entry.key} 深处影片编辑返回后保留分页、位置并显示新标题', (tester) async {
      SharedPreferences.setMockInitialValues({
        'privacy.app_switcher_shield': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final titles = <int, String>{};
      final listRequests = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final path = options.uri.path;
            Object? data;
            if (path.endsWith('/movies') || path.endsWith('/favorites')) {
              final query = Map<String, dynamic>.from(options.queryParameters);
              listRequests.add(query);
              final offset = query['offset'] as int;
              // 模拟服务端把超大 limit 截为 50，而不是按请求数量返回。
              final count = (query['limit'] as int).clamp(1, 50);
              data = {
                'items': [
                  for (
                    var id = offset + 1;
                    id <= offset + count && id <= 200;
                    id++
                  )
                    {
                      'id': id,
                      'title': titles[id] ?? '影片 $id',
                      'is_favorited': true,
                    },
                ],
                'total_count': 200,
                'limit': count,
                'offset': offset,
              };
            } else if (options.method == 'PATCH' && path.contains('/movies/')) {
              final id = int.parse(path.split('/').last);
              titles[id] = (options.data as Map)['title'] as String;
              data = {'id': id, 'title': titles[id]};
            } else if (path.endsWith('/lists')) {
              data = [];
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {'success': true, 'data': data},
              ),
            );
          },
        ),
      );
      final api = ApiClient(dio);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            requiredApiClientProvider.overrideWithValue(api),
            ommMediaSourceProvider.overrideWithValue(
              OmmMediaSourceAdapter(api),
            ),
            movieDetailProvider.overrideWith(
              (ref, id) async => MovieDetail(
                id: id,
                title: titles[id] ?? '影片 $id',
                isFavorited: true,
              ),
            ),
            extraFanartsProvider.overrideWith((ref, id) async => []),
            mediaInfoProvider.overrideWith((ref, id) async => null),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(body: entry.value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (entry.key == '搜索') {
        await tester.enterText(find.byType(TextField).first, '影片');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }
      final grid = find.byType(PagedSliverGrid<int, MovieListItem>);
      final paging = tester
          .widget<PagedSliverGrid<int, MovieListItem>>(grid)
          .pagingController;
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView).last)
          .controller!;
      // 真实滚动触发第二页，并停在第一批 50 条之外。
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(paging.itemList!.length, greaterThan(50));
      scroll.jumpTo(scroll.position.maxScrollExtent - 700);
      await tester.pumpAndSettle();
      final idsBefore = paging.itemList!.map((item) => item.id).toList();
      final offsetBefore = scroll.offset;
      final visibleCard = find.byType(MovieCard).hitTestable().first;
      final selected = tester.widget<MovieCard>(visibleCard).movie;
      expect(selected.id, greaterThan(50));
      await tester.tap(visibleCard);
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailPage), findsOneWidget);

      unawaited(
        MovieEditorSheet.show(
          tester.element(find.byType(MovieDetailPage)),
          MovieDetail(
            id: selected.id,
            title: selected.title,
            isFavorited: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '已编辑影片');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(titles[selected.id], '已编辑影片');
      expect(find.byType(MovieEditorSheet), findsNothing);
      final requestsBeforeReturn = listRequests.length;
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(paging.itemList!.map((item) => item.id), idsBefore);
      expect(paging.nextPageKey, idsBefore.length);
      expect(scroll.offset, closeTo(offsetBefore, 0.5));
      expect(
        paging.itemList!.singleWhere((item) => item.id == selected.id).title,
        '已编辑影片',
      );
      final refreshRequests = listRequests.skip(requestsBeforeReturn).toList();
      expect(refreshRequests.map((query) => query['offset']), [
        for (var offset = 0; offset < idsBefore.length; offset += 50) offset,
      ]);
      if (entry.key == '媒体库') {
        expect(
          refreshRequests.every((query) => query['library_id'] == 7),
          isTrue,
        );
      }
      if (entry.key == '搜索') {
        expect(
          refreshRequests.every((query) => query['search'] == '影片'),
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
