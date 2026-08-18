import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:md_center/core/api/api_client.dart';
import 'package:md_center/core/api/services/favorites_api.dart';
import 'package:md_center/core/api/providers.dart';
import 'package:md_center/core/config/server_config_provider.dart';
import 'package:md_center/features/actors/actor_management_page.dart';
import 'package:md_center/features/favorites/favorites_page.dart';
import 'package:md_center/features/favorites/favorites_providers.dart';
import 'package:md_center/features/favorites/favorites_repository.dart';
import 'package:md_center/features/movies/movies_page.dart';
import 'package:md_center/l10n/generated/app_localizations.dart';
import 'package:md_center/shared/entity_batch_toolbar.dart';
import 'package:md_center/shared/movie_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('影片网格长按滑动同步工具栏和勾选状态', (tester) async {
    await _pumpPage(tester, const MoviesPage(maxItems: 9));

    final first = find.byKey(const ValueKey<int>(1));
    final second = find.byKey(const ValueKey<int>(2));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(find.byType(MovieCard), findsWidgets);

    final gesture = await _longPress(tester, first);
    expect(find.byType(EntityBatchToolbar), findsOneWidget);
    expect(find.text('1 已选'), findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    await gesture.moveTo(tester.getCenter(second));
    await tester.pump();
    expect(find.text('2 已选'), findsOneWidget);
    expect(
      find.descendant(of: second, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump();
  });

  testWidgets('影片网格按手指命中的卡片选择连续范围', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, const MoviesPage(maxItems: 9));

    final crossAxisCount = tester.getSize(find.byType(Scaffold)).width > 600
        ? 4
        : 3;
    final first = find.byKey(const ValueKey<int>(1));
    final firstRowEnd = find.byKey(ValueKey<int>(crossAxisCount));
    final secondRowStart = find.byKey(ValueKey<int>(crossAxisCount + 1));
    final thirdRowStart = find.byKey(ValueKey<int>(crossAxisCount * 2 + 1));

    var gesture = await _longPress(tester, first);
    await gesture.moveTo(tester.getCenter(firstRowEnd));
    await gesture.up();
    await tester.pump();
    expect(find.text('$crossAxisCount 已选'), findsOneWidget);

    expect(secondRowStart, findsOneWidget);
    expect(thirdRowStart, findsOneWidget);

    gesture = await _longPress(tester, secondRowStart);
    await gesture.moveTo(tester.getCenter(thirdRowStart));
    await gesture.up();
    await tester.pump();
    expect(find.text('9 已选'), findsOneWidget);
  });

  testWidgets('演员普通列表长按滑动同步工具栏和滚动偏移', (tester) async {
    await _pumpPage(tester, const ActorManagementPage());

    final listFinder = find.byType(CustomScrollView);
    final first = find.byKey(const ValueKey<int>(1));
    final second = find.byKey(const ValueKey<int>(2));
    expect(listFinder, findsOneWidget);
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);

    final gesture = await _longPress(tester, first);
    await gesture.moveTo(tester.getCenter(second));
    await tester.pump();
    expect(find.byType(EntityBatchToolbar), findsOneWidget);
    expect(find.text('2 已选'), findsOneWidget);

    final viewport = tester.getRect(listFinder);
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
    await _pumpFrames(tester, const Duration(milliseconds: 350));
    final controller = tester.widget<CustomScrollView>(listFinder).controller!;
    expect(controller.offset, greaterThan(0));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('收藏夹列表仍保留左滑移除', (tester) async {
    await _pumpPage(tester, const FavoritesPage());

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey<int>(1));
    expect(first, findsOneWidget);
    expect(find.byType(Dismissible), findsWidgets);

    await tester.fling(
      find.byType(Dismissible).first,
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<int>(1)), findsNothing);
  });

  testWidgets('影片库列表支持左滑收藏且保留影片', (tester) async {
    final favoritesApi = _RecordingFavoritesApi();
    await _pumpPage(
      tester,
      const MoviesPage(maxItems: 9),
      favoritesRepository: FavoritesRepository(favoritesApi),
    );

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsWidgets);

    await tester.fling(
      find.byType(Dismissible).first,
      const Offset(-500, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(find.text('已收藏「影片 1」'), findsOneWidget);
    expect(favoritesApi.addedMovieIds, [1]);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  FavoritesRepository? favoritesRepository,
}) async {
  SharedPreferences.setMockInitialValues({
    'privacy.app_switcher_shield': false,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(_buildFakeClient()),
        sharedPrefsProvider.overrideWithValue(prefs),
        if (favoritesRepository != null)
          favoritesRepositoryProvider.overrideWithValue(favoritesRepository),
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

Future<TestGesture> _longPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  return gesture;
}

Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
    await tester.pump(frame);
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

  if (method == 'GET' && normalizedPath == '/actors') {
    final actors = [
      for (var i = 1; i <= 100; i++)
        {'id': i, 'name': '演员 $i', 'movie_count': i},
    ];
    return {
      'success': true,
      'data': actors,
      'total_count': actors.length,
      'limit': 100,
      'offset': 0,
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

  if (method == 'POST' && normalizedPath == '/favorites/batch-delete') {
    return {'success': true, 'data': null};
  }

  if (method == 'POST' && normalizedPath == '/favorites') {
    return {'success': true, 'data': null};
  }

  return null;
}

class _RecordingFavoritesApi implements FavoritesApi {
  List<int>? addedMovieIds;

  @override
  Future<dynamic> addBatch(Map<String, dynamic> body) async {
    addedMovieIds = List<int>.from(body['movie_ids'] as List);
    return {'success': true, 'data': null};
  }

  @override
  Future<dynamic> list(Map<String, dynamic> q) async =>
      throw UnimplementedError();

  @override
  Future<dynamic> removeBatch(Map<String, dynamic> body) async =>
      throw UnimplementedError();

  @override
  Future<dynamic> status(int movieId) async => throw UnimplementedError();

  @override
  Future<dynamic> toggle(int movieId) async => throw UnimplementedError();
}
