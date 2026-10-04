import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/pages/db_online_rankings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Dio dio,
  }) async {
    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          sharedPrefsProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(body: DbOnlineRankingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Dio rankingDio({
    required bool top250Authorized,
    List<String> requests = const [],
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.uri.path);
          handler.resolve(
            Response<dynamic>(requestOptions: options, data: _responseFor(
              options.uri.path,
              top250Authorized: top250Authorized,
            )),
          );
        },
      ),
    );
    return dio;
  }

  testWidgets('默认打开日榜并显示名次徽章，未配置 Authorization 时隐藏 Top250', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <String>[];
    await pumpPage(
      tester,
      dio: rankingDio(top250Authorized: false, requests: requests),
    );

    expect(find.text('排行榜'), findsOneWidget);
    expect(find.text('Top250'), findsNothing);
    expect(find.text('日榜'), findsOneWidget);
    expect(requests, containsAll(['/api/config', '/api/rankings']));
    expect(find.text('榜单影片'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('配置 Authorization 后显示 Top250 榜单入口与筛选操作', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <String>[];
    await pumpPage(
      tester,
      dio: rankingDio(top250Authorized: true, requests: requests),
    );

    expect(find.text('Top250'), findsOneWidget);
    await tester.tap(find.text('Top250'));
    await tester.pumpAndSettle();

    expect(requests, contains('/api/top250'));
    // 筛选与一键订阅已移至页头右上角的圆形按钮，通过 tooltip 定位。
    expect(find.byTooltip('筛选'), findsOneWidget);
    expect(find.byTooltip('一键订阅'), findsOneWidget);
    expect(find.byTooltip('排行榜自动订阅'), findsOneWidget);
    expect(find.text('榜单影片'), findsOneWidget);
  });

  testWidgets('切换演员榜请求演员接口并渲染演员卡片', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <String>[];
    await pumpPage(
      tester,
      dio: rankingDio(top250Authorized: false, requests: requests),
    );

    await tester.tap(find.text('演员榜'));
    await tester.pumpAndSettle();

    expect(requests, contains('/api/actors'));
    expect(find.text('榜单演员'), findsOneWidget);
  });
}

Map<String, dynamic> _responseFor(String path, {required bool top250Authorized}) {
  final data = switch (path) {
    '/api/config' => {
      'javdb_api': {
        if (top250Authorized) 'authorization': 'Bearer token',
      },
    },
    '/api/rankings' || '/api/top250' => {
      'movies': [
        {
          'id': 'vid-1',
          'number': 'ABC-001',
          'title': '榜单影片',
          'can_play': true,
        },
      ],
    },
    '/api/actors' => {
      'actors': [
        {'id': 'actor-1', 'name': '榜单演员'},
      ],
    },
    _ => <String, dynamic>{},
  };
  return {'success': true, 'data': data};
}
