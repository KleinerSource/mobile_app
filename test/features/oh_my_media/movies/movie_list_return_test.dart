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
import 'package:omm/core/models/related_movie.dart';
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
    for (final action in ['编辑信息', '编辑封面', '自动获取', '读取缓存', '探测失败']) {
      testWidgets('${entry.key} $action 后按变更类型刷新并保留位置', (tester) async {
        SharedPreferences.setMockInitialValues({
          'privacy.app_switcher_shield': false,
        });
        final prefs = await SharedPreferences.getInstance();
        final titles = <int, String>{};
        final probed = <int>{};
        final cropped = <int>{};
        final listRequests = <Map<String, dynamic>>[];
        final updateBodies = <Map<String, dynamic>>[];
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final path = options.uri.path;
              Object? data;
              if (path.endsWith('/movies') || path.endsWith('/favorites')) {
                final query = Map<String, dynamic>.from(
                  options.queryParameters,
                );
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
                        'poster_uuid': cropped.contains(id)
                            ? 'new-poster-$id'
                            : 'poster-$id',
                        'resolution_tier':
                            action == '自动获取' && !probed.contains(id)
                            ? 'unknown'
                            : '4k',
                      },
                  ],
                  'total_count': 200,
                  'limit': count,
                  'offset': offset,
                };
              } else if (path.endsWith('/media-info')) {
                final parts = options.uri.pathSegments;
                final id = int.parse(parts[parts.indexOf('id') + 1]);
                final refreshed = action == '自动获取' && probed.add(id);
                data = {
                  'refreshed': refreshed,
                  'probe_failed': action == '探测失败',
                  if (action != '探测失败') ...{
                    'resolution_tier': '4k',
                    'video_width': 3840,
                    'video_height': 2160,
                    'bit_rate': 8000000,
                  },
                };
              } else if (path.endsWith('/poster/watermark')) {
                final parts = options.uri.pathSegments;
                cropped.add(int.parse(parts[parts.indexOf('id') + 1]));
              } else if (options.method == 'PATCH' &&
                  path.contains('/movies/')) {
                final id = int.parse(path.split('/').last);
                final body = Map<String, dynamic>.from(options.data as Map);
                updateBodies.add(body);
                titles[id] = body['title'] as String;
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
                  resolutionTier: action == '自动获取' && !probed.contains(id)
                      ? ResolutionTier.none
                      : ResolutionTier.uhd,
                ),
              ),
              extraFanartsProvider.overrideWith((ref, id) async => []),
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
        final container = ProviderScope.containerOf(
          tester.element(visibleCard),
        );
        final imageRevisionBefore = container.read(imageCacheRevisionProvider);
        expect(selected.id, greaterThan(50));
        await tester.tap(visibleCard);
        await tester.pumpAndSettle();
        expect(find.byType(MovieDetailPage), findsOneWidget);

        if (action == '编辑信息') {
          unawaited(
            MovieEditorSheet.show(
              tester.element(find.byType(MovieDetailPage)),
              MovieDetail(
                id: selected.id,
                title: selected.title,
                isFavorited: true,
                partMovies: [
                  RelatedMovie(
                    id: selected.id + 1000,
                    title: selected.title,
                    moviePart: 'cd2',
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('同步到 1 个分卷'), findsOneWidget);
          expect(find.text('分卷：CD2'), findsOneWidget);
          expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
          await tester.enterText(find.byType(TextField).first, '已编辑影片');
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(titles[selected.id], '已编辑影片');
          expect(updateBodies.single['sync_parts'], isTrue);
          expect(find.byType(MovieEditorSheet), findsNothing);
        } else if (action == '编辑封面') {
          await tester.runAsync(
            () => container
                .read(mediaRepositoryProvider)
                .applyPosterCrop(selected.id, cropOffset: 0.5),
          );
          expect(cropped, contains(selected.id));
        } else if (action == '自动获取') {
          expect(probed, contains(selected.id));
          expect(
            container
                .read(mediaInfoProvider(selected.id))
                .value!
                .resolutionTier,
            ResolutionTier.uhd,
          );
        }
        final requestsBeforeReturn = listRequests.length;
        navigator.currentState!.pop();
        await tester.pumpAndSettle();

        expect(paging.itemList!.map((item) => item.id), idsBefore);
        expect(paging.nextPageKey, idsBefore.length);
        expect(scroll.offset, closeTo(offsetBefore, 0.5));
        expect(
          paging.itemList!.singleWhere((item) => item.id == selected.id).title,
          action == '编辑信息' ? '已编辑影片' : selected.title,
        );
        final returned = paging.itemList!.singleWhere(
          (item) => item.id == selected.id,
        );
        expect(
          returned.posterUuid,
          action == '编辑封面' ? 'new-poster-${selected.id}' : selected.posterUuid,
        );
        expect(
          container.read(imageCacheRevisionProvider),
          imageRevisionBefore + (action == '编辑封面' ? 1 : 0),
        );
        if (action == '自动获取') {
          expect(selected.resolutionTier, ResolutionTier.none);
          expect(returned.resolutionTier, ResolutionTier.uhd);
        }
        final refreshRequests = listRequests
            .skip(requestsBeforeReturn)
            .toList();
        expect(refreshRequests.map((query) => query['offset']), [
          if (action != '读取缓存' && action != '探测失败')
            for (var offset = 0; offset < idsBefore.length; offset += 50)
              offset,
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
}
