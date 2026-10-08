import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/dbo_media_source_adapter.dart';
import 'package:omm/features/db_online/pages/db_online_entity_movies_page.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _popTopRoute(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();

/// 系列/类型区块可能在视口外未被 sliver 构建，先滚动到可见再点击。
Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  // 悬浮页头遮住视口顶部：目标贴顶时先向下补滚，避免点击命中页头。
  var top = tester.getTopLeft(finder).dy;
  for (var i = 0; top < 150 && i < 10; i++) {
    await tester.drag(scrollable, const Offset(0, 80));
    await tester.pumpAndSettle();
    top = tester.getTopLeft(finder).dy;
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

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
          home: DbOnlineMovieDetailPage(detailKey: 'ABC-001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return requestPaths;
  }

  /// 记录完整请求地址（含 query），用于校验双主键 key 的请求路径。
  Future<List<Uri>> pumpDetailUris(
    WidgetTester tester, {
    String? videoId,
    Map<String, dynamic> Function()? detailData,
    Brightness brightness = Brightness.light,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestUris = <Uri>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestUris.add(options.uri);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'source': 'database',
                'data': detailData != null
                    ? detailData()
                    : {
                        'code': 'ABC-001',
                        'title': '消歧测试影片',
                        'magnets': [],
                        'ed2ks': [],
                      },
              },
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(preferences),
          mediaRuntimeConfigProvider.overrideWithValue(config),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(DbOnlineApi(dio))),
          ),
          dbOnlineSubscriptionCapabilitiesProvider.overrideWith(
            (ref, serverId) async => const DbOnlineSubscriptionCapabilities(
              database: false,
              onlineAccount: false,
              onlineQuery: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: DbOnlineMovieDetailPage(detailKey: videoId ?? 'ABC-001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return requestUris;
  }

  testWidgets('详情以 video_id 为主键发起请求', (tester) async {
    final uris = await pumpDetailUris(tester, videoId: 'v-42');

    final detailRequests = uris
        .where((uri) => uri.path == '/api/video/v-42')
        .toList();
    expect(detailRequests, isNotEmpty);
    expect(
      uris.any((uri) => uri.path == '/api/video/ABC-001'),
      isFalse,
      reason: '携带 video_id 的入口必须以 video_id 为路径主键，由服务端'
          '优先按 video_id 解析，避免同番号多条影片时详情对不上',
    );
  });

  /// 为系统分享注册平台消息 mock，返回收到的分享文本列表。
  List<String?> mockShare(WidgetTester tester) {
    final shareTexts = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        if (call.method == 'share') {
          shareTexts.add((call.arguments as Map)['text']?.toString());
        }
        return 'dev.fluttercommunity.plus/share/success';
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        null,
      );
    });
    return shareTexts;
  }

  Future<void> pumpShareDetail(WidgetTester tester) async {
    await pumpDetailUris(tester, videoId: 'v-42', detailData: () {
      return {
        'code': 'ABC-001',
        'video_id': 'v-9',
        'title': '分享测试影片',
        'magnets': [],
        'ed2ks': [],
      };
    });
  }

  testWidgets('详情更多菜单分享项位于列表最后并拉起系统分享', (tester) async {
    final shareTexts = mockShare(tester);
    await pumpShareDetail(tester);

    final menu = find.byType(HeaderMenuButton<String>);
    await tester.tapAt(tester.getRect(menu).topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('分享'), findsOneWidget);
    // 分享是出口操作，排在资源/字幕功能项之后。
    expect(
      tester.getTopLeft(find.text('分享')).dy,
      greaterThan(tester.getTopLeft(find.text('获取字幕')).dy),
    );
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();

    expect(shareTexts, ['https://example.test/video/v-9?code=ABC-001']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('详情更多菜单在番号缺失时仍可按 video_id 分享', (tester) async {
    final shareTexts = mockShare(tester);
    await pumpDetailUris(tester, detailData: () {
      return {
        'code': '',
        'video_id': 'v-only',
        'title': '无番号影片',
        'magnets': [],
        'ed2ks': [],
      };
    });

    final menu = find.byType(HeaderMenuButton<String>);
    await tester.tapAt(tester.getRect(menu).topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('分享'), findsOneWidget);
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();
    expect(shareTexts, ['https://example.test/video/v-only']);
  });

  testWidgets('详情更多沿用封面悬浮栏风格并保留资源与字幕菜单', (tester) async {
    await pumpDetail(tester, hasCnsub: true);
    final menu = find.byType(HeaderMenuButton<String>);
    expect(menu, findsOneWidget);
    final back = find.widgetWithIcon(HeaderActionButton, Icons.arrow_back);
    expect(tester.widget<HeaderMenuButton<String>>(menu).tooltip, '更多');
    expect(
      tester.widget<HeaderMenuButton<String>>(menu).style,
      tester.widget<HeaderActionButton>(back).style,
    );
    expect(tester.getSize(menu), tester.getSize(back));
    expect(
      tester.getSize(
        find.descendant(of: menu, matching: find.byType(HeaderActionIcon)),
      ),
      tester.getSize(
        find.descendant(of: back, matching: find.byType(HeaderActionIcon)),
      ),
    );
    await tester.tapAt(tester.getRect(menu).topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('在线资源'), findsOneWidget);
    expect(find.text('获取字幕'), findsOneWidget);
    await tester.tapAt(const Offset(10, 200));
    await tester.pumpAndSettle();
    expect(find.text('在线资源'), findsNothing);
    expect(find.byType(DbOnlineMovieDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情字幕徽标按 has_cnsub 显示', (tester) async {
    final requestPaths = await pumpDetail(tester, hasCnsub: true);

    expect(find.byIcon(Icons.closed_caption_rounded), findsOneWidget);
    expect(requestPaths, isNot(contains('/subtitle/find/ABC-001')));
  });

  testWidgets('has_cnsub 为 false 时不显示详情字幕徽标', (tester) async {
    await pumpDetail(tester, hasCnsub: false);

    expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
  });

  testWidgets('已入库徽标按媒体库来源显示名称和配色', (tester) async {
    const cases = <({String source, Color color, Color ink})>[
      (source: 'Emby', color: Color(0xFF48C97D), ink: Color(0xFF1F7A4B)),
      (source: 'Jellyfin', color: Color(0xFF9B6FFF), ink: Color(0xFF6D28D9)),
      (source: 'FNOS', color: Color(0xFF4A9EFF), ink: Color(0xFF1F5FA8)),
    ];

    for (final item in cases) {
      await pumpDetailUris(
        tester,
        detailData: () => {
          'code': 'ABC-001',
          'title': '已入库配色测试',
          'library': {'in_library': true, 'source': item.source},
          'magnets': [],
          'ed2ks': [],
        },
      );

      final label = '已入库 (${item.source})';
      expect(find.text(label), findsOneWidget);
      final badgeFinder = find.ancestor(
        of: find.text(label),
        matching: find.byType(CoverBadgePill),
      );
      final badge = tester.widget<CoverBadgePill>(badgeFinder);
      expect(badge.color, item.color);
      expect(badge.backgroundColor, item.color.withValues(alpha: 0.18));
      expect(badge.foregroundColor, item.ink);
      expect(badge.borderColor, item.color.withValues(alpha: 0.4));
      expect(badge.shadowColor, item.color.withValues(alpha: 0.24));
    }
  });

  testWidgets('已入库徽标深色主题按媒体库来源使用浅色文字', (tester) async {
    const cases = <({String source, Color ink})>[
      (source: 'Emby', ink: Color(0xFF76E3A5)),
      (source: 'Jellyfin', ink: Color(0xFFC9ADFF)),
      (source: 'FNOS', ink: Color(0xFF8BC3FF)),
    ];

    for (final item in cases) {
      await pumpDetailUris(
        tester,
        brightness: Brightness.dark,
        detailData: () => {
          'code': 'ABC-001',
          'title': '深色主题配色测试',
          'library': {'in_library': true, 'source': item.source},
          'magnets': [],
          'ed2ks': [],
        },
      );

      final label = find.text('已入库 (${item.source})');
      final badgeFinder = find.ancestor(
        of: label,
        matching: find.byType(CoverBadgePill),
      );
      expect(
        tester.widget<CoverBadgePill>(badgeFinder).foregroundColor,
        item.ink,
      );
    }
  });

  testWidgets('缺失或未知媒体库来源回退到媒体库文案和 Emby 绿', (tester) async {
    for (final source in <String?>[null, 'Other Server']) {
      await pumpDetailUris(
        tester,
        detailData: () => {
          'code': 'ABC-001',
          'title': '默认配色测试',
          'library': {'in_library': true, if (source != null) 'source': source},
          'magnets': [],
          'ed2ks': [],
        },
      );

      final label = source == null ? '已入库 (媒体库)' : '已入库 (Other Server)';
      expect(find.text(label), findsOneWidget);
      final badgeFinder = find.ancestor(
        of: find.text(label),
        matching: find.byType(CoverBadgePill),
      );
      expect(
        tester.widget<CoverBadgePill>(badgeFinder).color,
        const Color(0xFF48C97D),
      );
    }
  });

  testWidgets('已入库标识只由 library.in_library 控制', (tester) async {
    await pumpDetailUris(
      tester,
      detailData: () => {
        'code': 'ABC-001',
        'title': '未入库测试',
        'can_play': true,
        'library': {'in_library': false, 'source': 'Jellyfin'},
        'magnets': [],
        'ed2ks': [],
      },
    );

    expect(find.text('已入库 (Jellyfin)'), findsNothing);
  });

  testWidgets('详情导演/片商/发行商/演员/系列/类型点击进入实体列表页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestPaths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPaths.add(options.uri.path);
          final path = options.uri.path;
          const entityPrefixes = [
            '/actors/',
            '/series/',
            '/makers/',
            '/publishers/',
            '/directors/',
            '/categories/',
          ];
          Object? data;
          if (entityPrefixes.any(path.startsWith)) {
            data = {
              'movies': [
                {'id': 'movie-1', 'number': 'ABC-002', 'title': '列表影片'},
              ],
              'current_page': 1,
            };
          } else {
            data = {
              'code': 'ABC-001',
              'title': '跳转测试影片',
              'director': {'external_id': 'director-1', 'name': '导演甲'},
              'maker': {'external_id': 'maker-1', 'name': '片商甲'},
              'publisher': {'external_id': 'publisher-1', 'name': '发行商甲'},
              'actors': [
                {'external_id': 'actor-1', 'name': '演员甲'},
              ],
              'series': {'external_id': 'series-1', 'name': '系列甲'},
              'categories': [
                {'external_id': 'cat-1', 'name': '类别甲'},
                {'name': '类别乙'},
              ],
              'magnets': [],
              'ed2ks': [],
            };
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {'success': true, 'source': 'database', 'data': data},
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(preferences),
          mediaRuntimeConfigProvider.overrideWithValue(config),
          requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
          dboMediaRepositoryProvider.overrideWithValue(
            DboMediaRepository(DboMediaSourceAdapter(DbOnlineApi(dio))),
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
          home: DbOnlineMovieDetailPage(detailKey: 'ABC-001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 演员卡片 → 演员实体影片页。
    await tester.tap(find.text('演员甲'));
    await tester.pumpAndSettle();
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/actors/actor-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 系列 Chip → 系列实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 系列甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/series/series-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 导演 Chip → 导演实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 导演甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/directors/director-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 片商 Chip → 片商实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 片商甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/makers/maker-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 发行商 Chip → 发行商实体影片页。
    await _scrollToAndTap(tester, find.text('◇ 发行商甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/publishers/publisher-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 有 external_id 的类型 Chip → 类别实体影片页（/categories 端点）。
    await _scrollToAndTap(tester, find.text('类别甲'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsOneWidget);
    expect(requestPaths, contains('/api/categories/cat-1/movies'));
    _popTopRoute(tester);
    await tester.pumpAndSettle();

    // 无 external_id 的类型 Chip 不可跳转，停留在详情页。
    await _scrollToAndTap(tester, find.text('类别乙'));
    expect(find.byType(DbOnlineEntityMoviesPage), findsNothing);
  });
}
