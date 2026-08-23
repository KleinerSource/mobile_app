import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:md_center/core/models/paged_result.dart';
import 'package:md_center/shared/paged_scroll_position_restorer.dart';

void main() {
  testWidgets('分页刷新恢复原滚动位置', (tester) async {
    final scrollController = ScrollController();
    final pagingController = PagingController<int, int>(firstPageKey: 0);
    final restorer = PagedScrollPositionRestorer<int>(pagingController);

    await tester.pumpWidget(
      MaterialApp(
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
