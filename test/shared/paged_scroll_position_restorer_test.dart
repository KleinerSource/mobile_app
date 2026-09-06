import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/shared/paged_scroll_position_restorer.dart';
import 'package:omm/shared/paged_request_coordinator.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
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
        loadFirstPage: (_) => response.future,
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
      loadFirstPage: (_) => response.future,
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
      loadFirstPage: (limit) async {
        expect(limit, 2);
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
      loadFirstPage: (_) => result.future,
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
