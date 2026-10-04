import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record.dart';
import 'package:omm/features/db_online/pages/db_online_download_records_page.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';
import 'package:omm/features/db_online/widgets/db_online_download_record_filter_sheet.dart';
import 'package:omm/features/db_online/widgets/db_online_download_record_widgets.dart';
import 'package:omm/features/main/media_manager_shell.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/shared/catalog_search_field.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/floating_tab_bar.dart';
import 'package:omm/shared/glass_menu.dart';
import 'package:omm/shared/pagination_footer.dart';
import 'package:omm/shared/resource_panel_components.dart';

import '../support/download_records_test_support.dart';
import '../support/following_test_support.dart';

Future<void> sheetTap(WidgetTester tester, String text) async {
  final target = find
      .descendant(
        of: find.byType(DbOnlineDownloadRecordFilterSheet),
        matching: find.text(text),
      )
      .last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await pumpFollowingFrames(tester);
}

PagedListView<int, DbOnlineDownloadRecord> recordList(WidgetTester tester) =>
    tester.widget<PagedListView<int, DbOnlineDownloadRecord>>(
      find.byType(PagedListView<int, DbOnlineDownloadRecord>),
    );

Future<ProviderContainer> pumpRecords(
  WidgetTester tester,
  DownloadRecordsTestBackend backend, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) => pumpFollowingTest(
  tester,
  backend,
  const DbOnlineDownloadRecordsPage(),
  retry: (_, _) => null,
  locale: locale,
  textScale: textScale,
);

void main() {
  testWidgets('订阅长按滑动进入下载记录，返回保持原Tab，空白关闭菜单', (tester) async {
    final backend = DownloadRecordsTestBackend();
    await pumpFollowingTest(tester, backend, const MediaManagerShell());
    final tabBar = find.byType(FloatingTabBar<Object?>);
    expect(tester.widget<FloatingTabBar<Object?>>(tabBar).tabs, hasLength(5));
    final subscription = find.descendant(
      of: tabBar,
      matching: find.byIcon(Icons.subscriptions_outlined),
    );
    final anchor = find.ancestor(
      of: subscription,
      matching: find.byType(GlassMenuAnchor<Object?>),
    );
    final gesture = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('关注列表'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.text('下载记录')));
    await gesture.up();
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineDownloadRecordsPage), findsOneWidget);
    expect(find.byType(DbOnlineDownloadRecordCard), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await pumpFollowingFrames(tester);
    expect(tester.widget<FloatingTabBar<Object?>>(tabBar).active, 0);
    final outside = await tester.startGesture(tester.getCenter(anchor));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await outside.up();
    await pumpFollowingFrames(tester);
    await tester.tapAt(const Offset(10, 40));
    await pumpFollowingFrames(tester);
    expect(find.text('下载记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final success in [true, false]) {
    final status = success ? '成功' : '失败';
    testWidgets('页头使用共享方形筛选，重推按钮靠左紧邻$status状态', (tester) async {
      final backend = DownloadRecordsTestBackend()
        ..records = [downloadRecord(1, success: success)];
      await pumpRecords(tester, backend);
      final filter = find.descendant(
        of: find.byTooltip('筛选条件'),
        matching: find.byType(CompactFilterButton),
      );
      expect(filter, findsOneWidget);
      expect(tester.widget<CompactFilterButton>(filter).active, isFalse);
      expect(find.byTooltip('刷新'), findsNothing);

      final badge = tester.getRect(find.widgetWithText(CoverBadgePill, status));
      final repush = tester.getRect(find.widgetWithText(OutlinedButton, '重推'));
      final card = tester.getRect(find.byType(DbOnlineDownloadRecordCard));
      final expand = tester.getRect(find.byTooltip('展开记录详情'));
      expect(badge.left, closeTo(card.left + 12, 1));
      expect(repush.left - badge.right, closeTo(8, 1));
      expect(repush.center.dy, closeTo(badge.center.dy, 1));
      expect(repush.size.height, closeTo(badge.size.height, 0.01));
      expect(repush.size.width, closeTo(badge.size.width, 0.01));
      expect(repush.right, lessThan(expand.left));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('当天默认查询，卡片三行标题、共享标签、格式化时间及展开信息', (tester) async {
    final backend = DownloadRecordsTestBackend()
      ..records = [
        downloadRecord(
          1,
          sourceType: 'series_subscription',
          sourceLabel: '关注订阅 (1,2)',
        ),
      ];
    await pumpRecords(tester, backend);
    final today = DateTime.now().toIso8601String().split('T').first;
    expect(backend.to('/download-records').single.queryParameters, {
      'limit': 20,
      'offset': 0,
      'start_date': today,
      'end_date': today,
    });
    expect(backend.to('/downloaders').single.queryParameters, {
      'include_pan115_quota': true,
    });
    expect(
      tester
          .widgetList<PrivacyText>(find.byType(PrivacyText))
          .any((text) => text.text == '记录影片 1' && text.maxLines == 3),
      true,
    );
    expect(find.byType(ResourceTagBadges), findsOneWidget);
    expect(find.text('HD'), findsOneWidget);
    expect(find.text('字幕'), findsOneWidget);
    expect(find.text('破解'), findsOneWidget);
    expect(find.textContaining('2026-10-03T'), findsNothing);
    await tester.tap(find.byTooltip('展开记录详情'));
    await pumpFollowingFrames(tester);
    expect(find.text('关注订阅 (风格一 / 风格二) / 磁链 / nyaa'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('资源名称 1'), findsOneWidget);
    expect(find.text('共 1 条，筛选后 1 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消筛选不请求，应用多组选项后重置偏移量并发送false', (tester) async {
    final backend = DownloadRecordsTestBackend();
    await pumpRecords(tester, backend);
    await tester.tap(find.byTooltip('筛选条件'));
    await pumpFollowingFrames(tester);
    await sheetTap(tester, '失败');
    await sheetTap(tester, '取消');
    expect(backend.to('/download-records'), hasLength(1));
    await tester.tap(find.byTooltip('筛选条件'));
    await pumpFollowingFrames(tester);
    for (final label in ['高清', '字幕', '破解', '115 网盘', '综合订阅', '失败', '确定']) {
      await sheetTap(tester, label);
    }
    final query = backend.to('/download-records').last.queryParameters;
    expect(query['offset'], 0);
    expect(query['resource_types'], 'hd,sub,uncensored');
    expect(query['downloader'], 'pan115');
    expect(query['source_type'], 'series_subscription');
    expect(query['success'], false);
    expect(
      tester
          .widget<CompactFilterButton>(
            find.descendant(
              of: find.byTooltip('筛选条件'),
              matching: find.byType(CompactFilterButton),
            ),
          )
          .active,
      isTrue,
    );
    expect(find.text('暂无下载记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期选择和无效范围校验，取消不会提交请求', (tester) async {
    final backend = DownloadRecordsTestBackend();
    await pumpRecords(tester, backend);
    await tester.tap(find.byTooltip('筛选条件'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.byKey(const ValueKey('record-end-date')));
    await pumpFollowingFrames(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(
      tester.element(find.byType(DatePickerDialog)),
    ).pop(DateTime(2000, 1, 1));
    await pumpFollowingFrames(tester);
    await sheetTap(tester, '确定');
    expect(find.text('结束日期不能早于开始日期'), findsOneWidget);
    expect(backend.to('/download-records'), hasLength(1));
    expect(find.byType(DbOnlineDownloadRecordFilterSheet), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await sheetTap(tester, '取消');
    expect(tester.takeException(), isNull);
  });

  testWidgets('共享搜索提交与清空重置查询，快速切换丢弃旧响应', (tester) async {
    final backend = DownloadRecordsTestBackend();
    final slow = Completer<Object?>();
    backend.respond = (request) {
      if (request.path != '/download-records') return null;
      if (request.queryParameters['keyword'] == '慢') return slow.future;
      if (request.queryParameters['keyword'] == '快') {
        return downloadRecordPage([
          {...downloadRecord(2), 'video_title': '快速结果'},
        ]);
      }
      return null;
    };
    await pumpRecords(tester, backend);
    expect(find.byType(CatalogSearchField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '慢');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpFollowingFrames(tester);
    await tester.enterText(find.byType(TextField), '快');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpFollowingFrames(tester);
    slow.complete(
      downloadRecordPage([
        {...downloadRecord(3), 'video_title': '过期结果'},
      ]),
    );
    await pumpFollowingFrames(tester);
    expect(
      recordList(tester).pagingController.itemList!.single.videoTitle,
      '快速结果',
    );
    await tester.tap(find.byTooltip('清空'));
    await pumpFollowingFrames(tester);
    expect(
      backend.to('/download-records').last.queryParameters,
      isNot(contains('keyword')),
    );
    expect(recordList(tester).pagingController.itemList!.single.id, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自然分页按实际批次推进并按记录ID去重，以has_more结束', (tester) async {
    final backend = DownloadRecordsTestBackend();
    backend.respond = (request) {
      if (request.path != '/download-records') return null;
      final offset = request.queryParameters['offset'];
      if (offset == 0) {
        return downloadRecordPage(
          List.generate(20, (index) => downloadRecord(index + 1)),
          more: true,
        );
      }
      if (offset == 20) {
        return downloadRecordPage([
          downloadRecord(20),
          downloadRecord(21),
          downloadRecord(22),
        ], more: true);
      }
      if (offset == 23) return downloadRecordPage([downloadRecord(23)]);
      return null;
    };
    await pumpRecords(tester, backend);
    for (var index = 0; index < 6; index++) {
      await tester.drag(
        find.byType(PagedListView<int, DbOnlineDownloadRecord>),
        const Offset(0, -1800),
      );
      await pumpFollowingFrames(tester);
    }
    expect(
      backend
          .to('/download-records')
          .map((request) => request.queryParameters['offset']),
      [0, 20, 23],
    );
    final records = recordList(tester).pagingController.itemList!;
    expect(records, hasLength(23));
    expect(records.map((item) => item.id).toSet(), hasLength(23));
    expect(recordList(tester).pagingController.nextPageKey, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('第一页失败可重试，刷新沿用当前筛选', (tester) async {
    final backend = DownloadRecordsTestBackend();
    var fail = true;
    backend.respond = (request) => request.path == '/download-records' && fail
        ? {'success': false, 'error': '第一页读取失败'}
        : null;
    await pumpRecords(tester, backend);
    expect(find.text('第一页读取失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试'));
    await pumpFollowingFrames(tester);
    expect(recordList(tester).pagingController.itemList, hasLength(1));
    await tester.enterText(find.byType(TextField), 'DBO-1');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpFollowingFrames(tester);
    final beforeRefresh = backend.to('/download-records').length;
    await tester.drag(
      find.byType(PagedListView<int, DbOnlineDownloadRecord>),
      const Offset(0, 400),
    );
    await pumpFollowingFrames(tester);
    expect(backend.to('/download-records').length, greaterThan(beforeRefresh));
    expect(
      backend.to('/download-records').last.queryParameters['keyword'],
      'DBO-1',
    );
    expect(backend.to('/download-records').last.queryParameters['offset'], 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('追加页失败保留已加载记录并可重试同一偏移量', (tester) async {
    final backend = DownloadRecordsTestBackend();
    var failure = true;
    backend.respond = (request) {
      if (request.path != '/download-records') return null;
      if (request.queryParameters['offset'] == 0) {
        return downloadRecordPage(
          List.generate(20, (index) => downloadRecord(index + 1)),
          more: true,
        );
      }
      if (failure) return {'success': false, 'error': '第二页读取失败'};
      return downloadRecordPage([downloadRecord(21)]);
    };
    await pumpRecords(tester, backend);
    for (var index = 0; index < 4; index++) {
      await tester.drag(
        find.byType(PagedListView<int, DbOnlineDownloadRecord>),
        const Offset(0, -1800),
      );
      await pumpFollowingFrames(tester);
    }
    expect(recordList(tester).pagingController.itemList, hasLength(20));
    failure = false;
    final retry = find.descendant(
      of: find.byType(PaginationRetry),
      matching: find.byType(TextButton),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await pumpFollowingFrames(tester);
    expect(recordList(tester).pagingController.itemList, hasLength(21));
    expect(backend.to('/download-records').last.queryParameters['offset'], 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重推更新原记录和状态，保留来源／标记并刷新115配额', (tester) async {
    final backend = DownloadRecordsTestBackend()
      ..records = [
        downloadRecord(
          1,
          success: false,
          sourceType: 'actor_subscription',
          sourceLabel: '演员订阅 (1)',
        ),
      ];
    await pumpRecords(tester, backend);
    await tester.tap(find.text('重推'));
    await pumpFollowingFrames(tester);
    final body = backend.to('/download').single.data as Map;
    final resource = (body['record_resources'] as List).single as Map;
    expect(resource['record_id'], 1);
    expect(resource['source_type'], 'actor_subscription');
    expect(resource['source_label'], '演员订阅 (1)');
    expect(resource['resource_flags'], 26);
    expect(body['save_path'], '');
    expect(backend.records, hasLength(1));
    expect(recordList(tester).pagingController.itemList!.single.success, true);
    expect(backend.to('/downloaders'), hasLength(2));
    expect(backend.downloaders.single['available_quota'], 122);
    expect(find.text('已重推到 pan115'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('多个下载器展示配额，取消选择不推送也不刷新记录', (tester) async {
    final backend = DownloadRecordsTestBackend();
    backend.downloaders.add({
      'name': 'cd2',
      'display_name': 'CloudDrive2',
      'ed2k_enabled': true,
    });
    await pumpRecords(tester, backend);
    await tester.tap(find.text('重推'));
    await pumpFollowingFrames(tester);
    expect(find.text('选择下载器'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    await tester.tapAt(const Offset(10, 40));
    await pumpFollowingFrames(tester);
    expect(backend.to('/download'), isEmpty);
    expect(backend.to('/download-records'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('重推选择指定下载器，提交期间禁止重复操作', (tester) async {
    final backend = DownloadRecordsTestBackend();
    backend.downloaders.add({
      'name': 'cd2',
      'display_name': 'CloudDrive2',
      'ed2k_enabled': true,
    });
    final push = Completer<Object?>();
    backend.respond = (request) =>
        request.path == '/download' ? push.future : null;
    await pumpRecords(tester, backend);
    await tester.tap(find.text('重推'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('CloudDrive2'));
    await pumpFollowingFrames(tester);
    expect(find.text('重推中'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '重推中'))
          .onPressed,
      isNull,
    );
    expect((backend.to('/download').single.data as Map)['downloader'], 'cd2');
    push.complete({
      'success': true,
      'data': {'downloader': 'cd2'},
    });
    await pumpFollowingFrames(tester);
    expect(backend.to('/download'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ed2k只允许支持的下载器，无适配器时禁用重推', (tester) async {
    final backend = DownloadRecordsTestBackend()
      ..records = [downloadRecord(1, protocol: 'ed2k')];
    await pumpRecords(tester, backend);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '重推'))
          .onPressed,
      isNull,
    );
    expect(backend.to('/download'), isEmpty);
    backend.downloaders.add({
      'name': 'cd2',
      'display_name': 'CloudDrive2',
      'ed2k_enabled': true,
    });
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('重推'));
    await pumpFollowingFrames(tester);
    expect((backend.to('/download').single.data as Map)['downloader'], 'cd2');
    expect(find.text('选择下载器'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重推失败刷新服务端失败原因并使用统一错误提示', (tester) async {
    final backend = DownloadRecordsTestBackend()..pushFailed = true;
    await pumpRecords(tester, backend);
    await tester.tap(find.text('重推'));
    await pumpFollowingFrames(tester);
    expect(recordList(tester).pagingController.itemList!.single.success, false);
    expect(backend.to('/download-records'), hasLength(2));
    expect(backend.to('/downloaders'), hasLength(1));
    expect(find.textContaining('重推测试失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byTooltip('展开记录详情'));
    await pumpFollowingFrames(tester);
    expect(find.text('重推测试失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('数据库控制记录查询，在线查询和账户关闭仍可浏览', (tester) async {
    final backend = DownloadRecordsTestBackend()
      ..database = false
      ..onlineQuery = false
      ..onlineAccount = false;
    await pumpRecords(tester, backend);
    expect(find.text('请先在 DBO 后台启用数据库'), findsOneWidget);
    expect(backend.to('/download-records'), isEmpty);
    expect(backend.to('/downloaders'), isEmpty);
    backend.database = true;
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await pumpFollowingFrames(tester);
    expect(backend.to('/download-records'), hasLength(1));
    expect(find.byType(DbOnlineDownloadRecordCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('服务器切换重置筛选和弹层，过期查询不覆盖新服务器', (tester) async {
    final backend = DownloadRecordsTestBackend();
    final old = Completer<Object?>();
    backend.respond = (request) {
      if (request.path != '/download-records') return null;
      if (request.queryParameters['keyword'] == '旧') return old.future;
      if (request.uri.host == 'b.test') {
        return downloadRecordPage([
          {...downloadRecord(2), 'video_title': '服务器 B'},
        ]);
      }
      return null;
    };
    final container = await pumpRecords(tester, backend);
    await tester.enterText(find.byType(TextField), '旧');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpFollowingFrames(tester);
    await tester.tap(find.byTooltip('筛选条件'));
    await pumpFollowingFrames(tester);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineDownloadRecordFilterSheet), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    old.complete(
      downloadRecordPage([
        {...downloadRecord(3), 'video_title': '服务器 A 过期结果'},
      ]),
    );
    await pumpFollowingFrames(tester);
    expect(
      recordList(tester).pagingController.itemList!.single.videoTitle,
      '服务器 B',
    );
    expect(backend.to('/download-records').last.uri.host, 'b.test');
    expect(
      backend.to('/download-records').last.queryParameters,
      isNot(contains('keyword')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('服务器切换丢弃旧重推结果，不提示或刷新新服务器', (tester) async {
    final backend = DownloadRecordsTestBackend();
    final old = Completer<Object?>();
    backend.respond = (request) =>
        request.path == '/download' ? old.future : null;
    final container = await pumpRecords(tester, backend);
    await tester.tap(find.text('重推'));
    await pumpFollowingFrames(tester);
    (container.read(serverConfigProvider.notifier) as FollowingTestServerState)
        .select('b');
    await pumpFollowingFrames(tester);
    final count = backend.to('/download-records').length;
    old.complete({
      'success': true,
      'data': {'downloader': 'pan115'},
    });
    await pumpFollowingFrames(tester);
    expect(backend.to('/download-records'), hasLength(count));
    expect(find.textContaining('已重推到'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐私遮罩标题封面，首次揭开，第二次进入详情', (tester) async {
    final backend = DownloadRecordsTestBackend();
    final container = await pumpRecords(tester, backend);
    await container.read(privacyShieldProvider.notifier).setEnabled(true);
    await pumpFollowingFrames(tester);
    final title = find.byWidgetPredicate(
      (widget) => widget is PrivacyText && widget.text == '记录影片 1',
    );
    expect(
      find.descendant(of: title, matching: find.text('记录影片 1')),
      findsNothing,
    );
    expect(find.byType(PrivacyMask), findsOneWidget);
    await tester.tap(find.text('DBO-1'));
    await pumpFollowingFrames(tester);
    expect(container.read(revealedMoviesProvider), contains('video-1'));
    expect(find.byType(DbOnlineMovieDetailPage), findsNothing);
    await tester.tap(find.text('DBO-1'));
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineMovieDetailPage), findsOneWidget);
    expect(
      tester
          .widget<DbOnlineMovieDetailPage>(find.byType(DbOnlineMovieDetailPage))
          .detailKey,
      'video-1',
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    final localeCode = locale.languageCode;
    testWidgets('320px窄屏双倍字体卡片与筛选无溢出：$localeCode', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = DownloadRecordsTestBackend()
        ..records = [
          downloadRecord(1, types: ['normal']),
        ];
      await pumpRecords(tester, backend, locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
      final badge = tester.getRect(find.byType(CoverBadgePill));
      final repush = tester.getRect(
        find.descendant(
          of: find.byType(DbOnlineDownloadRecordCard),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(repush.height, closeTo(badge.height, 0.01));
      await tester.tap(find.byTooltip(localeCode == 'zh' ? '筛选条件' : 'Filters'));
      await pumpFollowingFrames(tester);
      expect(find.byType(DbOnlineDownloadRecordFilterSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
