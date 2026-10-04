import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _popTopRoute(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();

/// 系列/类型区块可能在视口外未被 sliver 构建，先滚动到可见再点击。
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  // 悬浮页头遮住视口顶部：目标贴顶时先向下补滚，避免点击命中页头。
  var top = tester.getTopLeft(finder).dy;
  for (var i = 0; top < 150 && i < 10; i++) {
    await tester.drag(scrollable, const Offset(0, 80));
    await tester.pumpAndSettle();
    top = tester.getTopLeft(finder).dy;
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  const config = ServerConfig(
    baseUrl: 'https://example.test',
    activeServerId: 'server-1',
  );

  Future<List<String>> pumpDetail(
    WidgetTester tester, {
    required bool hasCnsub,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestPaths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPaths.add(options.uri.path);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'source': 'database',
                'data': {
                  'code': 'ABC-001',
                  'title': '字幕状态测试影片',
                  'has_cnsub': hasCnsub,
                  'magnets': [],
                  'ed2ks': [],
                },
              },
            ),
          );
        },
      ),
    );

    final api = DbOnlineApi(dio);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(preferences),
          mediaRuntimeConfigProvider.overrideWithValue(config),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(api)),
          ),
          dbOnlineSubscriptionCapabilitiesProvider.overrideWith(
            (ref, serverId) async => const DbOnlineSubscriptionCapabilities(
              database: false,
              onlineAccount: false,
              onlineQuery: false,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: DbOnlineMovieDetailPage(code: 'ABC-001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return requestPaths;
  }

  testWidgets('详情更多沿用封面悬浮栏风格并保留资源与字幕菜单', (tester) async {
    await pumpDetail(tester, hasCnsub: true);
    final menu = find.byType(HeaderMenuButton<String>);
    expect(menu, findsOneWidget);
    final back = find.widgetWithIcon(HeaderActionButton, Icons.arrow_back);
    expect(tester.widget<HeaderMenuButton<String>>(menu).tooltip, '更多');
    expect(
      tester.widget<HeaderMenuButton<String>>(menu).style,
      tester.widget<HeaderActionButton>(back).style,
    );
    expect(tester.getSize(menu), tester.getSize(back));
    expect(
      tester.getSize(
        find.descendant(of: menu, matching: find.byType(HeaderActionIcon)),
      ),
      tester.getSize(
        find.descendant(of: back, matching: find.byType(HeaderActionIcon)),
      ),
    );
    await tester.tapAt(tester.getRect(menu).topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('获取资源'), findsOneWidget);
    expect(find.text('获取字幕'), findsOneWidget);
    await tester.tapAt(const Offset(10, 200));
    await tester.pumpAndSettle();
    expect(find.text('获取资源'), findsNothing);
    expect(find.byType(DbOnlineMovieDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情字幕徽标按 has_cnsub 显示', (tester) async {
    final requestPaths = await pumpDetail(tester, hasCnsub: true);

    expect(find.byIcon(Icons.closed_caption_rounded), findsOneWidget);
    expect(requestPaths, isNot(contains('/subtitle/find/ABC-001')));
  });

  testWidgets('has_cnsub 为 false 时不显示详情字幕徽标', (tester) async {
    await pumpDetail(tester, hasCnsub: false);

    expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
  });

  testWidgets('详情导演/片商/发行商/演员/系列/类型点击进入实体列表页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestPaths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPaths.add(options.uri.path);
          final path = options.uri.path;
          const entityPrefixes = [
            '/actors/',
            '/series/',
            '/makers/',
            '/publishers/',
            '/directors/',
            '/categories/',
          ];
          Object? data;
          if (entityPrefixes.any(path.startsWith)) {
            data = {
              'movies': [
                {'id': 'movie-1', 'number': 'ABC-002', 'title': '列表影片'},
              ],
              'current_page': 1,
            };
          } else {
            data = {
              'code': 'ABC-001',
              'title': '跳转测试影片',
              'director': {'external_id': 'director-1', 'name': '导演甲'},
              'maker': {'external_id': 'maker-1', 'name': '片商甲'},
              'publisher': {'external_id': 'publisher-1', 'name': '发行商甲'},
              'actors': [
                {'external_id': 'actor-1', 'name': '演员甲'},
              ],
              'series': {'external_id': 'series-1', 'name': '系列甲'},
              'categories': [
                {'external_id': 'cat-1', 'name': '类别甲'},
                {'name': '类别乙'},
              ],
              'magnets': [],
              'ed2ks': [],
            };
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {'success': true, 'source': 'database', 'data': data},
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(preferences),
          mediaRuntimeConfigProvider.overrideWithValue(config),
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(DbOnlineApi(dio))),
          ),
          dbOnlineSubscriptionCapabilitiesProvider.overrideWith(
            (ref, serverId) async => const DbOnlineSubscriptionCapabilities(
              database: false,
              onlineAccount: false,
              onlineQuery: false,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: DbOnlineMovieDetailPage(code: 'ABC-001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 演员卡片 → 演员实体影片页。
    await tester.tap(find.text('演员甲'));
    await tester.pumpAndSettle();
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/actors/actor-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 系列 Chip → 系列实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 系列甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/series/series-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 导演 Chip → 导演实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 导演甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/directors/director-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 片商 Chip → 片商实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 片商甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/makers/maker-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 发行商 Chip → 发行商实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 发行商甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/publishers/publisher-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 有 external_id 的类型 Chip → 类别实体影片页（/categories 端点）。
    await _scrollToAndTap(tester, find.text('类别甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/categories/cat-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 无 external_id 的类型 Chip 不可跳转，停留在详情页。
    await _scrollToAndTap(tester, find.text('类别乙'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsNothing);
  });
}
