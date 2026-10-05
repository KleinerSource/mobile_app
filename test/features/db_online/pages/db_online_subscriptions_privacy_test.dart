import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/db_online/pages/db_online_subscriptions_page.dart';
import 'package:omm/features/db_online/widgets/db_online_ranking_preview_card.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_section_tab.dart';
import 'package:omm/shared/media_view_mode.dart';
import 'package:omm/shared/page_header.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NavigationObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  Widget page = const DbOnlineSubscriptionsPage(),
  required _NavigationObserver observer,
  bool withVideoId = true,
  bool emptyContent = false,
  ThemeData? theme,
  double textScale = 1,
  void Function(RequestOptions)? onRequest,
}) async {
  SharedPreferences.setMockInitialValues({'privacy.app_switcher_shield': true});
  final prefs = await SharedPreferences.getInstance();
  const config = ServerConfig(baseUrl: 'https://example.test');
  final dio = Dio(BaseOptions(baseUrl: '${config.baseUrl}/api'));
  addTearDown(dio.close);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        onRequest?.call(request);
        if (emptyContent && request.path != '/health') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              data: {
                'success': true,
                'data': {'items': [], 'movies': [], 'has_more': false},
              },
            ),
          );
          return;
        }
        final movies = [
          for (var index = 1; index <= 2; index++)
            {
              'id': 'movie-$index',
              if (withVideoId) 'video_id': 'movie-$index',
              'video_code': 'ABC-00$index',
              'number': 'ABC-00$index',
              'video_title': '私人影片$index',
              'release_date': '2026-01-01',
              'status': request.queryParameters['status'] ?? 'pending',
            },
        ];
        final data = switch (request.path) {
          '/health' => {
            'capabilities': {
              'database': true,
              'online_account': true,
              'online_query': true,
            },
          },
          '/subscription-videos' => {'items': movies, 'has_more': false},
          '/subs/live-sub' => {'movies': movies, 'has_more': false},
          '/actor-subs' => {
            'items': [
              {'id': 1, 'actor_id': 'movie-1', 'actor_name': '私人演员'},
            ],
            'has_more': false,
          },
          '/series-subs' => {
            'items': [
              {'id': 1, 'external_id': 'movie-1', 'series_name': '私人系列'},
            ],
            'has_more': false,
          },
          '/blacklist' => {
            'items': [
              {'video_code': 'PRIVATE-*', 'reason': '私人备注'},
            ],
            'has_more': false,
          },
          _ => <String, dynamic>{},
        };
        handler.resolve(
          Response<dynamic>(
            requestOptions: request,
            data: {'success': true, 'data': data},
          ),
        );
      },
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        mediaRuntimeConfigProvider.overrideWithValue(config),
        requiredApiClientProvider.overrideWithValue(ApiClient(dio)),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        navigatorObservers: [observer],
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _selectSection(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(MediaSectionTab, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

// 海报备用标题在 ImageFiltered 内继续渲染；这里只检查外部文字。
Finder _privateText(String text) => find.descendant(
  of: find.byType(PrivacyText),
  matching: find.textContaining(text),
);

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('订阅分区沿用收藏 tabs 尺寸且保留 DBO 主题 ${brightness.name}/$scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpPage(
          tester,
          observer: _NavigationObserver(),
          emptyContent: true,
          theme: buildAppTheme(brightness, project: ServerProject.dbOnline),
          textScale: scale,
        );
        final pending = find.widgetWithText(MediaSectionTab, '订阅中');
        final completed = find.widgetWithText(MediaSectionTab, '已完成');
        expect(tester.getRect(pending).left, 22);
        expect(
          tester.getRect(completed).left - tester.getRect(pending).right,
          6,
        );
        for (final label in ['订阅中', '已完成', '在线订阅', '演员订阅', '综合订阅', '黑名单']) {
          await _selectSection(tester, label);
          final tab = find.widgetWithText(MediaSectionTab, label);
          final tabRect = tester.getRect(tab);
          expect(tabRect.height, 32);
          expect(tester.widget<MediaSectionTab>(tab).selected, isTrue);
          if (label == '在线订阅') {
            expect(find.byType(TextField), findsNothing);
          } else {
            final searchBox = find.ancestor(
              of: find.byType(TextField),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            );
            expect(tester.getRect(searchBox).top - tabRect.bottom, 12);
          }
          final box = tester.widget<Container>(
            find.descendant(
              of: tab,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            ),
          );
          final decoration = box.decoration! as BoxDecoration;
          const accent = Color(0xFF12B8C2);
          expect(decoration.color, accent.withValues(alpha: 0.15));
          expect(
            (decoration.border! as Border).top.color,
            accent.withValues(alpha: 0.5),
          );
          expect(decoration.borderRadius, BorderRadius.circular(10));
          expect(box.padding, const EdgeInsets.symmetric(horizontal: 12));
          final text = find.descendant(of: tab, matching: find.text(label));
          expect(tester.widget<Text>(text).style!.color, accent);
          expect(tester.getCenter(text).dy, closeTo(tabRect.center.dy, 0.01));
          expect(
            tester
                .getCenter(
                  find.descendant(of: tab, matching: find.byType(Icon)),
                )
                .dy,
            closeTo(tabRect.center.dy, 0.01),
          );
          if (label == '已完成') {
            final colors = appColors(tester.element(pending));
            final oldText = find.descendant(
              of: pending,
              matching: find.text('订阅中'),
            );
            expect(tester.widget<MediaSectionTab>(pending).selected, isFalse);
            expect(tester.widget<Text>(oldText).style!.color, colors.muted);
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final kind in ['actor', 'series']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(320, 844), const Size(844, 390)]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '订阅影片 tags 样式、留白与筛选 $kind/${brightness.name}/$size/$scale',
            (tester) async {
              await tester.binding.setSurfaceSize(size);
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final requests = <RequestOptions>[];
              await _pumpPage(
                tester,
                observer: _NavigationObserver(),
                emptyContent: true,
                theme: buildAppTheme(
                  brightness,
                  project: ServerProject.dbOnline,
                ),
                textScale: scale,
                onRequest: requests.add,
                page: DbOnlineSubscriptionVideosSheet(
                  kind: kind,
                  sourceId: 7,
                  title: '订阅影片',
                  pendingCount: 12345,
                  completedCount: 0,
                  skippedCount: null,
                ),
              );
              final pending = find.widgetWithText(
                MediaSectionTab,
                '订阅中(12345)',
              );
              expect(pending, findsOneWidget);
              expect(tester.getRect(pending).height, 32);
              final search = find.byType(TextField);
              expect(
                tester.getRect(search).top - tester.getRect(pending).bottom,
                12,
              );
              await tester.enterText(search, '  ABC  ');
              await tester.testTextInput.receiveAction(TextInputAction.search);
              await tester.pumpAndSettle();
              for (final (label, status) in [
                ('已完成(0)', 'completed'),
                ('已跳过', 'skipped'),
                ('订阅中(12345)', 'pending'),
              ]) {
                final tab = find.widgetWithText(MediaSectionTab, label);
                await tester.scrollUntilVisible(
                  tab,
                  status == 'pending' ? -120 : 120,
                  scrollable: find.descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  ),
                );
                await tester.pumpAndSettle();
                await tester.tap(tab);
                await tester.pumpAndSettle();
                expect(tester.widget<MediaSectionTab>(tab).selected, isTrue);
                final box = tester.widget<Container>(
                  find.descendant(
                    of: tab,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Container &&
                          widget.decoration is BoxDecoration,
                    ),
                  ),
                );
                const accent = Color(0xFF12B8C2);
                final decoration = box.decoration! as BoxDecoration;
                expect(decoration.color, accent.withValues(alpha: 0.15));
                expect(
                  (decoration.border! as Border).top.color,
                  accent.withValues(alpha: 0.5),
                );
                expect(tester.getRect(tab).height, 32);
                expect(
                  tester.getCenter(find.text(label)).dy,
                  closeTo(tester.getRect(tab).center.dy, 0.01),
                );
                final query = requests.last.queryParameters;
                expect(requests.last.path, '/subscription-videos');
                expect(query['source_type'], kind);
                expect(query['source_id'], 7);
                expect(query['status'], status);
                expect(query['keyword'], 'ABC');
                expect(query['page'], 1);
                expect(tester.takeException(), isNull);
              }
              await tester.tap(find.byTooltip('取消'));
              await tester.pumpAndSettle();
              expect(
                requests.last.queryParameters.containsKey('keyword'),
                isFalse,
              );
              expect(requests.last.queryParameters['status'], 'pending');
            },
          );
        }
      }
    }
  }

  for (final section in ['订阅中', '已完成', '在线订阅']) {
    testWidgets('$section 遮罩影片，首次点击只揭示当前条目，再次点击进入详情', (tester) async {
      final observer = _NavigationObserver();
      final container = await _pumpPage(tester, observer: observer);
      if (section != '订阅中') await _selectSection(tester, section);

      final card = tester.getRect(find.byType(CatalogMovieCard).first);
      final nextCard = tester.getRect(find.byType(CatalogMovieCard).last);
      final pageWidth = tester.getSize(find.byType(Scaffold).first).width;
      expect(card.left, 22);
      // 默认测试视口为 800，应与影片库一样使用 4 列。
      expect(card.width, closeTo((pageWidth - 44 - 30) / 4, 0.001));
      expect(card.width / card.height, closeTo(0.5, 0.001));
      expect(nextCard.left - card.right, closeTo(10, 0.001));

      expect(_privateText('私人影片'), findsNothing);
      expect(find.text('2026-01-01'), findsNothing);
      expect(find.byType(ImageFiltered), findsNWidgets(2));
      expect(find.byType(GlassMenuPanel), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(CatalogMovieCard).first,
          matching: find.byType(GlassMenuAnchor<String>),
        ),
        findsNothing,
      );

      await tester.tap(find.byType(CatalogMovieCard).first);
      await tester.pumpAndSettle();
      expect(observer.pushes, 1);
      expect(container.read(revealedMoviesProvider), contains('movie-1'));
      expect(_privateText('私人影片1'), findsOneWidget);
      expect(_privateText('私人影片2'), findsNothing);
      expect(find.byType(ImageFiltered), findsOneWidget);

      await container.read(privacyShieldProvider.notifier).setEnabled(false);
      await tester.pumpAndSettle();
      expect(_privateText('私人影片2'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
      await container.read(privacyShieldProvider.notifier).setEnabled(true);
      await tester.pumpAndSettle();
      expect(_privateText('私人影片'), findsNothing);

      await tester.tap(find.byType(CatalogMovieCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CatalogMovieCard).first);
      await tester.pump();
      expect(observer.pushes, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('在线订阅缺少 video_id 时使用影片 id 揭示', (tester) async {
    final container = await _pumpPage(
      tester,
      observer: _NavigationObserver(),
      withVideoId: false,
    );
    await _selectSection(tester, '在线订阅');
    await tester.tap(find.byType(CatalogMovieCard).first);
    await tester.pumpAndSettle();
    expect(container.read(revealedMoviesProvider), contains('movie-1'));
    expect(_privateText('私人影片1'), findsOneWidget);
  });

  for (final (section, title) in [
    ('演员订阅', '私人演员'),
    ('综合订阅', '私人系列'),
    ('黑名单', 'PRIVATE-*'),
  ]) {
    testWidgets('$section 隐藏名称和备注，揭示与影片域隔离', (tester) async {
      final observer = _NavigationObserver();
      final container = await _pumpPage(tester, observer: observer);
      container.read(revealedMoviesProvider.notifier).reveal('movie-1');
      await _selectSection(tester, section);
      expect(find.text(title), findsNothing);
      expect(find.textContaining('私人备注'), findsNothing);
      if (section == '演员订阅') {
        expect(find.byType(ImageFiltered), findsOneWidget);
      }

      await tester.tapAt(tester.getCenter(find.byType(PrivacyText).first));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.byType(DbOnlineSubscriptionVideosSheet), findsNothing);
      expect(observer.pushes, 1);
      if (section == '演员订阅') {
        expect(container.read(revealedActorsProvider), contains('movie-1'));
        expect(find.byType(ImageFiltered), findsNothing);
      } else if (section == '黑名单') {
        expect(find.textContaining('私人备注'), findsOneWidget);
      }
      if (section != '黑名单') {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.byType(DbOnlineSubscriptionVideosSheet), findsOneWidget);
      }
    });
  }

  testWidgets('实体影片弹层遮罩影片和标题，切换隐私模式后重新隐藏', (tester) async {
    final observer = _NavigationObserver();
    final container = await _pumpPage(
      tester,
      observer: observer,
      page: const DbOnlineSubscriptionVideosSheet(
        kind: 'actor',
        sourceId: 1,
        privacyId: 'actor-1',
        title: '私人演员',
        pendingCount: 2,
        completedCount: 0,
        skippedCount: 0,
      ),
    );
    final card = tester.getRect(find.byType(CatalogMovieCard).first);
    final nextCard = tester.getRect(find.byType(CatalogMovieCard).last);
    expect(card.left, 22);
    expect(card.width / card.height, closeTo(0.5, 0.001));
    expect(nextCard.left - card.right, closeTo(10, 0.001));
    expect(find.text('私人演员'), findsNothing);
    expect(_privateText('私人影片'), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(SheetHeader)));
    await tester.pumpAndSettle();
    expect(find.text('私人演员'), findsOneWidget);
    await tester.tap(find.byType(CatalogMovieCard).first);
    await tester.pumpAndSettle();
    expect(observer.pushes, 1);
    expect(_privateText('私人影片1'), findsOneWidget);
    expect(_privateText('私人影片2'), findsNothing);
    await container.read(privacyShieldProvider.notifier).setEnabled(false);
    await tester.pumpAndSettle();
    expect(_privateText('私人影片2'), findsOneWidget);
    await container.read(privacyShieldProvider.notifier).setEnabled(true);
    await tester.pumpAndSettle();
    expect(find.text('私人演员'), findsNothing);
    expect(_privateText('私人影片'), findsNothing);
  });

  testWidgets('视图切换统一作用于订阅影片板块与实体影片弹层，弹层与黑名单不显示切换器', (tester) async {
    final container = await _pumpPage(tester, observer: _NavigationObserver());
    final headerToggle = find.descendant(
      of: find.byType(PageHeader),
      matching: find.byType(MediaViewModeToggle),
    );
    expect(headerToggle, findsOneWidget);
    expect(
      tester.getRect(headerToggle).bottom,
      lessThan(tester.getRect(find.byType(MediaSectionTab).first).top),
    );
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DbOnlineRankingPreviewCard), findsNWidgets(2));
    expect(find.byType(CatalogMovieCard), findsNothing);
    for (final section in ['已完成', '在线订阅']) {
      await _selectSection(tester, section);
      expect(find.byType(DbOnlineRankingPreviewCard), findsNWidgets(2));
    }

    await tester.tap(find.byIcon(Icons.crop_landscape_rounded));
    await tester.pumpAndSettle();
    await _selectSection(tester, '订阅中');
    final cards = tester.widgetList<CatalogMovieCard>(
      find.byType(CatalogMovieCard),
    );
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.landscape), isTrue);
    expect(
      container
          .read(sharedPrefsProvider)
          .getString(mediaServerViewModeStorageKey(null)),
      'landscape',
    );

    await _selectSection(tester, '黑名单');
    expect(find.byType(MediaViewModeToggle), findsNothing);
    expect(
      tester
          .widget<MediaSectionTab>(find.widgetWithText(MediaSectionTab, '黑名单'))
          .selected,
      isTrue,
    );

    await _selectSection(tester, '演员订阅');
    expect(find.byType(MediaViewModeToggle), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(PrivacyText).first));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私人演员'));
    await tester.pumpAndSettle();
    final sheet = find.byType(DbOnlineSubscriptionVideosSheet);
    // 弹层不提供切换器，沿用订阅管理页头的统一视图模式。
    expect(
      find.descendant(of: sheet, matching: find.byType(MediaViewModeToggle)),
      findsNothing,
    );
    final sheetCards = tester.widgetList<CatalogMovieCard>(
      find.descendant(of: sheet, matching: find.byType(CatalogMovieCard)),
    );
    expect(sheetCards, isNotEmpty);
    expect(sheetCards.every((card) => card.landscape), isTrue);
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私人演员'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: sheet,
        matching: find.byType(DbOnlineRankingPreviewCard),
      ),
      findsNWidgets(2),
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    await _selectSection(tester, '订阅中');
    expect(find.byType(DbOnlineRankingPreviewCard), findsNWidgets(2));
  });
}
