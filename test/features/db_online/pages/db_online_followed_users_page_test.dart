import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/features/db_online/pages/db_online_followed_users_page.dart';
import 'package:omm/features/db_online/pages/db_online_review_resources_page.dart';

import '../support/following_test_support.dart';

void main() {
  Future<void> pumpNestedUsers(
    WidgetTester tester,
    FollowingTestBackend backend,
  ) => pumpFollowingTest(
    tester,
    backend,
    Navigator(
      onGenerateInitialRoutes: (_, _) => [
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('用户管理入口')),
        ),
        MaterialPageRoute<void>(
          builder: (_) => const DbOnlineFollowedUsersPage(serverId: 'a'),
        ),
      ],
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const DbOnlineFollowedUsersPage(serverId: 'a'),
      ),
    ),
  ).then((_) {});

  testWidgets('嵌套导航中取消添加关注只关闭弹窗，不新增用户或退出列表', (tester) async {
    final backend = FollowingTestBackend();
    await pumpNestedUsers(tester, backend);
    for (final input in ['', '00001']) {
      await tester.tap(find.byTooltip('添加关注用户'));
      await pumpFollowingFrames(tester);
      await tester.enterText(find.byType(TextFormField), input);
      await tester.tap(find.text('取消'));
      await pumpFollowingFrames(tester);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(DbOnlineFollowedUsersPage), findsOneWidget);
      expect(find.text('用户管理入口'), findsNothing);
      expect(backend.users, isEmpty);
      expect(
        backend.requests.where((request) => request.method != 'GET'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('嵌套导航中关注和取消关注使用弹窗结果，保留用户列表', (tester) async {
    final backend = FollowingTestBackend();
    await pumpNestedUsers(tester, backend);
    await tester.tap(find.byTooltip('添加关注用户'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('关注'));
    await pumpFollowingFrames(tester);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(backend.users, isEmpty);
    await tester.enterText(find.byType(TextFormField), ' 00001 ');
    await tester.tap(find.text('关注'));
    await pumpFollowingFrames(tester);
    expect(find.byType(TextFormField), findsNothing);
    expect(backend.users.single['user_id'], '00001');
    expect(find.byType(DbOnlineFollowedUsersPage), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await pumpFollowingFrames(tester);

    await tester.tap(find.byTooltip('取消关注'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('取消'));
    await pumpFollowingFrames(tester);
    expect(backend.users, hasLength(1));
    expect(find.text('确定取消关注 1 位用户吗？'), findsNothing);
    expect(find.byType(DbOnlineFollowedUsersPage), findsOneWidget);
    expect(
      backend
          .to('/following/users')
          .where((request) => request.method == 'DELETE'),
      isEmpty,
    );

    await tester.tap(find.byTooltip('取消关注'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('取消关注').last);
    await pumpFollowingFrames(tester);
    expect(backend.users, isEmpty);
    expect(find.byType(DbOnlineFollowedUsersPage), findsOneWidget);
    expect(find.text('用户管理入口'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('添加用户保留 ID 并反馈重复关注，单个取消需要确认', (tester) async {
    final backend = FollowingTestBackend();
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineFollowedUsersPage(serverId: 'a'),
    );
    expect(find.text('最新评论'), findsOneWidget);
    Future<void> follow() async {
      await tester.tap(find.byTooltip('添加关注用户'));
      await pumpFollowingFrames(tester);
      await tester.enterText(find.byType(TextFormField), '00001');
      await tester.tap(find.text('关注'));
      await pumpFollowingFrames(tester);
    }

    await follow();
    expect(backend.users.single['user_id'], '00001');
    expect(find.text('用户00001'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await pumpFollowingFrames(tester);
    await follow();
    expect(backend.users, hasLength(1));
    expect(find.text('已关注该用户，无需重复添加'), findsOneWidget);
    await tester.tap(find.byTooltip('取消关注'));
    await pumpFollowingFrames(tester);
    expect(
      backend
          .to('/following/users')
          .where((request) => request.method == 'DELETE'),
      isEmpty,
    );
    await tester.tap(find.text('取消'));
    await pumpFollowingFrames(tester);
    expect(backend.users, hasLength(1));
    await tester.tap(find.byTooltip('取消关注'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('取消关注').last);
    await pumpFollowingFrames(tester);
    expect(backend.users, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新遵循服务端顺序、显示当天更新并反馈部分失败，长按批量取消', (tester) async {
    final now = DateTime.now().toIso8601String();
    final backend = FollowingTestBackend()
      ..users.addAll([
        {'user_id': '1', 'username': '用户一', 'latest_review_at': now},
        {'user_id': '2', 'username': '用户二', 'latest_review_at': '2020-01-01'},
      ])
      ..refreshFailed = 1;
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineFollowedUsersPage(serverId: 'a'),
    );
    expect(find.byTooltip('今天有评论更新'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新用户评论'));
    await pumpFollowingFrames(tester);
    expect(
      tester.getTopLeft(find.text('用户二')).dy,
      lessThan(tester.getTopLeft(find.text('用户一')).dy),
    );
    expect(find.text('刷新完成，1 位用户刷新失败'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await pumpFollowingFrames(tester);
    await tester.longPress(find.text('用户二'));
    await pumpFollowingFrames(tester);
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.text('用户一'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('取消关注'));
    await pumpFollowingFrames(tester);
    expect(backend.users, hasLength(2));
    await tester.tap(find.text('取消关注').last);
    await pumpFollowingFrames(tester);
    expect(backend.users, isEmpty);
    final request = backend
        .to('/following/users')
        .singleWhere((request) => request.method == 'DELETE');
    expect((request.data as Map)['user_ids'], unorderedEquals(['1', '2']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('无在线账户禁用用户刷新，最新评论仍使用独立资源接口', (tester) async {
    final backend = FollowingTestBackend()..onlineAccount = false;
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineFollowedUsersPage(serverId: 'a'),
    );
    final refresh = tester.widget<HeaderActionButton>(
      find.byWidgetPredicate(
        (widget) => widget is HeaderActionButton && widget.tooltip == '刷新用户评论',
      ),
    );
    expect(refresh.onPressed, isNull);
    backend.respond = (request) => request.path == '/reviews/latest/resources'
        ? {
            'success': true,
            'data': {'items': [], 'has_next': false, 'page': 1},
          }
        : null;
    await tester.tap(find.text('最新评论'));
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineReviewResourcesPage), findsOneWidget);
    expect(backend.to('/reviews/latest/resources'), hasLength(1));
    expect(backend.to('/following/users/refresh'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
