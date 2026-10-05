import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/pages/db_online_search_page.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_ranking_preview_card.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('输入关键词后不会立即请求，点击搜索图标才显示 DBO 影片卡片', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    String? query;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          query = options.queryParameters['q']?.toString();
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'movies': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-001',
                      'title': '搜索到的 DBO 影片',
                      'can_play': true,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineSearchPage()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '关键词');
    await tester.pump(const Duration(milliseconds: 350));
    expect(query, isNull);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(query, '关键词');
    expect(find.text('搜索到的 DBO 影片'), findsWidgets);
    expect(find.text('在线播放'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('DBO 搜索支持列表、演员和系列三种模式，并可按 Enter 提交', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requests = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.uri.path);
          final isActor = options.uri.path.endsWith('/search/actors');
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': isActor
                    ? {
                        'actors': [
                          {'id': 'actor-1', 'name': '演员结果'},
                        ],
                      }
                    : {
                        'items': [
                          {'id': 'series-1', 'name': '系列结果'},
                        ],
                      },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineSearchPage()),
        ),
      ),
    );

    expect(find.text('列表搜索'), findsOneWidget);
    await tester.tap(find.text('列表搜索'));
    await tester.pumpAndSettle();
    expect(find.text('演员搜索'), findsOneWidget);
    expect(find.text('系列搜索'), findsOneWidget);
    await tester.tap(find.text('演员搜索').first);
    await tester.enterText(find.byType(TextField), '演员');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(requests, contains('/api/search/actors'));
    expect(find.text('演员结果'), findsOneWidget);

    await tester.tap(find.text('演员搜索').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('系列搜索'));
    await tester.enterText(find.byType(TextField), '系列');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(requests, contains('/api/search'));
    expect(find.text('系列结果'), findsOneWidget);
  });

  testWidgets('点击演员卡片进入演员影片列表', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    String? moviesPath;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          if (path.endsWith('/movies')) {
            moviesPath = path;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {
                    'movies': [
                      {
                        'id': 'movie-1',
                        'number': 'ABC-004',
                        'title': '演员影片',
                        'can_play': true,
                      },
                    ],
                    'current_page': 1,
                  },
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'actors': [
                    {
                      'id': 'actor-1',
                      'name': '演员结果',
                      'uncensored': true,
                      'videos_count': 6,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineSearchPage()),
        ),
      ),
    );

    await tester.tap(find.text('列表搜索'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('演员搜索').first);
    await tester.enterText(find.byType(TextField), '演员');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // 无码演员在卡片底部显示无码标识。
    expect(find.text('演员结果'), findsOneWidget);
    expect(find.text('无码'), findsOneWidget);

    await tester.tap(find.text('演员结果'));
    await tester.pumpAndSettle();

    expect(moviesPath, '/api/actors/actor-1/movies');
    expect(find.text('演员影片'), findsOneWidget);
  });

  testWidgets('提交搜索后记录历史，点击历史重搜并可一键清空', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'movies': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-001',
                      'title': '搜索到的 DBO 影片',
                      'can_play': true,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineSearchPage()),
        ),
      ),
    );

    // 无历史时空态提示照旧。
    expect(find.text('搜索历史'), findsNothing);
    expect(find.text('输入关键词开始搜索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '关键词A');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('搜索到的 DBO 影片'), findsOneWidget);

    // 清空输入后回到空态，展示按服务器保存的历史。
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('关键词A'), findsOneWidget);

    // 点击历史关键词重新搜索。
    await tester.tap(find.text('关键词A'));
    await tester.pumpAndSettle();
    expect(find.text('搜索到的 DBO 影片'), findsOneWidget);

    // 一键清空需二次确认：第一次进入确认态，第二次真正清空后回到空态提示。
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.text('确认清空？'), findsOneWidget);
    await tester.tap(find.text('确认清空？'));
    await tester.pumpAndSettle();
    expect(find.text('搜索历史'), findsNothing);
    expect(find.text('关键词A'), findsNothing);
    expect(find.text('输入关键词开始搜索'), findsOneWidget);
  });

  testWidgets('列表搜索通过筛选弹层过滤并按参数重新搜索', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final queries = <Map<String, String>>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          queries.add(options.uri.queryParameters);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'movies': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-001',
                      'title': '搜索到的 DBO 影片',
                      'can_play': true,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineSearchPage()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '关键词');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(queries.last['movie_type'], 'all');

    // 页头筛选按钮打开弹层，选择类型与资源条件后立即按参数重搜。
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('资源条件'), findsOneWidget);

    await tester.tap(find.text('无码').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('字幕').first);
    await tester.pumpAndSettle();

    expect(queries.last['movie_type'], '1');
    expect(queries.last['movie_filter_by'], 'subtitle');
    expect(find.text('搜索到的 DBO 影片'), findsOneWidget);
  });

  testWidgets('列表搜索的列表模式有预览图用预览条目，缺失预览图降级紧凑行', (tester) async {
    SharedPreferences.setMockInitialValues({
      'db_online.search.view_mode.v1': 'list',
    });
    final preferences = await SharedPreferences.getInstance();
    var withPreviewImages = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'movies': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-001',
                      'title': '搜索到的 DBO 影片',
                      'can_play': true,
                      if (withPreviewImages)
                        'preview_images': [
                          {
                            'large_url': 'https://example.test/l1.jpg',
                            'thumb_url': 'https://example.test/s1.jpg',
                          },
                          {'large_url': 'https://example.test/l2.jpg'},
                        ],
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(client.dbOnline)),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
          // 预览图 URL 解析依赖运行时服务器配置。
          mediaRuntimeConfigProvider.overrideWithValue(
            const ServerConfig(baseUrl: 'https://example.test'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineSearchPage()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '关键词');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // 接口返回 preview_images 时列表模式启用预览条目（左封面 + 右翻页）。
    final card = tester.widget<DbOnlineMovieCard>(
      find.byType(DbOnlineMovieCard),
    );
    expect(card.compact, isTrue);
    expect(card.previewList, isTrue);
    expect(find.byType(DbOnlineRankingPreviewCard), findsOneWidget);
    expect(find.byType(CatalogListMovieCard), findsNothing);
    expect(find.byType(PageView), findsOneWidget);

    // 数据未携带 preview_images 时降级为紧凑行，不渲染预览翻页。
    withPreviewImages = false;
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(DbOnlineRankingPreviewCard), findsNothing);
    expect(find.byType(CatalogListMovieCard), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });
}
