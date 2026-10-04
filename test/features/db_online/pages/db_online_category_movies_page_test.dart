import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/pages/db_online_category_movies_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required String categoryId,
    required String categoryName,
    required void Function(String path, Map<String, String> query) onRequest,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          onRequest(
            options.uri.path,
            options.uri.queryParameters.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'videos': [
                    {'id': 'movie-1', 'number': 'ABC-004', 'title': '类别影片'},
                  ],
                  'count': 1,
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
            const ServerConfig(
              baseUrl: 'https://example.test',
              activeServerId: 'server-1',
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: DbOnlineCategoryMoviesPage(
              categoryId: categoryId,
              categoryName: categoryName,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('类别影片页按 external_id 一次性加载并渲染影片卡片', (tester) async {
    String? requestPath;
    var lastQuery = const <String, String>{};
    await pumpPage(
      tester,
      categoryId: 'cat-1',
      categoryName: '类别甲',
      onRequest: (path, query) {
        requestPath = path;
        lastQuery = query;
      },
    );

    expect(requestPath, '/api/videos/filter');
    expect(lastQuery['category_id'], 'cat-1');
    expect(find.text('类别甲'), findsOneWidget);
    expect(find.text('类别影片'), findsOneWidget);
  });

  testWidgets('无类别 ID 时按名称回退筛选', (tester) async {
    String? requestPath;
    var lastQuery = const <String, String>{};
    await pumpPage(
      tester,
      categoryId: '',
      categoryName: '类别乙',
      onRequest: (path, query) {
        requestPath = path;
        lastQuery = query;
      },
    );

    expect(requestPath, '/api/videos/filter');
    expect(lastQuery.containsKey('category_id'), isFalse);
    expect(lastQuery['category'], '类别乙');
    expect(find.text('类别乙'), findsOneWidget);
  });
}
