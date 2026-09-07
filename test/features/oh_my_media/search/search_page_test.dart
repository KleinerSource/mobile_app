import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/search/search_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('演员影片过滤不会序列化已移除的 search_type=actor', () {
    final query = const MovieFilter(
      search: '演员甲',
      searchType: MovieSearchType.actor,
      actorIds: [7],
    ).toQuery(limit: 60, offset: 0);

    expect(query['actor_ids'], '7');
    expect(query.containsKey('search'), isFalse);
    expect(query.containsKey('search_type'), isFalse);
  });

  testWidgets('切换搜索词时旧请求不会覆盖新结果或留下加载状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final query = options.queryParameters['search']?.toString() ?? '';
          if (query == '旧') {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
          final item = query == '新'
              ? {'id': 2, 'title': '新结果'}
              : {'id': 1, 'title': '旧结果'};
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'items': [item],
                  'total_count': 1,
                  'limit': 60,
                  'offset': 0,
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    final source = OmmMediaSourceAdapter(client);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          mediaRepositoryProvider.overrideWithValue(
            MediaRepository(
              catalog: source,
              details: source,
              operations: source.operations,
            ),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: SearchPage()),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.enterText(field, '旧');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, '新');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('新结果'), findsWidgets);
    expect(find.text('旧结果'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('新结果'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('搜索框可以切换影片、番号、演员和文件名类型', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    String? actorSearchPath;
    String? movieSearchType;
    String? movieActorIds;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          if (path.endsWith('/actors/search')) {
            actorSearchPath = path;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': [
                    {'id': 7, 'name': '演员甲'},
                  ],
                  'has_more': false,
                  'limit': 8,
                  'offset': 0,
                },
              ),
            );
            return;
          }
          movieSearchType = options.queryParameters['search_type']?.toString();
          movieActorIds = options.queryParameters['actor_ids']?.toString();
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'items': [
                    {'id': 1, 'title': '演员结果'},
                  ],
                  'total_count': 1,
                  'limit': 60,
                  'offset': 0,
                },
              },
            ),
          );
        },
      ),
    );

    final client = ApiClient(dio);
    final source = OmmMediaSourceAdapter(client);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          ommMediaSourceProvider.overrideWithValue(source),
          mediaRepositoryProvider.overrideWithValue(
            MediaRepository(
              catalog: source,
              details: source,
              operations: source.operations,
            ),
          ),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: SearchPage()),
        ),
      ),
    );

    await tester.tap(find.text('影片').first);
    await tester.pumpAndSettle();
    expect(find.text('番号'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('文件名'), findsOneWidget);
    await tester.tap(find.text('演员'));

    await tester.enterText(find.byType(TextField), '演员甲');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(actorSearchPath, '/api/actors/search');
    expect(find.text('演员甲'), findsWidgets);

    await tester.tap(find.text('演员甲').last);
    await tester.pumpAndSettle();

    expect(movieSearchType, isNull);
    expect(movieActorIds, '7');
    expect(find.text('演员结果'), findsWidgets);
  });

  testWidgets('暗色模式下搜索类型菜单支持长按滑动选择并显示 icon', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: SearchPage()),
        ),
      ),
    );

    final anchor = find.text('影片').first;
    expect(anchor, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.movie_outlined), findsWidgets);
    expect(find.byIcon(Icons.numbers_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('演员')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('演员'), findsOneWidget);
  });
}
