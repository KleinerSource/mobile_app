import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/features/db_online/pages/db_online_subscriptions_page.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/movie_card.dart';
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
}) async {
  SharedPreferences.setMockInitialValues({'privacy.app_switcher_shield': true});
  final prefs = await SharedPreferences.getInstance();
  const config = ServerConfig(baseUrl: 'https://example.test');
  final dio = Dio(BaseOptions(baseUrl: '${config.baseUrl}/api'));
  addTearDown(dio.close);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
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
  final chip = find.widgetWithText(ChoiceChip, label);
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
      expect(find.byType(GlassMenuAnchor<String>), findsNothing);

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
}
