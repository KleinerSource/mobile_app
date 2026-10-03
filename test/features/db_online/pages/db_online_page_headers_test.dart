import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/db_online/pages/db_online_followed_users_page.dart';
import 'package:omm/features/db_online/pages/db_online_following_page.dart';
import 'package:omm/features/db_online/pages/db_online_latest_movies_page.dart';
import 'package:omm/features/db_online/pages/db_online_review_resources_page.dart';
import 'package:omm/features/db_online/widgets/db_online_following_widgets.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/header_action_button.dart';

import '../support/following_test_support.dart';

void _checkHeader(
  WidgetTester tester,
  String title, {
  String eyebrow = 'DB ONLINE',
}) {
  final header = find.byType(SettingsSubPageHeader);
  final label = find.descendant(of: header, matching: find.text(eyebrow));
  final heading = find.descendant(of: header, matching: find.text(title));
  final back = find.byTooltip('返回');
  expect(header, findsOneWidget);
  expect(label, findsOneWidget);
  expect(heading, findsOneWidget);
  expect(tester.widget<SettingsSubPageHeader>(header).subtitle, isNull);
  final headingRect = tester.getRect(heading);
  final backRect = tester.getRect(back);
  expect(backRect.right, lessThanOrEqualTo(headingRect.left));
  expect(backRect.center.dy, closeTo(headingRect.center.dy, 1));
  expect(tester.getRect(label).left, headingRect.left);
  expect(tester.getRect(label).bottom, lessThan(headingRect.top));
  expect(
    tester.widget<Text>(label).style!.fontSize,
    lessThan(tester.widget<Text>(heading).style!.fontSize!),
  );
  final actions = find.descendant(
    of: header,
    matching: find.byType(HeaderActionButton),
  );
  for (final element in actions.evaluate()) {
    final button = find.byWidget(element.widget);
    final circle = find.descendant(
      of: button,
      matching: find.byType(HeaderActionIcon),
    );
    expect(tester.getSize(button), const Size.square(48));
    expect(tester.getSize(circle), const Size.square(36));
    expect(tester.getCenter(circle), tester.getCenter(button));
    expect(tester.getCenter(button).dy, closeTo(headingRect.center.dy, 1));
  }
}

void main() {
  testWidgets('关注页筛选在在线查询不可用时仍复用圆形样式且禁止操作', (tester) async {
    final backend = FollowingTestBackend()..onlineQuery = false;
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    _checkHeader(tester, '关注列表', eyebrow: '我的');
    final action = find.widgetWithIcon(HeaderActionButton, Icons.tune_rounded);
    final filter = find.descendant(
      of: action,
      matching: find.byType(IconButton),
    );
    expect(filter, findsOneWidget);
    expect(tester.widget<IconButton>(filter).onPressed, isNull);
    await tester.tap(action);
    await pumpFollowingFrames(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(backend.to('/subs/tags'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  final pages = <(Widget, String, String, Object)>[
    (
      const DbOnlineLatestMoviesPage(sortBy: 'release'),
      '最新上架',
      '/latest',
      {'items': [], 'has_more': false},
    ),
    (
      const DbOnlineLatestMoviesPage(sortBy: 'update'),
      '最近更新',
      '/latest',
      {'items': [], 'has_more': false},
    ),
    (
      const DbOnlineFollowingPage(),
      '关注列表',
      '/subs/tags',
      {'movies': [], 'has_more': false},
    ),
    (
      const DbOnlineFollowedUsersPage(serverId: 'a'),
      '关注用户',
      '/following/users',
      [],
    ),
    (
      const DbOnlineReviewResourcesPage(
        serverId: 'a',
        userId: 'latest_reviews',
        latest: true,
      ),
      '最新评论',
      '/reviews/latest/resources',
      {'items': [], 'page': 1, 'has_next': false},
    ),
    (
      const DbOnlineReviewResourcesPage(
        serverId: 'a',
        userId: 'one',
        username: '指定用户',
      ),
      '指定用户',
      '/users/one/resources',
      {'items': [], 'page': 1, 'has_next': false},
    ),
  ];

  for (final (page, title, path, data) in pages) {
    final eyebrow = page is DbOnlineFollowingPage ? '我的' : 'DB ONLINE';
    testWidgets('$title 加载、失败、重试和成功保留双抬头，返回仅退出当前页', (tester) async {
      final pending = Completer<Object?>();
      var retried = false;
      final backend = FollowingTestBackend()
        ..respond = (request) => request.path == path
            ? retried
                  ? {'success': true, 'data': data}
                  : pending.future
            : null;
      await pumpFollowingTest(
        tester,
        backend,
        Navigator(
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('上一页')),
            ),
            MaterialPageRoute<void>(builder: (_) => page),
          ],
          onGenerateRoute: (_) => null,
        ),
        retry: (_, _) => null,
      );
      expect(backend.to(path), hasLength(1));
      _checkHeader(tester, title, eyebrow: eyebrow);
      final before = tester.getRect(find.byType(SettingsSubPageHeader));

      pending.complete({'success': false, 'error': '测试请求失败'});
      await pumpFollowingFrames(tester);
      _checkHeader(tester, title, eyebrow: eyebrow);
      expect(find.text('重试'), findsOneWidget);
      expect(tester.getRect(find.byType(SettingsSubPageHeader)), before);

      retried = true;
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试').hitTestable());
      await tester.pump();
      _checkHeader(tester, title, eyebrow: eyebrow);
      await pumpFollowingFrames(tester);
      expect(backend.to(path), hasLength(2));
      _checkHeader(tester, title, eyebrow: eyebrow);
      expect(tester.getRect(find.byType(SettingsSubPageHeader)), before);

      await tester.tap(find.byTooltip('返回'));
      await pumpFollowingFrames(tester);
      expect(find.text('上一页'), findsOneWidget);
      expect(find.byType(SettingsSubPageHeader), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 720), const Size(844, 390)]) {
    testWidgets('关注抬头在 $size、长标题及双倍字体下可滚动且操作可用', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const title = '指定用户的很长很长的评论资源页面标题';
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: DbOnlineFollowingLayout(
            title: title,
            actions: [
              for (var i = 0; i < 3; i++)
                HeaderActionButton(
                  icon: Icons.refresh,
                  tooltip: '操作 $i',
                  onPressed: () => tapped++,
                ),
            ],
            body: ListView(
              children: const [SizedBox(height: 1000), Text('列表底部')],
            ),
          ),
        ),
      );
      _checkHeader(tester, title);
      final before = tester.getRect(find.byType(SettingsSubPageHeader));
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(SettingsSubPageHeader)), before);
      await tester.tap(find.byTooltip('操作 2'));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
