import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:md_center/core/api/api_client.dart';
import 'package:md_center/core/api/providers.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/favorites/favorites_page.dart';
import 'package:md_center/features/movies/movies_page.dart';
import 'package:md_center/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 影片库筛选按钮行与收藏夹 header 固定在顶部,不随内容滚动。
void main() {
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

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  SharedPreferences.setMockInitialValues({
    'privacy.app_switcher_shield': false,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(_buildFakeClient()),
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
  await tester.pumpAndSettle();
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
