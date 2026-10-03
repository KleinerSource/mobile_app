import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('实体影片页按实体端点加载并渲染影片卡片', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    String? requestPath;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPath = options.uri.path;
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

    expect(requestPath, '/api/makers/mk-1/movies');
    expect(find.text('示例片商'), findsOneWidget);
    expect(find.text('片商影片'), findsOneWidget);
  });
}
