import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  for (final action in ['失败', '筛选切换', '页面退出']) {
    test('后台补页期间$action，保留当前列表且停止后续请求', () async {
      final original = [1, 2, 3, 4, 5, 6];
      final controller = PagingController<int, int>(firstPageKey: 0)
        ..appendPage(original, 6);
      final requests = PagedRequestCoordinator();
      final pending = Completer<PagedResult<int>>();
      final secondPageStarted = Completer<void>();
      final offsets = <int>[];
      var applied = false;
      final refreshing = refreshPagedListInBackground<int>(
        controller: controller,
        requests: requests,
        onApplied: (_) => applied = true,
        loadPage: (limit, offset) async {
          offsets.add(offset);
          if (offset == 0) {
            return const PagedResult(
              items: [10, 11],
              totalCount: 8,
              limit: 2,
              offset: 0,
            );
          }
          secondPageStarted.complete();
          return pending.future;
        },
      );
      await secondPageStarted.future;
      expect(controller.itemList, original);
      expect(controller.nextPageKey, 6);
      if (action == '失败') {
        pending.completeError(StateError('第二页请求失败'));
      } else {
        if (action == '页面退出') {
          requests.dispose();
          controller.dispose();
        } else {
          requests.invalidate();
          controller.value = const PagingState(itemList: [99], nextPageKey: null);
        }
        pending.complete(
          const PagedResult(
            items: [12, 13],
            totalCount: 8,
            limit: 2,
            offset: 2,
          ),
        );
      }
      expect(await refreshing, isFalse);
      expect(offsets, [0, 2]);
      expect(applied, isFalse);
      if (action != '页面退出') {
        expect(controller.itemList, action == '失败' ? original : [99]);
        expect(controller.error, isNull);
        controller.dispose();
        requests.dispose();
      }
    });
  }

  for (final emptyLastPage in [false, true]) {
    test('后台补页遇到末页（空页=$emptyLastPage）一次性提交完整状态', () async {
      final controller = PagingController<int, int>(firstPageKey: 0)
        ..appendPage([1, 2, 3, 4, 5, 6], 6);
      final states = <PagingState<int, int>>[];
      controller.addListener(() => states.add(controller.value));
      PagedResult<int>? applied;
      await refreshPagedListInBackground<int>(
        controller: controller,
        onApplied: (page) => applied = page,
        loadPage: (limit, offset) async => offset == 0
            ? const PagedResult(
                items: [10, 11],
                totalCount: 3,
                limit: 2,
                offset: 0,
              )
            : PagedResult(
                items: emptyLastPage ? [] : [12],
                totalCount: 3,
                limit: 2,
                offset: 2,
              ),
      );
      expect(states, hasLength(1));
      expect(controller.itemList, emptyLastPage ? [10, 11] : [10, 11, 12]);
      expect(controller.nextPageKey, isNull);
      expect(applied!.items, controller.itemList);
      expect(applied!.offset, 0);
      expect(applied!.totalCount, 3);
      controller.dispose();
    });
  }

  testWidgets('后台刷新遇到服务端分页上限时保留深处的列表和滚动位置', (tester) async {
    final controller = PagingController<int, int>(firstPageKey: 0)
      ..appendPage(List.generate(120, (i) => i), 120);
    final scroll = ScrollController();
    final requests = PagedRequestCoordinator();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    addTearDown(requests.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PagedListView<int, int>(
          pagingController: controller,
          scrollController: scroll,
          builderDelegate: PagedChildBuilderDelegate<int>(
            itemBuilder: (_, item, __) =>
                SizedBox(height: 40, child: Text('$item')),
          ),
        ),
      ),
    );
    scroll.jumpTo(3600);
    await tester.pump();
    final response = Completer<PagedResult<int>>();
    final requestedOffsets = <int>[];
    final refreshing = refreshPagedListInBackground<int>(
      controller: controller,
      requests: requests,
      loadPage: (limit, offset) async {
        requestedOffsets.add(offset);
        final count = limit.clamp(0, 50);
        if (offset == 0) return response.future;
        return PagedResult(
          items: List.generate(count, (i) => offset + i + 1000),
          totalCount: 200,
          limit: count,
          offset: offset,
        );
      },
    );
    await tester.pump();
    expect(controller.itemList, hasLength(120));
    expect(scroll.offset, 3600);
    response.complete(
      PagedResult(
        items: List.generate(50, (i) => i + 1000),
        totalCount: 200,
        limit: 50,
        offset: 0,
      ),
    );
    await refreshing;
    await tester.pump();
    await tester.pump();
    expect(controller.itemList, List.generate(120, (i) => i + 1000));
    expect(controller.nextPageKey, 120);
    expect(requestedOffsets, [0, 50, 100]);
    expect(scroll.offset, 3600);
    await tester.pumpWidget(const SizedBox());
  });

  for (final pagingFinishesFirst in [true, false]) {
    test('后台刷新与翻页交错，翻页先完成=$pagingFinishesFirst', () async {
      final controller = PagingController<int, int>(firstPageKey: 0)
        ..appendPage([1, 2], 2);
      final requests = PagedRequestCoordinator();
      final oldRequest = requests.begin(2)!;
      final response = Completer<PagedResult<int>>();
      final background = refreshPagedListInBackground<int>(
        controller: controller,
        requests: requests,
        loadPage: (_, __) => response.future,
      );
      expect(oldRequest.isCurrent, isFalse);
      final nextPage = requests.begin(2)!;
      if (pagingFinishesFirst) {
        controller.appendLastPage([3]);
        nextPage.finish();
      }
      response.complete(
        const PagedResult<int>(
          items: [8, 9],
          totalCount: 4,
          limit: 2,
          offset: 0,
        ),
      );
      expect(await background, !pagingFinishesFirst);
      expect(controller.itemList, pagingFinishesFirst ? [1, 2, 3] : [8, 9]);
      expect(nextPage.isCurrent, isFalse);
      requests.dispose();
      controller.dispose();
    });
  }

  test('后台刷新期间销毁分页控制器，晚到结果不写入', () async {
    final controller = PagingController<int, int>(firstPageKey: 0)
      ..appendLastPage([1]);
    final requests = PagedRequestCoordinator();
    final response = Completer<PagedResult<int>>();
    final background = refreshPagedListInBackground<int>(
      controller: controller,
      requests: requests,
      loadPage: (_, __) => response.future,
    );
    requests.dispose();
    controller.dispose();
    response.complete(
      const PagedResult<int>(items: [8], totalCount: 1, limit: 1, offset: 0),
    );
    expect(await background, isFalse);
  });
  testWidgets('分页刷新恢复原滚动位置', (tester) async {
    final scrollController = ScrollController();
    final pagingController = PagingController<int, int>(firstPageKey: 0);
    final restorer = PagedScrollPositionRestorer<int>(pagingController);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: ListView(
          controller: scrollController,
          children: [
            for (var i = 0; i < 80; i++)
              SizedBox(height: 40, child: Text('$i')),
          ],
        ),
      ),
    );

    scrollController.jumpTo(500);
    restorer.prepare(scrollController, preserve: true);
    scrollController.jumpTo(0);
    restorer.restoreAfterPage(scrollController);
    await tester.pump();

    expect(scrollController.offset, closeTo(500, 0.5));

    pagingController.dispose();
    scrollController.dispose();
  });

  test('后台刷新保留列表并更新分页游标', () async {
    final pagingController = PagingController<int, int>(firstPageKey: 0)
      ..appendLastPage([1, 2]);

    final refreshed = await refreshPagedListInBackground<int>(
      controller: pagingController,
      loadPage: (limit, offset) async {
        expect(limit, 2);
        expect(offset, 0);
        return const PagedResult<int>(
          items: [3, 4],
          totalCount: 5,
          limit: 2,
          offset: 0,
        );
      },
    );

    expect(refreshed, isTrue);
    expect(pagingController.itemList, [3, 4]);
    expect(pagingController.nextPageKey, 2);
    expect(pagingController.value.status, PagingStatus.ongoing);
    pagingController.dispose();
  });

  test('后台刷新期间列表发生变化时丢弃旧结果', () async {
    final pagingController = PagingController<int, int>(firstPageKey: 0)
      ..appendLastPage([1, 2]);
    final result = Completer<PagedResult<int>>();

    final refreshing = refreshPagedListInBackground<int>(
      controller: pagingController,
      loadPage: (_, __) => result.future,
    );
    pagingController.refresh();
    pagingController.appendLastPage([9]);
    result.complete(
      const PagedResult<int>(items: [3, 4], totalCount: 2, limit: 2, offset: 0),
    );

    expect(await refreshing, isFalse);
    expect(pagingController.itemList, [9]);
    pagingController.dispose();
  });
}
