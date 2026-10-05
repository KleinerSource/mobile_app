import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/features/db_online/pages/db_online_rankings_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Dio dio,
    bool completedSubscription = false,
  }) async {
    final client = ApiClient(dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requiredApiClientProvider.overrideWithValue(client),
          sharedPrefsProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          mediaRuntimeConfigProvider.overrideWithValue(
            completedSubscription
                ? const ServerConfig(
                    baseUrl: 'https://example.test',
                    activeServerId: 'server-1',
                  )
                : const ServerConfig(baseUrl: 'https://example.test'),
          ),
          if (completedSubscription) ...[
            dbOnlineSubscriptionCapabilitiesProvider.overrideWith(
              (ref, serverId) async => const DbOnlineSubscriptionCapabilities(
                database: true,
                onlineAccount: false,
                onlineQuery: false,
              ),
            ),
            dbOnlineMovieSubscriptionStatusesProvider(
              'server-1',
            ).overrideWith(() => _CompletedStatusesNotifier()),
          ],
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

  testWidgets('列表模式渲染预览条目：封面 + 预览图翻页 + 标题', (tester) async {
    SharedPreferences.setMockInitialValues({
      mediaServerViewModeStorageKey(null): 'list',
    });
    final requests = <String>[];
    await pumpPage(
      tester,
      dio: rankingDio(top250Authorized: false, requests: requests),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('[ABC-001] 榜单影片'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // 名次徽章
    // 磁链角标叠加在预览图内，不再单独占用标题下的一行。
    expect(find.text('3'), findsOneWidget);
    final preview = tester.getRect(find.byType(PageView));
    final magnet = tester.getRect(find.text('3'));
    expect(magnet.top, greaterThan(preview.top));
    expect(magnet.bottom, lessThan(preview.bottom));
    expect(magnet.left, greaterThan(preview.left));
  });

  testWidgets('订阅已完成的绿点放在名称前，其余角标叠加预览图左下角', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      mediaServerViewModeStorageKey(null): 'list',
    });
    final requests = <String>[];
    await pumpPage(
      tester,
      dio: rankingDio(top250Authorized: false, requests: requests),
      completedSubscription: true,
    );

    expect(find.byType(PageView), findsOneWidget);
    final dot = find.bySemanticsLabel('已完成');
    expect(dot, findsOneWidget);
    final title = find.text('[ABC-001] 榜单影片');
    expect(title, findsOneWidget);
    expect(
      tester.getCenter(dot).dy,
      closeTo(tester.getRect(title).top + 8.4, 3),
    );
    expect(tester.getRect(dot).right, lessThan(tester.getRect(title).left));
    // 磁链角标仍在预览图左下角。
    final preview = tester.getRect(find.byType(PageView));
    final magnet = tester.getRect(find.text('3'));
    expect(magnet.bottom, lessThan(preview.bottom));
  });
}

/// 预置 ABC-001 已完成订阅状态，避免卡片触发批量状态查询。
class _CompletedStatusesNotifier
    extends DbOnlineMovieSubscriptionStatusesNotifier {
  _CompletedStatusesNotifier() : super('server-1');

  @override
  Map<String, DbOnlineSubscriptionStatus> build() {
    return {
      ...super.build(),
      'ABC-001': const DbOnlineSubscriptionStatus(
        subscribed: true,
        sourceType: 'video',
        status: 'completed',
        active: true,
      ),
    };
  }
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
          'magnets_count': 3,
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
    '/api/actors' => {
      'actors': [
        {'id': 'actor-1', 'name': '榜单演员'},
      ],
    },
    _ => <String, dynamic>{},
  };
  return {'success': true, 'data': data};
}
