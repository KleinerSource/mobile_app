import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/pages/db_online_following_page.dart';
import 'package:omm/features/db_online/pages/db_online_subscriptions_page.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_view_mode.dart';

import '../support/following_test_support.dart';

void main() {
  testWidgets('订阅点击进入订阅，长按滑动选择关注列表并返回原 Tab', (tester) async {
    final backend = FollowingTestBackend();
    await pumpFollowingTest(tester, backend, const MediaManagerShell());
    final tabs = tester.widget<FloatingTabBar<Object?>>(
      find.byType(FloatingTabBar<Object?>),
    );
    expect(tabs.tabs, hasLength(5));
    final subscription = find.descendant(
      of: find.byType(FloatingTabBar<Object?>),
      matching: find.byIcon(Icons.subscriptions_outlined),
    );
    await tester.tap(subscription);
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineSubscriptionsPage), findsOneWidget);
    final anchor = find.ancestor(
      of: subscription,
      matching: find.byType(GlassMenuAnchor<Object?>),
    );
    final gesture = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.text('关注列表')));
    await gesture.up();
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineFollowingPage), findsOneWidget);
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(find.text('请选择筛选条件或预设，开始加载关注影片'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await pumpFollowingFrames(tester);
    expect(
      tester
          .widget<FloatingTabBar<Object?>>(find.byType(FloatingTabBar<Object?>))
          .active,
      4,
    );

    final outsideGesture = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await outsideGesture.up();
    await pumpFollowingFrames(tester);
    await tester.tapAt(const Offset(10, 40));
    await pumpFollowingFrames(tester);
    expect(find.text('关注列表'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首次自动加载有码影片，切换筛选使用网页参数和共享卡片', (tester) async {
    final backend = FollowingTestBackend();
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    expect(backend.to('/subs/tags').single.queryParameters, {
      'filter_by': '0:t:m::::',
      'page': 1,
      'limit': 24,
      'sort_by': 'update',
      'order_by': 'desc',
    });
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(find.text('请选择筛选条件或预设，开始加载关注影片'), findsNothing);
    await tester.tap(find.byTooltip('筛选'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('无码'));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/tags').last.queryParameters, {
      'filter_by': '1:t:m::::',
      'page': 1,
      'limit': 24,
      'sort_by': 'update',
      'order_by': 'desc',
    });
    await tester.tap(find.text('字幕'));
    await pumpFollowingFrames(tester);
    expect(
      backend.to('/subs/tags').last.queryParameters['filter_by'],
      '1:t:m,c::::',
    );
    await tester.tap(find.text('发布日期'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('发布日期'));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/tags').last.queryParameters['order_by'], 'asc');
    await tester.tap(find.text('最近更新'));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/tags').last.queryParameters['order_by'], 'desc');
    Navigator.of(tester.element(find.text('资源条件'))).pop();
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(find.text('关注影片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速筛选的旧响应不覆盖新数据，换服务器重置筛选并关闭弹层', (tester) async {
    final backend = FollowingTestBackend();
    final old = Completer<Object?>();
    backend.respond = (request) =>
        request.path == '/subs/tags' &&
            request.queryParameters['filter_by'].toString().startsWith('1:')
        ? old.future
        : null;
    final container = await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineFollowingPage(),
    );
    await tester.tap(find.byTooltip('筛选'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('无码'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('欧美'));
    await pumpFollowingFrames(tester);
    old.complete({
      'success': true,
      'data': {
        'movies': [
          {'id': 'old', 'number': 'OLD-001', 'title': '旧筛选影片'},
        ],
        'has_more': false,
      },
    });
    await pumpFollowingFrames(tester);
    expect(find.text('旧筛选影片'), findsNothing);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    await pumpFollowingFrames(tester);
    expect(find.text('资源条件'), findsNothing);
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(backend.to('/subs/tags').last.uri.host, 'b.test');
    expect(
      backend.to('/subs/tags').last.queryParameters['filter_by'],
      '0:t:m::::',
    );
    await tester.tap(find.byTooltip('筛选'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('FC2'));
    await pumpFollowingFrames(tester);
    expect(backend.to('/subs/tags').last.uri.host, 'b.test');
    expect(
      backend.to('/subs/tags').last.queryParameters['filter_by'],
      '3:t:m::::',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定每页 24 条，自然加载下一页并支持刷新', (tester) async {
    final backend = FollowingTestBackend();
    backend.respond = (request) {
      if (request.path != '/subs/tags') return null;
      final page = request.queryParameters['page'] as int;
      return {
        'success': true,
        'data': {
          'movies': [
            for (var index = 0; index < (page == 1 ? 24 : 3); index++)
              {
                'id': '$page-$index',
                'number': 'ABC-$page-$index',
                'title': '影片$page-$index',
              },
          ],
          'has_more': page == 1,
        },
      };
    };
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    expect(find.byTooltip('手动编辑筛选'), findsNothing);
    expect(find.textContaining('每页数量'), findsNothing);
    for (
      var index = 0;
      index < 5 && backend.to('/subs/tags').length < 2;
      index++
    ) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await pumpFollowingFrames(tester);
    }
    expect(
      backend
          .to('/subs/tags')
          .map((request) => request.queryParameters['page']),
      [1, 2],
    );
    expect(
      backend
          .to('/subs/tags')
          .every((request) => request.queryParameters['limit'] == 24),
      isTrue,
    );
    expect(find.byType(DbOnlineMovieCard), findsWidgets);
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await pumpFollowingFrames(tester);
    await refresh;
    expect(backend.to('/subs/tags').last.queryParameters['page'], 1);
    expect(backend.to('/subs/tags').last.queryParameters['limit'], 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认影片查询失败后可重试相同筛选', (tester) async {
    final backend = FollowingTestBackend();
    var failed = true;
    backend.respond = (request) => request.path == '/subs/tags' && failed
        ? {'success': false, 'error': '查询失败'}
        : null;
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    expect(find.text('查询失败'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('重试'));
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(
      backend
          .to('/subs/tags')
          .map((request) => request.queryParameters['filter_by']),
      ['0:t:m::::', '0:t:m::::'],
    );
  });

  testWidgets('有码风格订阅使用 follow 契约，编辑和取消刷新状态', (tester) async {
    final backend = FollowingTestBackend()
      ..presets.add({
        'id': 1,
        'name': '风格关注',
        'category': '0',
        'basic': 'm',
        'styles': '1,2',
        'sort_by': 'update',
      });
    final container = await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineFollowingPage(),
    );
    var subscriptionReloads = 0;
    // 关注订阅操作会失效订阅管理列表缓存。
    final subscriptionListener = container.listen(
      dbOnlineSubscriptionListProvider(
        const DbOnlineSubscriptionQuery(
          serverId: 'a',
          kind: 'series',
          page: 1,
          limit: 24,
        ),
      ),
      (_, _) => subscriptionReloads++,
    );
    addTearDown(subscriptionListener.close);
    await tester.tap(find.text('风格关注'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.byTooltip('添加订阅'));
    await pumpFollowingFrames(tester);
    // 实体预览替代编号/名称只读字段：风格订阅显示 follow 图标与名称，编号不再展示。
    expect(find.byIcon(Icons.person_search_outlined), findsOneWidget);
    expect(find.text('风格一, 风格二'), findsOneWidget);
    expect(find.text('1,2'), findsNothing);
    final beforeCreate = subscriptionReloads;
    await tester.ensureVisible(find.text('保存').last);
    await tester.tap(find.text('保存').last);
    await pumpFollowingFrames(tester);
    final create = backend
        .to('/series-subs')
        .singleWhere((request) => request.method == 'POST');
    expect((create.data as Map)['external_id'], '1,2');
    expect((create.data as Map)['sub_type'], 'follow');
    // 行内统计徽标与按钮共用"订阅中"文案，按组件类型限定到操作按钮。
    final subscribedButton = find.byWidgetPredicate(
      (widget) => widget is HeaderActionButton && widget.tooltip == '订阅中',
    );
    expect(subscribedButton, findsOneWidget);
    expect(subscriptionReloads, greaterThan(beforeCreate));
    final beforeEdit = subscriptionReloads;
    await tester.tap(subscribedButton);
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('编辑订阅'));
    await pumpFollowingFrames(tester);
    await tester.ensureVisible(find.text('保存').last);
    await tester.tap(find.text('保存').last);
    await pumpFollowingFrames(tester);
    expect(
      backend
          .to('/series-subs/1%2C2')
          .where((request) => request.method == 'PUT'),
      hasLength(1),
    );
    expect(subscriptionReloads, greaterThan(beforeEdit));
    final beforeDelete = subscriptionReloads;
    await tester.tap(subscribedButton);
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('取消订阅'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('删除订阅').last);
    await pumpFollowingFrames(tester);
    expect(backend.subscribed, isFalse);
    expect(find.byTooltip('添加订阅'), findsOneWidget);
    expect(subscriptionReloads, greaterThan(beforeDelete));
  });

  testWidgets('确认在线查询能力后自动加载，未启用数据库也能浏览', (tester) async {
    final backend = FollowingTestBackend()..database = false;
    final health = Completer<Object?>();
    backend.respond = (request) =>
        request.path == '/health' ? health.future : null;
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    expect(backend.to('/subs/tags'), isEmpty);
    expect(find.byType(DbOnlineMovieCard), findsNothing);

    health.complete(backend.response(backend.to('/health').single));
    await pumpFollowingFrames(tester);
    expect(
      backend.to('/subs/tags').single.queryParameters['filter_by'],
      '0:t:m::::',
    );
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(find.byTooltip('添加预设'), findsNothing);
    expect(backend.to('/following/presets'), isEmpty);
    expect(backend.to('/options/categories'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无数据库和在线查询时隐藏数据库操作并停止影片查询', (tester) async {
    final backend = FollowingTestBackend()
      ..database = false
      ..onlineQuery = false;
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    expect(find.byTooltip('添加预设'), findsNothing);
    expect(find.byTooltip('管理预设'), findsNothing);
    expect(find.byTooltip('关注用户'), findsNothing);
    expect(find.text('请先在 DBO 后台启用在线查询'), findsOneWidget);
    expect(backend.to('/following/presets'), isEmpty);
    expect(backend.to('/options/categories'), isEmpty);
    expect(backend.to('/subs/tags'), isEmpty);
  });

  testWidgets('视图切换无数据库也可用，列表与横版持久化', (tester) async {
    final backend = FollowingTestBackend()..database = false;
    final container = await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineFollowingPage(),
    );
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await pumpFollowingFrames(tester);
    expect(
      tester.widget<DbOnlineMovieCard>(find.byType(DbOnlineMovieCard)).compact,
      isTrue,
    );
    // 列表模式渲染预览条目：左封面 + 右预览图翻页。
    expect(
      tester.widget<DbOnlineMovieCard>(find.byType(DbOnlineMovieCard)).previewList,
      isTrue,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('[ABC-001] 关注影片'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.crop_landscape_rounded));
    await pumpFollowingFrames(tester);
    expect(
      tester
          .widget<DbOnlineMovieCard>(find.byType(DbOnlineMovieCard))
          .landscape,
      isTrue,
    );
    expect(
      container
          .read(sharedPrefsProvider)
          .getString(mediaServerViewModeStorageKey('a')),
      'landscape',
    );
    expect(backend.to('/subs/tags'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('视图切换位于页头右侧，320px 页头不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 只验证页头；窄屏影片卡片布局不在此用例范围内。
    final backend = FollowingTestBackend()
      ..respond = (request) => request.path == '/subs/tags'
          ? {
              'success': true,
              'data': {'movies': [], 'has_more': false},
            }
          : null;
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    final toggle = find.descendant(
      of: find.byType(SettingsSubPageHeader),
      matching: find.byType(MediaViewModeToggle),
    );
    expect(toggle, findsOneWidget);
    expect(tester.getRect(toggle).right, lessThanOrEqualTo(320 - 22 + 0.01));
    expect(
      tester.getRect(find.byTooltip('关注用户')).right,
      lessThanOrEqualTo(tester.getRect(toggle).left),
    );
    expect(tester.takeException(), isNull);
  });
}
