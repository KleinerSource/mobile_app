import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

    // 页头筛选按钮打开弹层，选择资源条件后按参数重新加载。
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('资源条件'), findsOneWidget);

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
}

class _CanPlayConfigController extends DbOnlineBackendConfigController {
  @override
  Future<Map<String, dynamic>> build() async => {
    'javdb_api': {'can_play': true},
  };
}
