import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:omm/core/models/movie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 影片库筛选按钮行与收藏夹 header 固定在顶部,不随内容滚动。
void main() {
  for (final page in [const MoviesPage(), const FavoritesPage()]) {
    testWidgets('${page.runtimeType} 连续刷新合并，旧请求和旧错误不能覆盖新列表', (tester) async {
      final pending = <(RequestOptions, RequestInterceptorHandler)>[];
      await _pumpPage(
        tester,
        page,
        client: _delayedClient(pending),
        settle: false,
      );
      await _waitRequests(tester, pending, 1);
      expect(pending, hasLength(1));
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      var finished = false;
      final first = refresh().then((_) {
        finished = true;
      });
      final second = refresh();
      await _waitRequests(tester, pending, 2);
      expect(pending, hasLength(2));
      await tester.pump(const Duration(milliseconds: 700));
      expect(finished, isFalse);
      _resolvePage(pending[1], 20);
      await tester.pumpAndSettle();
      await Future.wait([first, second]);
      expect(finished, isTrue);
      final controller = tester
          .widget<PagedSliverGrid<int, MovieListItem>>(
            find.byType(PagedSliverGrid<int, MovieListItem>),
          )
          .pagingController;
      expect(controller.itemList!.map((item) => item.id), [20]);
      pending[0].$2.reject(
        DioException(requestOptions: pending[0].$1, error: '过期失败'),
      );
      await tester.pumpAndSettle();
      expect(controller.error, isNull);
      expect(controller.itemList!.map((item) => item.id), [20]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${page.runtimeType} 请求中退出结束刷新且忽略晚到响应', (tester) async {
      final pending = <(RequestOptions, RequestInterceptorHandler)>[];
      await _pumpPage(
        tester,
        page,
        client: _delayedClient(pending),
        settle: false,
      );
      await _waitRequests(tester, pending, 1);
      final future = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await _waitRequests(tester, pending, 2);
      await tester.pumpWidget(const SizedBox());
      await future;
      for (final request in pending) {
        _resolvePage(request, 30);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('影片库筛选后的新结果不会被较慢的旧首屏追加', (tester) async {
    final pending = <(RequestOptions, RequestInterceptorHandler)>[];
    await _pumpPage(
      tester,
      const MoviesPage(),
      client: _delayedClient(pending),
      settle: false,
    );
    await _waitRequests(tester, pending, 1);
    await tester.tap(find.byIcon(Icons.fiber_new_rounded));
    await _waitRequests(tester, pending, 2);
    expect(pending, hasLength(2));
    expect(pending[1].$1.queryParameters['has_new_resources'], isNotNull);
    _resolvePage(pending[1], 40);
    await tester.pumpAndSettle();
    _resolvePage(pending[0], 10);
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PagedSliverGrid<int, MovieListItem>>(
          find.byType(PagedSliverGrid<int, MovieListItem>),
        )
        .pagingController;
    expect(controller.itemList!.map((item) => item.id), [40]);
  });

  testWidgets('影片库标题与筛选按钮行滚动后保持固定', (tester) async {
    await _pumpPage(tester, const MoviesPage());

    final titleBefore = tester.getTopLeft(find.text('影片库'));
    final chipBefore = tester.getTopLeft(find.text('更新状态'));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // header 整体固定:标题行与按钮行位置不变,内容区确实发生了滚动。
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller;
    expect(controller!.offset, greaterThan(0));
    expect(tester.getTopLeft(find.text('影片库')), titleBefore);
    expect(tester.getTopLeft(find.text('更新状态')), chipBefore);

    // 按钮行下方保留固定边距,滚动区不紧贴按钮行。
    final chipsBottom = tester.getBottomRight(find.text('扫描资源')).dy;
    final scrollTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(scrollTop - chipsBottom, greaterThan(14));
  });

  testWidgets('收藏夹标题与操作按钮滚动后保持固定', (tester) async {
    await _pumpPage(tester, const FavoritesPage());

    final titleBefore = tester.getTopLeft(find.text('收藏夹'));
    final scanButtonBefore = tester.getTopLeft(find.byIcon(Icons.settings));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('收藏夹')), titleBefore);
    expect(tester.getTopLeft(find.byIcon(Icons.settings)), scanButtonBefore);
    // 固定区之外的内容正常滚走。
    expect(find.text('已收藏'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  ApiClient? client,
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'privacy.app_switcher_shield': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final api = client ?? _buildFakeClient();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(api),
        ommMediaSourceProvider.overrideWithValue(OmmMediaSourceAdapter(api)),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: page),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

ApiClient _buildFakeClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.uri.path;
        final data = _fakeResponse(options.method, path);
        if (data == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: '未处理的测试请求: ${options.method} $path',
            ),
          );
          return;
        }
        handler.resolve(Response<dynamic>(requestOptions: options, data: data));
      },
    ),
  );
  return ApiClient(dio);
}

Object? _fakeResponse(String method, String path) {
  final normalizedPath = path.startsWith('/api') ? path.substring(4) : path;
  if (method == 'GET' && normalizedPath == '/movies') {
    final items = [
      for (var i = 1; i <= 9; i++) {'id': i, 'title': '影片 $i', 'year': 2024},
    ];
    return {
      'success': true,
      'data': {
        'items': items,
        'total_count': items.length,
        'limit': 50,
        'offset': 0,
      },
    };
  }

  if (method == 'GET' && normalizedPath == '/favorites') {
    final items = [
      for (var i = 1; i <= 6; i++) {'id': i, 'title': '', 'is_favorited': true},
    ];
    return {
      'success': true,
      'data': {
        'items': items,
        'total_count': items.length,
        'limit': 30,
        'offset': 0,
      },
    };
  }

  if (method == 'GET' && normalizedPath == '/lists') {
    return {'success': true, 'data': []};
  }

  if (method == 'POST' &&
      (normalizedPath == '/favorites' ||
          normalizedPath == '/favorites/delete')) {
    return {'success': true, 'data': null};
  }

  return null;
}

ApiClient _delayedClient(
  List<(RequestOptions, RequestInterceptorHandler)> pending,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.uri.path.endsWith('/movies') ||
            options.uri.path.endsWith('/favorites')) {
          pending.add((options, handler));
        } else {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: _fakeResponse(options.method, options.uri.path),
            ),
          );
        }
      },
    ),
  );
  return ApiClient(dio);
}

void _resolvePage((RequestOptions, RequestInterceptorHandler) request, int id) {
  request.$2.resolve(
    Response<dynamic>(
      requestOptions: request.$1,
      data: {
        'success': true,
        'data': {
          'items': [
            {'id': id, 'title': '影片 $id', 'is_favorited': true},
          ],
          'total_count': 1,
          'limit': 50,
          'offset': 0,
        },
      },
    ),
  );
}

Future<void> _waitRequests(WidgetTester tester, List pending, int count) async {
  for (var i = 0; i < 30 && pending.length < count; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(pending, hasLength(count));
}
