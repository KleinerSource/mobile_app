import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/core/sources/media/media_models.dart' as media_models;
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/db_online/pages/db_online_latest_movies_page.dart';
import 'package:omm/features/db_online/pages/db_online_library_page.dart';
import 'package:omm/features/db_online/pages/db_online_search_page.dart';
import 'package:omm/features/db_online/pages/db_online_subscriptions_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/files/file_manager_shell.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/features/media_browser/pages/media_browser_library_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_favorites_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_search_page.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';
import 'package:omm/features/oh_my_media/lists/list_detail_page.dart';
import 'package:omm/features/oh_my_media/favorites/favorites_page.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_page.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/oh_my_media/search/search_page.dart';
import 'package:omm/features/settings/server_lines_page.dart';
import 'package:omm/features/settings/settings_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/entity_batch_toolbar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_section_tab.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/shared/media_view_mode.dart';

class _ServerConfigState extends ServerConfigNotifier {
  _ServerConfigState(this.value);
  final ServerConfig? value;
  @override
  ServerConfig? build() => value;
}

class _UnusedSource implements MediaBrowserMediaSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyBrowserRepository extends MediaBrowserMediaRepository {
  _EmptyBrowserRepository() : super(_UnusedSource());
  @override
  Future<MediaBrowserItemPage> itemPage(media_models.MediaQuery query) async =>
      const MediaBrowserItemPage(items: [], total: 0, startIndex: 0, limit: 24);
}

ServerConfig _config(String project) => ServerConfig(
  baseUrl: 'https://headers.test',
  activeServerId: 'server',
  servers: [
    ServerProfile(
      id: 'server',
      name: '服务器',
      projectName: project,
      lines: const [],
    ),
  ],
);

ApiClient _client({bool emptyMovies = false}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://headers.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final isMovieList = options.path.endsWith('/movies');
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: {
              'success': true,
              'data': isMovieList
                  ? {
                      'items': [
                        for (var id = 1; !emptyMovies && id <= 9; id++)
                          {'id': id, 'title': '影片 $id'},
                      ],
                      'total_count': emptyMovies ? 0 : 9,
                      'offset': 0,
                      'limit': 50,
                    }
                  : [],
            },
          ),
        );
      },
    ),
  );
  return ApiClient(dio);
}

Future<void> _open(
  WidgetTester tester,
  Widget page, {
  String project = 'oh-my-media',
  bool configured = true,
  double scale = 1,
  bool settle = true,
  double topInset = 0,
  bool emptyMovies = false,
  List<MediaBrowserItem> browserViews = const [],
  Future<DbOnlineSubscriptionCapabilities> Function()? capabilitiesLoader,
}) async {
  SharedPreferences.setMockInitialValues({
    'privacy.app_switcher_shield': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final api = _client(emptyMovies: emptyMovies);
  final config = _config(project);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        requiredApiClientProvider.overrideWithValue(api),
        ommMediaSourceProvider.overrideWithValue(OmmMediaSourceAdapter(api)),
        imageUrlBuilderProvider.overrideWithValue((_) => ''),
        serverConfigProvider.overrideWith(
          () => _ServerConfigState(configured ? config : null),
        ),
        mediaRuntimeConfigProvider.overrideWithValue(config),
        if (capabilitiesLoader != null)
          dbOnlineSubscriptionCapabilitiesProvider.overrideWith(
            (ref, serverId) => capabilitiesLoader(),
          ),
        mediaBrowserMediaRepositoryProvider.overrideWithValue(
          _EmptyBrowserRepository(),
        ),
        mediaBrowserViewsProvider.overrideWith((ref) async => browserViews),
        mediaBrowserLatestProvider.overrideWith((ref) async => []),
        mediaBrowserResumeProvider.overrideWith((ref) async => []),
        mediaBrowserNextUpProvider.overrideWith((ref) async => []),
        mediaBrowserLibraryStatsProvider.overrideWith(
          (ref) async => const MediaBrowserLibraryStats(
            movieCount: 0,
            seriesCount: 0,
            episodeCount: 0,
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: EdgeInsets.only(top: topInset),
            viewPadding: EdgeInsets.only(top: topInset),
          ),
          child: child!,
        ),
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => Scaffold(body: page)),
              ),
              child: const Text('上一页'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('上一页'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }
  expect(
    Navigator.of(tester.element(find.byType(page.runtimeType).first)).canPop(),
    isTrue,
  );
}

Future<void> _return(WidgetTester tester) async {
  await tester.tap(find.byTooltip('返回').hitTestable());
  await tester.pumpAndSettle();
  expect(find.text('上一页'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void _expectDoubleHeader(
  WidgetTester tester,
  Finder page,
  String eyebrow,
  String title,
) {
  final small = find.descendant(of: page, matching: find.text(eyebrow));
  final large = find.descendant(of: page, matching: find.text(title));
  expect(small, findsOneWidget);
  expect(large, findsOneWidget);
  expect(
    tester.widget<Text>(small).style!.fontSize,
    lessThan(tester.widget<Text>(large).style!.fontSize!),
  );
  expect(tester.getTopLeft(small).dx, tester.getTopLeft(large).dx);
  expect(
    tester.getBottomRight(small).dy,
    lessThan(tester.getTopLeft(large).dy),
  );
  expect(find.byType(BackButton).hitTestable(), findsNothing);
  expect(find.byTooltip('返回').hitTestable(), findsNothing);
  expect(tester.takeException(), isNull);
}

void _expectHeaderIconCenters(WidgetTester tester, Finder header) {
  final buttons = find.descendant(
    of: header,
    matching: find.byWidgetPredicate(
      (widget) => widget is HeaderActionButton || widget is HeaderMenuButton,
    ),
  );
  expect(buttons, findsWidgets);
  for (final element in buttons.evaluate()) {
    final button = find.byWidget(element.widget);
    final ink = find.descendant(of: button, matching: find.byType(InkWell));
    final circle = find.descendant(
      of: button,
      matching: find.byType(HeaderActionIcon),
    );
    final icon = find.descendant(of: circle, matching: find.byType(Icon));
    final circleRect = tester.getRect(circle);
    expect(circleRect.size, const Size.square(36));
    expect(tester.getSize(ink), const Size.square(48));
    expect(tester.getCenter(icon).dx, closeTo(circleRect.center.dx, 0.01));
    expect(tester.getCenter(icon).dy, closeTo(circleRect.center.dy, 0.01));
    expect(tester.getCenter(ink), circleRect.center);
  }
}

void main() {
  for (final size in [const Size(320, 720), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('工具栏与搜索框按需显示，在 $size/$scale 下间距统一并固定', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // 第 4 位是工具栏底部到列表顶部的期望间距：所有媒体源统一用
        // aboveListGap，加上列表自带的 contentTopInset 后与块间间距
        // （toolbarTopGap）同为 12 的节奏。
        for (final entry in <(Widget, String, bool, double)>[
          (
            const MoviesPage(showBackButton: false, maxItems: 0),
            'oh-my-media',
            true,
            PageHeader.aboveListGap,
          ),
          (
            const SearchPage(),
            'oh-my-media',
            true,
            PageHeader.aboveListGap,
          ),
          (
            const DbOnlineSearchPage(),
            'db_online',
            true,
            PageHeader.aboveListGap,
          ),
          (
            const MediaBrowserSearchPage(),
            'emby',
            true,
            PageHeader.aboveListGap,
          ),
          (const DbOnlineLibraryPage(), 'db_online', false, 0),
          (
            const MediaBrowserLibraryPage(showBackButton: false),
            'emby',
            true,
            PageHeader.aboveListGap,
          ),
          (
            const MediaBrowserLibraryPage(showBackButton: false),
            'feiniu',
            false,
            0,
          ),
        ]) {
          await _open(
            tester,
            entry.$1,
            project: entry.$2,
            scale: scale,
            emptyMovies: true,
            browserViews: [
              MediaBrowserItem.fromJson(const {
                'Id': 'library',
                'Name': '测试媒体库',
                'Type': 'CollectionFolder',
              }),
            ],
          );
          final header = find.byType(PageHeader);
          final headerRect = tester.getRect(header);
          final column = tester.widget<Column>(
            find.ancestor(of: header, matching: find.byType(Column)).first,
          );
          final body = find.byWidget(column.children.last);
          if (entry.$3) {
            final toolbar = column.children[1] as Padding;
            final toolbarContent = find.byWidget(toolbar.child!);
            final toolbarRect = tester.getRect(toolbarContent);
            // PageHeader 的光学补偿引入浮点运算，几何断言带容差比较。
            expect(toolbarRect.top, closeTo(headerRect.bottom, 0.01));
            expect(
              tester.getRect(body).top - toolbarRect.bottom,
              closeTo(entry.$4, 0.01),
            );
            await tester.drag(body, const Offset(0, -250));
            await tester.pumpAndSettle();
            expect(tester.getRect(toolbarContent), toolbarRect);
          } else {
            expect(
              tester.getRect(body).top,
              closeTo(headerRect.bottom, 0.01),
            );
          }
          expect(tester.getRect(header), headerRect);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });

      testWidgets('六种媒体源底部双行抬头在 $size/$scale 下高度与位置统一', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Rect? referenceHeader;
        double? referenceContentHeight;
        Rect? referenceSmall;
        Rect? referenceLarge;
        Size? referenceToggle;
        Size? referenceFilter;
        for (final project in [
          'oh-my-media',
          'db_online',
          'emby',
          'jellyfin',
          'feiniu',
          'stash',
        ]) {
          final pages = switch (project) {
            'oh-my-media' => const [
              MoviesPage(showBackButton: false),
              SearchPage(),
              FavoritesPage(),
            ],
            'db_online' => const [
              DbOnlineLibraryPage(),
              DbOnlineSearchPage(),
              DbOnlineSubscriptionsPage(),
            ],
            'stash' => const [
              MediaBrowserLibraryPage(showBackButton: false),
              MediaBrowserSearchPage(),
              SettingsPage(showBackButton: false),
            ],
            _ => const [
              MediaBrowserLibraryPage(showBackButton: false),
              MediaBrowserSearchPage(),
              MediaBrowserFavoritesPage(),
            ],
          };
          for (var index = 0; index < pages.length; index++) {
            await tester.binding.setSurfaceSize(const Size(390, 844));
            await _open(tester, pages[index], project: project, topInset: 24);
            final pageHeader = tester.widget<PageHeader>(
              find.byType(PageHeader),
            );
            await tester.binding.setSurfaceSize(size);
            // 使用真实页面的抬头配置独立渲染，避免正文卡片影响抬头几何验证。
            await tester.pumpWidget(
              MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: AppL10n.localizationsDelegates,
                supportedLocales: AppL10n.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 24),
                    viewPadding: const EdgeInsets.only(top: 24),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: [
                        pageHeader,
                        Expanded(
                          child: ListView.builder(
                            itemCount: 50,
                            itemBuilder: (_, index) =>
                                SizedBox(height: 44, child: Text('条目 $index')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            // 存在性不做命中测试：底距收窄后头部中心点可能落在文字空隙上。
            final header = find.byType(PageHeader);
            expect(header, findsOneWidget, reason: '$project/$index');
            final small = find.descendant(
              of: header,
              matching: find.byWidgetPredicate(
                (widget) => widget is Text && widget.style?.fontSize == 11,
              ),
            );
            final large = find.descendant(
              of: header,
              matching: find.byWidgetPredicate(
                (widget) => widget is Text && widget.style?.fontSize == 28,
              ),
            );
            final headerRect = tester.getRect(header);
            final smallRect = tester.getRect(small);
            final largeRect = tester.getRect(large);
            final filterIcon = find.descendant(
              of: header,
              matching: find.byIcon(Icons.tune_rounded),
            );
            if (filterIcon.evaluate().isNotEmpty) {
              final filter = find
                  .ancestor(of: filterIcon, matching: find.byType(Container))
                  .first;
              final filterRect = tester.getRect(filter);
              referenceFilter ??= filterRect.size;
              expect(
                filterRect.size,
                referenceFilter,
                reason: '$project/$index',
              );
              expect(tester.getCenter(filterIcon), filterRect.center);
              expect(filterRect.center.dy, closeTo(largeRect.center.dy, 0.01));
            }
            final toggle = find.descendant(
              of: header,
              matching: find.byType(MediaViewModeToggle),
            );
            if (toggle.evaluate().isNotEmpty) {
              final toggleSize = tester.getSize(toggle);
              referenceToggle ??= toggleSize;
              expect(toggleSize, referenceToggle, reason: '$project/$index');
              expect(
                tester.getCenter(toggle).dy,
                closeTo(largeRect.center.dy, 0.01),
              );
            }
            if (index == 2 &&
                (project == 'oh-my-media' ||
                    project == 'db_online' ||
                    project == 'emby' ||
                    project == 'jellyfin' ||
                    project == 'feiniu')) {
              _expectHeaderIconCenters(tester, header);
            }
            // 双行抬头的内容高度跨源统一；底部留白随页面配置变化
            // （下方是工具栏用 toolbarTopGap，列表直接跟随用 aboveListGap），
            // 且光学补偿可能将其钳制为 0，因此从标题行实测实际留白再扣除。
            final titleRow = find
                .descendant(of: header, matching: find.byType(ConstrainedBox))
                .first;
            final actualBottomPadding =
                headerRect.bottom - tester.getRect(titleRow).bottom;
            final contentHeight = headerRect.height - actualBottomPadding;
            referenceHeader ??= headerRect;
            referenceContentHeight ??= contentHeight;
            referenceSmall ??= smallRect;
            referenceLarge ??= largeRect;
            expect(
              headerRect.top,
              referenceHeader.top,
              reason: '$project/$index',
            );
            expect(
              contentHeight,
              closeTo(referenceContentHeight, 0.01),
              reason: '$project/$index',
            );
            expect(
              smallRect.top,
              closeTo(referenceSmall.top, 0.01),
              reason: '$project/$index',
            );
            expect(
              largeRect.top,
              closeTo(referenceLarge.top, 0.01),
              reason: '$project/$index',
            );
            expect(smallRect.left, 22);
            expect(largeRect.left, 22);
            expect(smallRect.top, 40);
            expect(find.byTooltip('返回').hitTestable(), findsNothing);
            await tester.drag(find.byType(ListView), const Offset(0, -250));
            await tester.pumpAndSettle();
            expect(tester.getRect(header), headerRect);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      });
    }
  }

  testWidgets('DBO 订阅管理保留分区工具栏与搜索框，切换在线分区后不留搜索框占位', (tester) async {
    await _open(
      tester,
      const DbOnlineSubscriptionsPage(),
      project: 'db_online',
      emptyMovies: true,
      capabilitiesLoader: () async => const DbOnlineSubscriptionCapabilities(
        database: true,
        onlineAccount: true,
        onlineQuery: true,
      ),
    );
    final header = find.byType(PageHeader);
    final titleRect = tester.getRect(header);
    _expectHeaderIconCenters(tester, header);
    expect(
      find.descendant(of: header, matching: find.byType(HeaderActionButton)),
      findsOneWidget,
    );
    final menu = find.descendant(
      of: header,
      matching: find.byType(HeaderMenuButton<String>),
    );
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byType(GlassMenuRow), findsWidgets);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(DbOnlineSubscriptionsPage), findsOneWidget);
    final search = find.byType(TextField);
    expect(search, findsOneWidget);
    final searchRect = tester.getRect(search);
    final beforeBody = tester.getRect(find.byType(RefreshIndicator));
    final online = find.widgetWithText(MediaSectionTab, '在线订阅');
    await tester.ensureVisible(online);
    await tester.tap(online);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(tester.getRect(header), titleRect);
    expect(
      tester.getRect(find.byType(RefreshIndicator)).top,
      lessThan(beforeBody.top - searchRect.height),
    );
    expect(tester.takeException(), isNull);
  });

  for (final project in [
    'oh-my-media',
    'db_online',
    'emby',
    'jellyfin',
    'feiniu',
    'stash',
  ]) {
    testWidgets('$project 的所有底部页面在可返回导航栈中都不显示返回', (tester) async {
      await _open(tester, const MediaManagerShell(), project: project);
      // db_online 底部有榜单 Tab，比其它项目多一个。
      final tabCount = project == 'db_online' ? 5 : 4;
      for (var index = 0; index < tabCount; index++) {
        tester
            .widget<FloatingTabBar<Object?>>(
              find.byType(FloatingTabBar<Object?>),
            )
            .onTap(index);
        await tester.pumpAndSettle();
        expect(find.byTooltip('返回').hitTestable(), findsNothing);
        expect(find.byType(BackButton).hitTestable(), findsNothing);
        expect(find.byIcon(Icons.arrow_back).hitTestable(), findsNothing);
        final searchTabIndex = project == 'db_online' ? 3 : 2;
        if (index == searchTabIndex) {
          final searchPage = switch (project) {
            'oh-my-media' => find.byType(SearchPage),
            'db_online' => find.byType(DbOnlineSearchPage),
            _ => find.byType(MediaBrowserSearchPage),
          };
          _expectDoubleHeader(tester, searchPage, '搜索', '查找内容');
        }
        if (index == tabCount - 1 && project == 'db_online') {
          _expectDoubleHeader(
            tester,
            find.byType(DbOnlineSubscriptionsPage),
            '我的',
            '订阅管理',
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('DBO 我的双抬头在加载、失败、重试和成功时保留，支持窄屏双倍字体', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = Completer<DbOnlineSubscriptionCapabilities>();
    final retry = Completer<DbOnlineSubscriptionCapabilities>();
    var attempts = 0;
    await _open(
      tester,
      const DbOnlineSubscriptionsPage(),
      project: 'db_online',
      scale: 2,
      settle: false,
      capabilitiesLoader: () => ++attempts == 1 ? first.future : retry.future,
    );
    final page = find.byType(DbOnlineSubscriptionsPage);
    _expectDoubleHeader(tester, page, '我的', '订阅管理');
    first.completeError(StateError('模拟加载失败'));
    await tester.pumpAndSettle();
    _expectDoubleHeader(tester, page, '我的', '订阅管理');
    await tester.tap(find.text('重试'));
    await tester.pump();
    _expectDoubleHeader(tester, page, '我的', '订阅管理');
    retry.complete(
      const DbOnlineSubscriptionCapabilities(
        database: false,
        onlineAccount: false,
        onlineQuery: false,
      ),
    );
    await tester.pumpAndSettle();
    _expectDoubleHeader(tester, page, '我的', '订阅管理');
    expect(attempts, 2);
  });

  testWidgets('文件管理器底部设置隐藏返回，独立设置显示返回', (tester) async {
    await _open(tester, const FileManagerShell());
    tester
        .widget<FloatingTabBar<String>>(find.byType(FloatingTabBar<String>))
        .onTap(2);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SettingsPage>(find.byType(SettingsPage)).showBackButton,
      isFalse,
    );
    expect(find.byTooltip('返回'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _open(tester, const SettingsPage(showBackButton: true));
    await _return(tester);
  });

  for (final entry in <Widget>[
    const MoviesPage(showBackButton: true, maxItems: 30),
    const MoviesPage(
      showBackButton: true,
      initialFilter: MovieFilter(libraryId: 7),
    ),
    const MediaBrowserLibraryPage(
      showBackButton: true,
      initialViewId: 'library',
    ),
    const MediaBrowserLibraryPage(
      showBackButton: true,
      personId: 'actor',
      personName: '演员作品',
    ),
    const MediaBrowserLibraryPage(
      showBackButton: true,
      genreId: 'genre',
      genreName: '分类作品',
    ),
    const MediaBrowserLibraryPage(
      showBackButton: true,
      tagId: 'tag',
      tagName: '标签作品',
    ),
    const DbOnlineLatestMoviesPage(sortBy: 'release'),
    const DbOnlineLatestMoviesPage(sortBy: 'update'),
  ].indexed) {
    final page = entry.$2;
    testWidgets('列表子页面 ${entry.$1} 的返回在标题左侧且只返回上一页', (tester) async {
      await _open(tester, page);
      final back = find.byTooltip('返回');
      final row = find.ancestor(of: back, matching: find.byType(Row)).first;
      final title = find.descendant(of: row, matching: find.byType(Text)).first;
      expect(
        tester.getRect(back).right,
        lessThanOrEqualTo(tester.getRect(title).left),
      );
      final before = tester.getRect(back);
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(back), before);
      await _return(tester);
    });
  }

  for (final size in [const Size(320, 720), const Size(844, 390)]) {
    for (final page in <Widget>[
      const MoviesPage(showBackButton: true, maxItems: 0),
      const MediaBrowserLibraryPage(
        showBackButton: true,
        personId: 'actor',
        personName: '用于验证窄屏和放大字体的很长的演员作品标题',
      ),
      const DbOnlineLatestMoviesPage(sortBy: 'release'),
    ]) {
      testWidgets('$page 在 $size 和双倍字体下抬头不溢出', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _open(tester, page, scale: 2);
        expect(find.byTooltip('返回').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('子页面批量选择时先退出选择，再返回上一页', (tester) async {
    await _open(tester, const MoviesPage(showBackButton: true));
    await tester.longPress(find.byType(MovieCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(EntityBatchToolbar), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(EntityBatchToolbar), findsNothing);
    expect(find.byType(MoviesPage), findsOneWidget);
    await _return(tester);
  });

  for (final entry in <(Widget, String, bool)>[
    (const ServerLinesPage(), '尚未配置服务器线路', false),
    (const ServerLinesPage(serverId: 'deleted'), '服务器不存在或已被删除', true),
    (const ListDetailPage(listId: 'deleted'), '片单不存在', true),
  ]) {
    testWidgets('${entry.$2} 时仍有标题和可用返回', (tester) async {
      await _open(tester, entry.$1, configured: entry.$3);
      final title = entry.$1 is ServerLinesPage ? '服务器线路' : '影片列表';
      expect(find.text(title), findsOneWidget);
      await _return(tester);
    });
  }
}
