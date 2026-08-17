import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
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
}
