import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('详情字幕徽标按 has_cnsub 显示', (tester) async {
    final requestPaths = await pumpDetail(tester, hasCnsub: true);

    expect(find.byIcon(Icons.closed_caption_rounded), findsOneWidget);
    expect(requestPaths, isNot(contains('/subtitle/find/ABC-001')));
  });

  testWidgets('has_cnsub 为 false 时不显示详情字幕徽标', (tester) async {
    await pumpDetail(tester, hasCnsub: false);

    expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
  });
}
