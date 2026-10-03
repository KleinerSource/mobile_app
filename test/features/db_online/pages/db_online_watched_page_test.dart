import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/pages/db_online_watched_page.dart';
import 'package:omm/features/db_online/widgets/db_online_download_requirements_fields.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_watched_recheck_sheet.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/pagination_footer.dart';

import '../support/following_test_support.dart';
import '../support/watched_test_support.dart';

PagingController<int, DbOnlineMovie> movies(WidgetTester tester) => tester
    .widget<PagedSliverGrid<int, DbOnlineMovie>>(
      find.byType(PagedSliverGrid<int, DbOnlineMovie>),
    )
    .pagingController;

Future<void> sheetTap(WidgetTester tester, String text) async {
  final target = find
      .descendant(
        of: find.byType(DbOnlineWatchedRecheckSheet),
        matching: find.text(text),
      )
      .last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await pumpFollowingFrames(tester);
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('复查'));
  await pumpFollowingFrames(tester);
  expect(find.byType(DbOnlineWatchedRecheckSheet), findsOneWidget);
}

Future<void> pickFilters(WidgetTester tester, List<String> labels) async {
  await tester.tap(find.byTooltip('筛选'));
  await pumpFollowingFrames(tester);
  for (final label in labels) {
    // 「全部」同时出现在类型与评分两组，取第一组（类型）。
    await tester.tap(find.text(label).first);
    await pumpFollowingFrames(tester);
  }
  Navigator.of(tester.element(find.text('类型'))).pop();
  await pumpFollowingFrames(tester);
}

Future<void> pickSort(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('排序'));
  await pumpFollowingFrames(tester);
  await tester.tap(find.text(label));
  await pumpFollowingFrames(tester);
}

void main() {
  testWidgets('订阅点击仍导航，长按滑动进入看过影片，返回保持Tab，空白关闭', (tester) async {
    final backend = WatchedTestBackend();
    await pumpWatchedTest(tester, backend, page: const MediaManagerShell());
    final tab = find.descendant(
      of: find.byType(FloatingTabBar<Object?>),
      matching: find.byIcon(Icons.subscriptions_outlined),
    );
    await tester.tap(tab);
    await pumpFollowingFrames(tester);
    final bar = find.byType(FloatingTabBar<Object?>, skipOffstage: false);
    expect(tester.widget<FloatingTabBar<Object?>>(bar).active, 3);
    final anchor = find.ancestor(
      of: tab,
      matching: find.byType(GlassMenuAnchor<Object?>),
    );
    final gesture = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('关注列表'), findsOneWidget);
    expect(find.text('下载记录'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.text('看过影片')));
    await gesture.up();
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineWatchedPage), findsOneWidget);
    expect(tester.widget<FloatingTabBar<Object?>>(bar).tabs, hasLength(4));
    await tester.tap(find.byTooltip('返回'));
    await pumpFollowingFrames(tester);
    expect(tester.widget<FloatingTabBar<Object?>>(bar).active, 3);
    final outside = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await outside.up();
    await pumpFollowingFrames(tester);
    await tester.tapAt(const Offset(10, 30));
    await pumpFollowingFrames(tester);
    expect(find.text('看过影片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认查询，所有影片正常显示，三列共享卡片保留字幕磁链播放字段', (tester) async {
    final backend = WatchedTestBackend()
      ..movies = [
        watchedMovie(1),
        watchedMovie(2, playable: true),
        watchedMovie(3),
      ];
    final sockets = WatchedTestSockets();
    await pumpWatchedTest(tester, backend, sockets: sockets);
    expect(backend.to('/subs/watched').single.queryParameters, {
      'type': 'all',
      'star': '',
      'sort_by': 'create',
      'order_by': 'desc',
      'page': 1,
      'limit': 24,
    });
    expect(movies(tester).itemList, hasLength(3));
    final cards = tester.widgetList<DbOnlineMovieCard>(
      find.byType(DbOnlineMovieCard),
    );
    expect(cards.map((card) => card.movie.canPlay), [false, true, false]);
    expect(
      cards.every(
        (card) => card.movie.hasCnsub && card.movie.magnetsCount == 2,
      ),
      isTrue,
    );
    final first = tester.getRect(find.byType(CatalogMovieCard).at(0));
    final third = tester.getRect(find.byType(CatalogMovieCard).at(2));
    expect(first.top, third.top);
    expect(third.left, greaterThan(first.right));
    expect(find.byType(HeaderActionButton), findsOneWidget);
    expect(find.byTooltip('排序'), findsOneWidget);
    expect(find.byTooltip('筛选'), findsOneWidget);
    expect(sockets.urls.single.toString(), 'wss://a.test/ws/scheduler/status');
    expect(tester.takeException(), isNull);
  });

  testWidgets('类型/评分在筛选弹层组合，排序弹层切换字段与方向', (tester) async {
    final backend = WatchedTestBackend();
    await pumpWatchedTest(tester, backend);
    await pickFilters(tester, ['无码', '5 星']);
    expect(find.text('类型'), findsNothing);
    await pickSort(tester, '降序');
    expect(backend.to('/subs/watched').last.queryParameters, {
      'type': '1',
      'star': '5',
      'sort_by': 'create',
      'order_by': 'asc',
      'page': 1,
      'limit': 24,
    });
    await pickSort(tester, '发布日期');
    expect(backend.to('/subs/watched').last.queryParameters, {
      'type': '1',
      'star': '5',
      'sort_by': 'release',
      'order_by': 'asc',
      'page': 1,
      'limit': 24,
    });
    await pickFilters(tester, ['全部']);
    expect(backend.to('/subs/watched').last.queryParameters['type'], 'all');
    expect(backend.to('/subs/watched').last.queryParameters['star'], '5');
  });

  testWidgets('快速切换筛选丢弃迟到旧响应', (tester) async {
    final old = Completer<Object?>();
    final backend = WatchedTestBackend()
      ..respond = (request) =>
          request.path == '/subs/watched' &&
              request.queryParameters['type'] == '0'
          ? old.future
          : null;
    await pumpWatchedTest(tester, backend);
    await tester.tap(find.byTooltip('筛选'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('有码'));
    await tester.pump();
    await tester.tap(find.text('无码'));
    await pumpFollowingFrames(tester);
    old.complete(watchedPayload([watchedMovie(99)]));
    await pumpFollowingFrames(tester);
    expect(movies(tester).itemList!.single.id, 'watched-1');
    expect(
      movies(tester).itemList!.map((movie) => movie.number),
      isNot(contains('WATCH-99')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('原始整批去重后继续翻页，短批次结束，失败可重试同页', (tester) async {
    final batch = [for (var i = 0; i < 24; i++) watchedMovie(i)];
    final backend = WatchedTestBackend()
      ..pages[1] = batch
      ..pages[2] = batch
      ..pages[3] = [watchedMovie(25)];
    await pumpWatchedTest(tester, backend);
    final paging = movies(tester);
    paging.notifyPageRequestListeners(2);
    await pumpFollowingFrames(tester);
    expect(paging.itemList, hasLength(24));
    expect(paging.nextPageKey, 3);
    var fail = true;
    backend.respond = (request) =>
        request.path == '/subs/watched' &&
            request.queryParameters['page'] == 3 &&
            fail
        ? {'success': false, 'error': '分页失败'}
        : null;
    paging.notifyPageRequestListeners(3);
    await pumpFollowingFrames(tester);
    expect(paging.error, isNotNull);
    expect(paging.itemList, hasLength(24));
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await pumpFollowingFrames(tester);
    }
    fail = false;
    final retry = find.descendant(
      of: find.byType(PaginationRetry),
      matching: find.byType(TextButton),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await pumpFollowingFrames(tester);
    expect(paging.itemList, hasLength(25));
    expect(paging.nextPageKey, isNull);
  });

  testWidgets('首批失败可重试，下拉刷新沿用筛选，页头固定', (tester) async {
    var fail = true;
    final backend = WatchedTestBackend()
      ..respond = (request) => request.path == '/subs/watched' && fail
          ? {'success': false, 'error': '列表失败'}
          : null;
    await pumpWatchedTest(tester, backend);
    expect(find.text('列表失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试'));
    await pumpFollowingFrames(tester);
    await pickFilters(tester, ['5 星']);
    final header = tester.getTopLeft(find.text('看过影片'));
    final count = backend.to('/subs/watched').length;
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 450),
      1000,
    );
    await pumpFollowingFrames(tester, 24);
    expect(backend.to('/subs/watched').length, greaterThan(count));
    expect(backend.to('/subs/watched').last.queryParameters['star'], '5');
    expect(tester.getTopLeft(find.text('看过影片')), header);
    expect(tester.takeException(), isNull);
  });

  for (final database in [false, true]) {
    testWidgets('无在线账户不查询/不复查：database=$database', (tester) async {
      final backend = WatchedTestBackend()
        ..database = database
        ..onlineAccount = false;
      final sockets = WatchedTestSockets();
      await pumpWatchedTest(tester, backend, sockets: sockets);
      expect(backend.to('/subs/watched'), isEmpty);
      expect(find.byTooltip('复查'), findsNothing);
      expect(find.byTooltip('筛选'), findsNothing);
      expect(find.text('请先在当前服务器配置在线账户'), findsOneWidget);
      expect(sockets.urls, isEmpty);
    });
  }

  testWidgets('无数据库仍能浏览在线已看列表，隐藏复查', (tester) async {
    final backend = WatchedTestBackend()..database = false;
    await pumpWatchedTest(tester, backend);
    expect(movies(tester).itemList!.single.number, 'WATCH-1');
    expect(find.byTooltip('复查'), findsNothing);
  });

  testWidgets('复查读取启用预设，取消不发送请求，编号名称超期均不出现', (tester) async {
    final backend = WatchedTestBackend()
      ..preset = {
        'enabled': true,
        'quality': 'hd',
        'require_sub': true,
        'min_size_mb': 100,
        'max_size_mb': 1000,
        'max_file_count': 3,
        'after_date': '2026-10-01',
      };
    await pumpWatchedTest(tester, backend);
    await openSheet(tester);
    final ctrl = tester
        .widget<DbOnlineDownloadRequirementsFields>(
          find.byType(DbOnlineDownloadRequirementsFields),
        )
        .controller;
    expect(ctrl.quality, 'hd');
    expect(ctrl.requireSub, isTrue);
    expect(ctrl.minimum.text, '100');
    expect(ctrl.afterDate.text, '2026-10-01');
    expect(find.text('番号'), findsNothing);
    expect(find.text('超期天数'), findsNothing);
    await sheetTap(tester, '取消');
    expect(backend.to('/videos/recheck'), isEmpty);
  });

  testWidgets('停用预设使用默认条件；提交保留筛选与九项字段且反馈数量', (tester) async {
    final backend = WatchedTestBackend()
      ..preset = {'enabled': false, 'quality': 'uhd', 'require_sub': true};
    await pumpWatchedTest(tester, backend);
    await pickFilters(tester, ['5 星']);
    await openSheet(tester);
    await sheetTap(tester, '开始复查');
    final body = backend.to('/videos/recheck').single.data as Map;
    expect(body['scope'], 'watched');
    expect((body['filters'] as Map)['star'], '5');
    expect(body['requirements'], {
      'quality': '',
      'require_sub': false,
      'require_uncensored': false,
      'pre_download_mode': false,
      'wash_mode': false,
      'min_size_mb': 0.0,
      'max_size_mb': 0.0,
      'max_file_count': 0,
      'after_date': '',
    });
    expect(find.text('已提交 12 部影片的复查任务'), findsOneWidget);
    expect(find.byType(DbOnlineWatchedRecheckSheet), findsNothing);
  });

  testWidgets('预设读取失败可重试或使用默认条件', (tester) async {
    var fail = true;
    final backend = WatchedTestBackend()
      ..preset = {'enabled': true, 'quality': 'uhd'}
      ..respond = (request) => request.path == '/subs/preset' && fail
          ? {'success': false, 'error': '预设失败'}
          : null;
    await pumpWatchedTest(tester, backend);
    await openSheet(tester);
    expect(find.text('预设失败'), findsOneWidget);
    fail = false;
    await sheetTap(tester, '重试');
    final ctrl = tester
        .widget<DbOnlineDownloadRequirementsFields>(
          find.byType(DbOnlineDownloadRequirementsFields),
        )
        .controller;
    expect(ctrl.quality, 'uhd');
    await sheetTap(tester, '取消');
    fail = true;
    await openSheet(tester);
    await sheetTap(tester, '使用默认条件');
    await sheetTap(tester, '开始复查');
    expect(
      (backend.to('/videos/recheck').single.data as Map)['requirements'],
      containsPair('quality', ''),
    );
  });

  testWidgets('尺寸/文件数/日期校验拦截请求，失败保留面板可再提交', (tester) async {
    final backend = WatchedTestBackend()
      ..respond = (request) => request.path == '/videos/recheck'
          ? {'success': false, 'error': '复查失败'}
          : null;
    await pumpWatchedTest(tester, backend);
    await openSheet(tester);
    final ctrl = tester
        .widget<DbOnlineDownloadRequirementsFields>(
          find.byType(DbOnlineDownloadRequirementsFields),
        )
        .controller;
    for (final update in [
      () {
        ctrl.minimum.text = '-1';
      },
      () {
        ctrl.minimum.text = '0';
        ctrl.fileCount.text = '11';
      },
      () {
        ctrl.fileCount.text = '0';
        ctrl.afterDate.text = '2026-02-30';
      },
    ]) {
      update();
      await sheetTap(tester, '开始复查');
      expect(backend.to('/videos/recheck'), isEmpty);
    }
    ctrl.afterDate.text = '';
    await sheetTap(tester, '开始复查');
    expect(find.byType(DbOnlineWatchedRecheckSheet), findsOneWidget);
    expect(find.text('复查失败'), findsOneWidget);
    backend.respond = null;
    await sheetTap(tester, '开始复查');
    expect(find.byType(DbOnlineWatchedRecheckSheet), findsNothing);
  });

  testWidgets('复查期间禁止重复提交，零结果提示而不启动状态', (tester) async {
    final pending = Completer<Object?>();
    final backend = WatchedTestBackend()
      ..respond = (request) =>
          request.path == '/videos/recheck' ? pending.future : null;
    await pumpWatchedTest(tester, backend);
    await openSheet(tester);
    final button = find.widgetWithText(FilledButton, '开始复查');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpFollowingFrames(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(backend.to('/videos/recheck'), hasLength(1));
    pending.complete({
      'success': true,
      'data': {'total': 0},
    });
    await pumpFollowingFrames(tester);
    expect(find.text('没有可复查的匹配影片'), findsOneWidget);
  });

  testWidgets('排队/进度显示，任务结束刷新一次，重复结束广播不刷新', (tester) async {
    final backend = WatchedTestBackend();
    final sockets = WatchedTestSockets();
    await pumpWatchedTest(tester, backend, sockets: sockets);
    sockets.sockets.single.send(watchedTask(task: 'other', queued: true));
    await pumpFollowingFrames(tester);
    expect(find.text('复查排队中'), findsOneWidget);
    sockets.sockets.single.send(watchedTask(completed: 5));
    await pumpFollowingFrames(tester);
    expect(find.text('复查中：5 / 12'), findsOneWidget);
    final count = backend.to('/subs/watched').length;
    sockets.sockets.single.send(watchedTask(running: false, completed: 12));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/watched'), hasLength(count + 1));
    sockets.sockets.single.send(watchedTask(running: false, completed: 12));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/watched'), hasLength(count + 1));
  });

  testWidgets('切换服务器清空筛选和弹层，关闭旧连接，旧列表/预设响应无效', (tester) async {
    final old = Completer<Object?>();
    final backend = WatchedTestBackend();
    final sockets = WatchedTestSockets();
    final container = await pumpWatchedTest(tester, backend, sockets: sockets);
    backend.respond = (request) =>
        request.path == '/subs/preset' && request.baseUrl.contains('a.test')
        ? old.future
        : null;
    await pickFilters(tester, ['5 星']);
    await openSheet(tester);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    await pumpFollowingFrames(tester);
    old.complete({
      'success': true,
      'data': {
        'preset': {'enabled': true, 'quality': 'uhd'},
      },
    });
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineWatchedRecheckSheet), findsNothing);
    expect(sockets.sockets.first.closed, isTrue);
    expect(sockets.urls.last.host, 'b.test');
    expect(backend.to('/subs/watched').last.queryParameters['star'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换服务器后旧复查结果不提示或刷新新服务器', (tester) async {
    final old = Completer<Object?>();
    final backend = WatchedTestBackend()
      ..respond = (request) =>
          request.path == '/videos/recheck' ? old.future : null;
    final container = await pumpWatchedTest(tester, backend);
    await openSheet(tester);
    final button = find.widgetWithText(FilledButton, '开始复查');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpFollowingFrames(tester);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    await pumpFollowingFrames(tester);
    final count = backend.to('/subs/watched').length;
    old.complete({
      'success': true,
      'data': {'total': 999},
    });
    await pumpFollowingFrames(tester);
    expect(find.text('已提交 999 部影片的复查任务'), findsNothing);
    expect(backend.to('/subs/watched'), hasLength(count));
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐私遮罩标题封面，第一次揭开，第二次进入既有详情', (tester) async {
    final backend = WatchedTestBackend();
    final container = await pumpWatchedTest(tester, backend);
    await container.read(privacyShieldProvider.notifier).setEnabled(true);
    await pumpFollowingFrames(tester);
    expect(find.byType(PrivacyMask), findsWidgets);
    await tester.tap(find.byType(DbOnlineMovieCard).first);
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineMovieDetailPage), findsNothing);
    await tester.tap(find.byType(DbOnlineMovieCard).first);
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineMovieDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺失影片 ID 时按番号去重，不影响其他影片', (tester) async {
    final backend = WatchedTestBackend()
      ..movies = [
        {...watchedMovie(1), 'id': ''},
        {...watchedMovie(1), 'id': ''},
        {...watchedMovie(2), 'id': ''},
        watchedMovie(3),
      ];
    await pumpWatchedTest(tester, backend);
    expect(movies(tester).itemList!.map((movie) => movie.number), [
      'WATCH-1',
      'WATCH-2',
      'WATCH-3',
    ]);
    expect(movies(tester).nextPageKey, isNull);
  });

  testWidgets('复查面板完整条件按钮和成对输入保留九项下载字段', (tester) async {
    final backend = WatchedTestBackend();
    await pumpWatchedTest(tester, backend);
    await openSheet(tester);
    for (final label in ['预下载', '高清', '字幕', '破解', '洗板']) {
      await sheetTap(tester, label);
    }
    for (final (label, value) in [
      ('最小体积（MB）', '100'),
      ('最大体积（MB）', '4000'),
      ('最大文件数', '3'),
      ('起始日期', '2026-10-01'),
    ]) {
      await tester.ensureVisible(field(label));
      await tester.enterText(field(label), value);
    }
    tester.testTextInput.hide();
    await pumpFollowingFrames(tester);
    await sheetTap(tester, '开始复查');
    expect((backend.to('/videos/recheck').single.data as Map)['requirements'], {
      'quality': 'hd',
      'require_sub': true,
      'require_uncensored': true,
      'pre_download_mode': true,
      'wash_mode': true,
      'min_size_mb': 100.0,
      'max_size_mb': 4000.0,
      'max_file_count': 3,
      'after_date': '2026-10-01',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧服务器查询迟到时不覆盖新服务器列表', (tester) async {
    final old = Completer<Object?>();
    final backend = WatchedTestBackend();
    final container = await pumpWatchedTest(tester, backend);
    backend.respond = (request) {
      if (request.path != '/subs/watched') return null;
      if (request.baseUrl.contains('a.test')) return old.future;
      return watchedPayload([watchedMovie(2)]);
    };
    await pickFilters(tester, ['5 星']);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    await pumpFollowingFrames(tester);
    old.complete(watchedPayload([watchedMovie(99)]));
    await pumpFollowingFrames(tester);
    expect(movies(tester).itemList!.single.number, 'WATCH-2');
    expect(backend.to('/subs/watched').last.queryParameters['star'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('断线重连恢复完成快照后刷新列表，不重发复查', (tester) async {
    final backend = WatchedTestBackend();
    final sockets = WatchedTestSockets();
    await pumpWatchedTest(tester, backend, sockets: sockets);
    sockets.sockets.single.send(watchedTask(completed: 3));
    await pumpFollowingFrames(tester);
    await sockets.sockets.first.incoming.close();
    await pumpFollowingFrames(tester);
    expect(find.text('正在恢复复查进度连接'), findsOneWidget);
    final count = backend.to('/subs/watched').length;
    await tester.pump(const Duration(seconds: 2));
    expect(sockets.sockets, hasLength(2));
    sockets.sockets.last.send(watchedTask(running: false, completed: 12));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/watched'), hasLength(count + 1));
    expect(backend.to('/videos/recheck'), isEmpty);
    expect(find.text('复查中：3 / 12'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('320px双倍字体：${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = WatchedTestBackend();
      await pumpWatchedTest(tester, backend, locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byTooltip(locale.languageCode == 'zh' ? '复查' : 'Recheck'),
      );
      await pumpFollowingFrames(tester);
      expect(find.byType(DbOnlineWatchedRecheckSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('视图切换在竖版网格、横版和列表间切换并持久化', (tester) async {
    final backend = WatchedTestBackend()
      ..movies = [watchedMovie(1), watchedMovie(2)];
    final container = await pumpWatchedTest(tester, backend);
    expect(find.byType(PagedSliverGrid<int, DbOnlineMovie>), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await pumpFollowingFrames(tester);
    expect(find.byType(PagedSliverList<int, DbOnlineMovie>), findsOneWidget);
    final listCards = tester.widgetList<DbOnlineMovieCard>(
      find.byType(DbOnlineMovieCard),
    );
    expect(listCards, isNotEmpty);
    expect(listCards.every((card) => card.compact), isTrue);
    await tester.tap(find.byIcon(Icons.crop_landscape_rounded));
    await pumpFollowingFrames(tester);
    final cards = tester.widgetList<DbOnlineMovieCard>(
      find.byType(DbOnlineMovieCard),
    );
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.landscape && !card.compact), isTrue);
    expect(
      container
          .read(sharedPrefsProvider)
          .getString('db_online.watched.view_mode.v1'),
      'landscape',
    );
    expect(backend.to('/subs/watched'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
