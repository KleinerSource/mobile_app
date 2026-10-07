import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('实体页刷新未完成时切换筛选，旧响应不能覆盖新筛选结果', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pending =
        <({RequestOptions options, RequestInterceptorHandler handler})>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!options.path.contains('/makers/mk-1/movies')) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {'success': true, 'data': <String, dynamic>{}},
              ),
            );
            return;
          }
          pending.add((options: options, handler: handler));
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: DbOnlineEntityMoviesPage(
            kind: 'maker',
            id: 'mk-1',
            title: '片商',
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(pending, hasLength(1));
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final done = refresh();
    expect(identical(done, refresh()), isTrue);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('字幕').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final filtered = pending
        .where((r) => r.options.uri.queryParameters['filter'] == 'c')
        .toList();
    expect(filtered, hasLength(1));
    expect(filtered.single.options.uri.queryParameters['page'], '1');
    for (final request in pending.reversed) {
      final isFiltered = identical(request.handler, filtered.single.handler);
      request.handler.resolve(
        Response<dynamic>(
          requestOptions: request.options,
          data: {
            'success': true,
            'data': {
              'movies': [
                {
                  'id': isFiltered ? 'new' : 'old',
                  'title': isFiltered ? '筛选后影片' : '旧影片',
                },
              ],
              'current_page': 1,
            },
          },
        ),
      );
    }
    await tester.pumpAndSettle();
    await done;
    expect(find.text('筛选后影片'), findsOneWidget);
    expect(find.text('旧影片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('实体影片页按实体端点加载并渲染影片卡片', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    String? requestPath;
    var lastQuery = const <String, String>{};
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPath = options.uri.path;
          lastQuery = options.uri.queryParameters;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'movies': [
                    {
                      'id': 'movie-1',
                      'number': 'ABC-003',
                      'title': '片商影片',
                      'can_play': true,
                    },
                  ],
                  'current_page': 1,
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
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.paddingOf(context).copyWith(bottom: 34),
            ),
            child: child!,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: DbOnlineEntityMoviesPage(
              kind: 'maker',
              id: 'mk-1',
              title: '示例片商',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestPath, '/api/makers/mk-1/movies');
    expect(find.text('示例片商'), findsOneWidget);
    expect(find.text('片商影片'), findsOneWidget);
    final page = find.byType(DbOnlineEntityMoviesPage);
    final safeArea = find
        .descendant(of: page, matching: find.byType(SafeArea))
        .first;
    expect(tester.widget<SafeArea>(safeArea).bottom, isFalse);
    final pageScaffold = find
        .descendant(of: page, matching: find.byType(Scaffold))
        .first;
    expect(
      tester.getRect(safeArea).bottom,
      tester.getRect(pageScaffold).bottom,
    );
    final contentPadding = tester.widget<SliverPadding>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(SliverPadding),
      ).first,
    );
    expect(
      contentPadding.padding.resolve(TextDirection.ltr).bottom,
      34,
    );

    // 页头筛选按钮打开弹层，选择资源条件后按参数重新加载。
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('资源条件'), findsOneWidget);
    expect(tester.widget<SafeArea>(find.byType(SafeArea).last).bottom, isTrue);

    await tester.tap(find.text('字幕').first);
    await tester.pumpAndSettle();

    expect(requestPath, '/api/makers/mk-1/movies');
    expect(lastQuery['filter'], 'c');
    expect(lastQuery['sort_by'], 'release');
  });

  testWidgets('服务端 can_play 开启时资源条件提供可播放（p）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var lastQuery = const <String, String>{};
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          lastQuery = options.uri.queryParameters;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'movies': [
                    {'id': 'movie-1', 'number': 'ABC-003', 'title': '片商影片'},
                  ],
                  'current_page': 1,
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
          sharedPrefsProvider.overrideWithValue(preferences),
          dbOnlineBackendConfigProvider.overrideWith(
            () => _CanPlayConfigController(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(
            body: DbOnlineEntityMoviesPage(
              kind: 'maker',
              id: 'mk-1',
              title: '示例片商',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('可播放'), findsOneWidget);

    await tester.tap(find.text('可播放'));
    await tester.pumpAndSettle();

    expect(lastQuery['filter'], 'p');
  });

  testWidgets('列表模式渲染预览条目：封面 + 预览图翻页 + 标题', (tester) async {
    SharedPreferences.setMockInitialValues({
      mediaServerViewModeStorageKey(null): 'list',
    });
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
                      'number': 'ABC-003',
                      'title': '片商影片',
                      'can_play': true,
                      'preview_images': [
                        {
                          'large_url': 'https://example.test/l1.jpg',
                          'thumb_url': 'https://example.test/s1.jpg',
                        },
                        {'large_url': 'https://example.test/l2.jpg'},
                      ],
                    },
                  ],
                  'current_page': 1,
                },
              },
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
          sharedPrefsProvider.overrideWithValue(preferences),
          mediaRuntimeConfigProvider.overrideWithValue(
            const ServerConfig(baseUrl: 'https://example.test'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(
            body: DbOnlineEntityMoviesPage(
              kind: 'maker',
              id: 'mk-1',
              title: '示例片商',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('[ABC-003] 片商影片'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });
}

class _CanPlayConfigController extends DbOnlineBackendConfigController {
  @override
  Future<Map<String, dynamic>> build() async => {
    'javdb_api': {'can_play': true},
  };
}
