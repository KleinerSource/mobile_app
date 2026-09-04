import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/oh_my_media/actors/actor_management_page.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_page.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_providers.dart';
import 'package:omm/features/oh_my_media/favorites/media_favorites_repository.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/swipe_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('影片库和收藏夹分别保存视图模式', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();

    await _pumpPage(tester, const MoviesPage(maxItems: 9), preferences: prefs);
    expect(find.byType(SwipeActionCell), findsNothing);
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(prefs.getString('movies.view_mode.v1'), 'list');

    await _pumpPage(tester, const MoviesPage(maxItems: 9), preferences: prefs);
    expect(find.byType(SwipeActionCell), findsWidgets);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(prefs.getString('movies.view_mode.v1'), 'grid');

    await _pumpPage(tester, const MoviesPage(maxItems: 9), preferences: prefs);
    expect(find.byType(SwipeActionCell), findsNothing);

    await _pumpPage(tester, const FavoritesPage(), preferences: prefs);
    expect(find.byType(SwipeActionCell), findsNothing);
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(prefs.getString('favorites.view_mode.v1'), 'list');

    await _pumpPage(tester, const FavoritesPage(), preferences: prefs);
    expect(find.byType(SwipeActionCell), findsWidgets);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(prefs.getString('favorites.view_mode.v1'), 'grid');

    await _pumpPage(tester, const FavoritesPage(), preferences: prefs);
    expect(find.byType(SwipeActionCell), findsNothing);
  });

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
    final secondRowEnd = find.byKey(ValueKey<int>(crossAxisCount * 2));
    final thirdRowStart = find.byKey(ValueKey<int>(crossAxisCount * 2 + 1));

    var gesture = await _longPress(tester, first);
    await gesture.moveTo(tester.getCenter(firstRowEnd));
    await gesture.up();
    await tester.pump();
    expect(find.text('$crossAxisCount 已选'), findsOneWidget);

    expect(secondRowStart, findsOneWidget);
    expect(thirdRowStart, findsOneWidget);

    gesture = await _dragFromHandle(tester, secondRowStart);
    await gesture.moveTo(tester.getCenter(secondRowEnd));
    await gesture.moveTo(tester.getCenter(thirdRowStart));
    await gesture.up();
    await tester.pump();
    expect(find.text('9 已选'), findsOneWidget);
  });

  testWidgets('影片网格进入多选后未选中卡片整体变暗', (tester) async {
    await _pumpPage(tester, const MoviesPage(maxItems: 9));

    final first = find.byKey(const ValueKey<int>(1));
    final second = find.byKey(const ValueKey<int>(2));
    expect(find.byType(SelectableMovieCard), findsWidgets);

    double dimOpacity(Finder cell) => tester
        .widget<AnimatedOpacity>(
          find.descendant(of: cell, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    // 多选前全部不透明
    expect(dimOpacity(first), 1.0);
    expect(dimOpacity(second), 1.0);

    // 长按第一张进入多选 (长按即选中)
    final gesture = await _longPress(tester, first);
    await gesture.up();
    await tester.pumpAndSettle();

    // 选中卡全亮, 未选中卡整卡变暗 0.55, 与收藏页一致
    expect(dimOpacity(first), 1.0);
    expect(dimOpacity(second), 0.55);
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
    expect(find.byType(SwipeActionCell), findsWidgets);

    // 拖过按钮区继续拉长默认磁贴，越过阈值提交移除。
    await tester.timedDrag(
      find.byType(SwipeActionCell).first,
      const Offset(-800, 0),
      const Duration(milliseconds: 250),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<int>(1)), findsNothing);
  });

  testWidgets('影片库列表支持左滑收藏且保留影片', (tester) async {
    final favoritesSource = _RecordingFavoritesSource();
    await _pumpPage(
      tester,
      const MoviesPage(maxItems: 9),
      favoritesRepository: MediaFavoritesRepository(favoritesSource),
    );

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SwipeActionCell), findsWidgets);

    // 拖过按钮区继续拉长默认磁贴（收藏），越过阈值提交执行。
    await tester.timedDrag(
      find.byType(SwipeActionCell).first,
      const Offset(-800, 0),
      const Duration(milliseconds: 250),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(find.text('已收藏「影片 1」'), findsOneWidget);
    expect(favoritesSource.addedMovieIds, [1]);
  });

  testWidgets('影片库列表收藏状态实时同步并区分操作颜色', (tester) async {
    final favoritesSource = _RecordingFavoritesSource();
    await _pumpPage(
      tester,
      const MoviesPage(maxItems: 9),
      favoritesRepository: MediaFavoritesRepository(favoritesSource),
    );

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    final cell = find.byType(SwipeActionCell).first;

    await tester.timedDrag(
      cell,
      const Offset(-800, 0),
      const Duration(milliseconds: 250),
    );
    await tester.pumpAndSettle();
    expect(favoritesSource.addedMovieIds, [1]);

    await tester.timedDrag(
      cell,
      const Offset(-800, 0),
      const Duration(milliseconds: 250),
    );
    await tester.pumpAndSettle();
    expect(favoritesSource.removedMovieIds, [1]);
  });

  testWidgets('影片库列表支持从复选框区域向下滑动多选', (tester) async {
    await _pumpPage(tester, const MoviesPage(maxItems: 9));

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();

    final first = find.byKey(const ValueKey<int>(1));
    final second = find.byKey(const ValueKey<int>(2));
    final fourth = find.byKey(const ValueKey<int>(4));
    expect(second, findsOneWidget);
    var gesture = await _longPress(tester, first);
    await gesture.up();
    await tester.pump();
    expect(find.text('1 已选'), findsOneWidget);

    gesture = await _dragFromListSelectionIndicator(tester, second);
    await gesture.moveTo(tester.getCenter(fourth));
    await tester.pump();

    expect(find.text('4 已选'), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('收藏夹列表支持从复选框区域向下滑动多选', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, const FavoritesPage());

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();

    final first = find.byKey(const ValueKey<int>(1));
    final second = find.byKey(const ValueKey<int>(2));
    final fourth = find.byKey(const ValueKey<int>(4));
    expect(second, findsOneWidget);
    var gesture = await _longPress(tester, first);
    await gesture.up();
    await tester.pump();
    expect(find.text('1 已选'), findsOneWidget);

    gesture = await _dragFromListSelectionIndicator(tester, second);
    await gesture.moveTo(tester.getCenter(fourth));
    await tester.pump();

    expect(find.text('4 已选'), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  MediaFavoritesRepository? favoritesRepository,
  SharedPreferences? preferences,
}) async {
  late final SharedPreferences prefs;
  if (preferences != null) {
    prefs = preferences;
  } else {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    prefs = await SharedPreferences.getInstance();
  }
  final client = _buildFakeClient();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requiredApiClientProvider.overrideWithValue(client),
        ommMediaSourceProvider.overrideWithValue(OmmMediaSourceAdapter(client)),
        sharedPrefsProvider.overrideWithValue(prefs),
        mediaRepositoryProvider.overrideWithValue(_testMediaRepository()),
        favoritesRepositoryProvider.overrideWithValue(
          favoritesRepository ??
              MediaFavoritesRepository(_DefaultTestMediaSource()),
        ),
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

Future<TestGesture> _dragFromHandle(WidgetTester tester, Finder target) {
  final rect = tester.getRect(target);
  return tester.startGesture(rect.topLeft + const Offset(12, 12));
}

Future<TestGesture> _dragFromListSelectionIndicator(
  WidgetTester tester,
  Finder target,
) {
  final rect = tester.getRect(target);
  return tester.startGesture(Offset(rect.left + 11, rect.center.dy));
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

  if (method == 'POST' && normalizedPath == '/favorites/delete') {
    return {'success': true, 'data': null};
  }

  if (method == 'POST' && normalizedPath == '/favorites') {
    return {'success': true, 'data': null};
  }

  return null;
}

class _RecordingFavoritesSource implements OmmMediaOperationsSource {
  List<int>? addedMovieIds;
  List<int>? removedMovieIds;

  @override
  Future<void> addFavoriteBatch(List<source_models.MediaRef> movies) async {
    addedMovieIds = movies.map((movie) => int.parse(movie.value)).toList();
  }

  @override
  Future<void> removeFavoriteBatch(List<source_models.MediaRef> movies) async {
    removedMovieIds = movies.map((movie) => int.parse(movie.value)).toList();
  }

  @override
  Future<PreviewStartResult> generatePreview(
    source_models.MediaRef movie, {
    bool overwrite = false,
  }) => throw UnimplementedError();

  @override
  Future<PreviewStatus> previewStatus(
    source_models.MediaRef movie, {
    String? taskId,
  }) => throw UnimplementedError();

  @override
  Future<PreviewTask> previewTask(String taskId) => throw UnimplementedError();

  @override
  Future<void> cancelPreviewTask(String taskId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

MediaRepository _testMediaRepository() {
  final source = _DefaultTestMediaSource();
  return MediaRepository(catalog: source, details: source, operations: source);
}

class _DefaultTestMediaSource
    implements CatalogSource, MovieDetailSource, OmmMediaOperationsSource {
  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> listMovies(
    source_models.MediaQuery query,
  ) async {
    final items = [
      for (var i = 1; i <= 9; i++)
        source_models.MediaSummary(
          ref: source_models.MediaRef(
            sourceId: const SourceId('omm'),
            value: '$i',
          ),
          title: '影片 $i',
          payload: MovieListItem(id: i, title: '影片 $i'),
        ),
    ];
    return source_models.MediaPage(
      items: items,
      page: query.page,
      limit: query.limit,
      total: items.length,
      hasMore: false,
    );
  }

  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> searchMovies(
    source_models.MediaQuery query,
  ) => listMovies(query);

  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> listFavorites(
    source_models.MediaQuery query,
  ) async {
    final items = [
      for (var i = 1; i <= 6; i++)
        source_models.MediaSummary(
          ref: source_models.MediaRef(
            sourceId: const SourceId('omm'),
            value: '$i',
          ),
          title: '影片 $i',
          payload: MovieListItem(id: i, title: '影片 $i'),
        ),
    ];
    return source_models.MediaPage(
      items: items,
      page: query.page,
      limit: query.limit,
      total: items.length,
      hasMore: false,
    );
  }

  @override
  Future<void> removeFavoriteBatch(List<source_models.MediaRef> movies) async {}

  @override
  Future<PreviewStartResult> generatePreview(
    source_models.MediaRef movie, {
    bool overwrite = false,
  }) => throw UnimplementedError();

  @override
  Future<PreviewStatus> previewStatus(
    source_models.MediaRef movie, {
    String? taskId,
  }) => throw UnimplementedError();

  @override
  Future<PreviewTask> previewTask(String taskId) => throw UnimplementedError();

  @override
  Future<void> cancelPreviewTask(String taskId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
