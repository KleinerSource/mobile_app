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
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config_provider.dart';
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
}
