import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/pages/db_online_review_resources_page.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/db_online/widgets/db_online_resource_sheets.dart';

import '../support/following_test_support.dart';

void main() {
  testWidgets('关注用户影片长标题在窄屏换行，第三行省略且没有布局溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final title = List.filled(8, '关注用户发布的影片标题需要自然换行显示').join();
    final backend = FollowingTestBackend();
    backend.respond = (request) => request.path == '/users/one/resources'
        ? {
            'success': true,
            'data': {
              'items': [followingReview(1, title)],
              'page': 1,
              'has_next': false,
            },
          }
        : null;
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineReviewResourcesPage(serverId: 'a', userId: 'one'),
    );
    for (final width in [375.0, 320.0]) {
      tester.view.physicalSize = Size(width, 812);
      await pumpFollowingFrames(tester);
      final displayTitle = '[ABC-001] $title';
      final finder = find.text(displayTitle);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final lines = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: displayTitle.length),
          )
          .map((box) => box.top)
          .toSet();
      expect(lines, hasLength(3));
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.widget<Text>(finder).overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('资源先显示，再按评论补全去重，共用下载记录、复制和下载器选择', (tester) async {
    final metadata = Completer<Object?>();
    final backend = FollowingTestBackend();
    const magnet = 'magnet:?xt=urn:btih:ABCDEF';
    const ed2k = 'ed2k://|file|ABC-001.mp4|1024|123456|/';
    final review = followingReview(1, '评论影片')
      ..['ed2ks'] = [
        {'name': '电驴资源', 'ed2k': ed2k},
        {'name': '电驴重复', 'ed2k': ed2k},
      ];
    backend.respond = (request) => switch (request.path) {
      '/users/00001/resources' => {
        'success': true,
        'data': {
          'username': '用户一',
          'items': [review, review],
          'page': 1,
          'has_next': false,
        },
      },
      '/users/resources/metadata' => metadata.future,
      '/video/ABC-001/download-history' => {
        'success': true,
        'data': {
          'magnets': {'ABCDEF': '2026-10-01T01:00:00Z'},
          'ed2ks': {},
        },
      },
      '/downloaders' => {
        'success': true,
        'data': {
          'downloaders': [
            {'name': 'magnet', 'display_name': '磁链下载器', 'ed2k_enabled': false},
            {'name': 'both', 'display_name': '电驴下载器', 'ed2k_enabled': true},
          ],
        },
      },
      _ => null,
    };
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineReviewResourcesPage(serverId: 'a', userId: '00001'),
    );
    expect(find.byType(DbOnlineMovieCard), findsOneWidget);
    expect(find.text('评论影片'), findsOneWidget);
    expect(find.text('评论磁链'), findsOneWidget);
    expect(find.byType(DbOnlineResourceRow), findsNWidgets(2));
    expect(find.byTooltip('正在补全磁链信息'), findsOneWidget);
    expect(backend.to('/users/00001/resources').single.queryParameters, {
      'page': 1,
      'limit': 24,
    });
    final raw = tester
        .widgetList<DbOnlineResourceRow>(find.byType(DbOnlineResourceRow))
        .first;
    expect(raw.downloadedAt, '2026-10-01T01:00:00Z');

    metadata.complete({
      'success': true,
      'data': {
        'items': [
          {
            'review_id': 1,
            'magnets': [
              {
                'name': '补全磁链',
                'magnet': magnet,
                'tags': ['高清', '字幕', '破解'],
                'size_mb': 4096,
              },
              {'name': '重复磁链', 'magnet': 'magnet:?xt=urn:btih:abcdef'},
            ],
          },
        ],
      },
    });
    await pumpFollowingFrames(tester);
    expect(find.text('补全磁链'), findsOneWidget);
    expect(find.text('重复磁链'), findsNothing);
    expect(find.byType(DbOnlineResourceRow), findsNWidgets(2));
    expect(find.byTooltip('正在补全磁链信息'), findsNothing);
    final enriched = tester
        .widgetList<DbOnlineResourceRow>(find.byType(DbOnlineResourceRow))
        .first;
    expect(enriched.tags, ['高清', '字幕', '破解']);
    expect(enriched.sizeMb, 4096);
    await tester.tap(find.byTooltip('复制').first);
    await pumpFollowingFrames(tester);
    expect(copied, magnet);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await pumpFollowingFrames(tester);
    await tester.tap(find.byTooltip('推送下载').first);
    await pumpFollowingFrames(tester);
    expect(backend.to('/download'), isEmpty);
    expect(find.text('磁链下载器'), findsOneWidget);
    await tester.tap(find.text('磁链下载器'));
    await pumpFollowingFrames(tester);
    final push = backend.to('/download').single.data as Map;
    expect(push['downloader'], 'magnet');
    expect(push['urls'], [magnet]);
    expect((push['record_resources'] as List).single['resource_flags'], 26);
    expect(backend.to('/video/ABC-001/download-history'), hasLength(2));
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await pumpFollowingFrames(tester);
    await tester.tap(find.byTooltip('推送下载').last);
    await pumpFollowingFrames(tester);
    expect((backend.to('/download').last.data as Map)['downloader'], 'both');
    expect((backend.to('/download').last.data as Map)['urls'], [ed2k]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换用户和服务器时丢弃旧列表及元数据响应', (tester) async {
    final oldPage = Completer<Object?>();
    final oldMetadata = Completer<Object?>();
    final backend = FollowingTestBackend();
    final user = ValueNotifier((server: 'a', id: 'first'));
    addTearDown(user.dispose);
    backend.respond = (request) {
      if (request.path == '/users/first/resources') return oldPage.future;
      if (request.path == '/users/second/resources' ||
          request.path == '/users/third/resources') {
        final title = request.uri.host == 'b.test' ? '新服务器影片' : '新用户影片';
        return {
          'success': true,
          'data': {
            'items': [followingReview(1, title)],
            'has_next': false,
          },
        };
      }
      if (request.path == '/users/resources/metadata') {
        return request.uri.host == 'a.test'
            ? oldMetadata.future
            : {
                'success': true,
                'data': {
                  'items': [
                    {
                      'review_id': 1,
                      'magnets': [
                        {'magnet': 'magnet:?xt=urn:btih:NEW', 'name': '新服务器资源'},
                      ],
                    },
                  ],
                },
              };
      }
      return null;
    };
    final container = await pumpFollowingTest(
      tester,
      backend,
      ValueListenableBuilder(
        valueListenable: user,
        builder: (_, value, _) => DbOnlineReviewResourcesPage(
          serverId: value.server,
          userId: value.id,
        ),
      ),
    );
    user.value = (server: 'a', id: 'second');
    await pumpFollowingFrames(tester);
    expect(find.text('新用户影片'), findsOneWidget);
    oldPage.complete({
      'success': true,
      'data': {
        'items': [followingReview(2, '旧用户影片')],
        'has_next': false,
      },
    });
    await pumpFollowingFrames(tester);
    expect(find.text('旧用户影片'), findsNothing);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    user.value = (server: 'b', id: 'third');
    await pumpFollowingFrames(tester);
    oldMetadata.complete({
      'success': true,
      'data': {
        'items': [
          {
            'review_id': 1,
            'magnets': [
              {'magnet': 'magnet:?xt=urn:btih:OLD', 'name': '旧用户补全'},
            ],
          },
        ],
      },
    });
    await pumpFollowingFrames(tester);
    expect(find.text('旧用户补全'), findsNothing);
    expect(find.text('新用户影片'), findsNothing);
    expect(find.text('新服务器影片'), findsOneWidget);
    expect(find.text('新服务器资源'), findsOneWidget);
    expect(backend.to('/users/third/resources').single.uri.host, 'b.test');
    expect(tester.takeException(), isNull);
  });

  testWidgets('最新评论按返回页码逐批累积并按 has_next 结束', (tester) async {
    final backend = FollowingTestBackend();
    final second = Completer<Object?>();
    backend.respond = (request) {
      if (request.path == '/reviews/latest/resources') {
        if (request.queryParameters['page'] == 1) {
          return {
            'success': true,
            'data': {
              'items': [followingReview(1, '第一批影片')],
              'page': 3,
              'has_next': true,
            },
          };
        }
        return second.future;
      }
      return null;
    };
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineReviewResourcesPage(
        serverId: 'a',
        userId: 'latest_reviews',
        latest: true,
      ),
    );
    expect(find.text('第一批影片'), findsOneWidget);
    expect(
      backend
          .to('/reviews/latest/resources')
          .map((request) => request.queryParameters['page']),
      [1, 4],
    );
    second.complete({
      'success': true,
      'data': {
        'items': [followingReview(1, '重复影片'), followingReview(2, '第二批影片')],
        'page': 5,
        'has_next': false,
      },
    });
    await pumpFollowingFrames(tester);
    expect(find.text('第一批影片'), findsOneWidget);
    expect(find.text('重复影片'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await pumpFollowingFrames(tester);
    expect(find.text('第二批影片'), findsOneWidget);
    expect(backend.to('/reviews/latest/resources'), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通用户滚动自然加载，资源失败可重试', (tester) async {
    final backend = FollowingTestBackend();
    var fail = true;
    backend.respond = (request) {
      if (request.path != '/users/one/resources') return null;
      if (fail) return {'success': false, 'error': '资源查询失败'};
      final page = request.queryParameters['page'] as int;
      return {
        'success': true,
        'data': {
          'items': [
            for (var i = 0; i < (page == 1 ? 4 : 1); i++)
              followingReview(page * 10 + i, '影片$page-$i'),
          ],
          'page': page,
          'has_next': page == 1,
        },
      };
    };
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineReviewResourcesPage(serverId: 'a', userId: 'one'),
    );
    expect(find.text('资源查询失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试'));
    await pumpFollowingFrames(tester);
    expect(
      backend
          .to('/users/one/resources')
          .map((request) => request.queryParameters['page']),
      [1, 1],
    );
    for (
      var i = 0;
      i < 5 && backend.to('/users/one/resources').length < 3;
      i++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await pumpFollowingFrames(tester);
    }
    expect(backend.to('/users/one/resources').last.queryParameters['page'], 2);
    expect(
      backend
          .to('/users/one/resources')
          .every((request) => request.queryParameters['limit'] == 24),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭在线查询时不请求资源及磁链元数据', (tester) async {
    final backend = FollowingTestBackend()..onlineQuery = false;
    await pumpFollowingTest(
      tester,
      backend,
      const DbOnlineReviewResourcesPage(serverId: 'a', userId: 'one'),
    );
    expect(find.text('请先在 DBO 后台启用在线查询'), findsOneWidget);
    expect(backend.to('/users/one/resources'), isEmpty);
    expect(backend.to('/users/resources/metadata'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
