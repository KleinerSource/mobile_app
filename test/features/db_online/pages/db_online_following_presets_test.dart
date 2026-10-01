import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/db_online/pages/db_online_following_page.dart';

import '../support/following_test_support.dart';

void main() {
  testWidgets('预设保存、修改名称备注和确认删除', (tester) async {
    final backend = FollowingTestBackend();
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    await tester.tap(find.text('关注预设'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.byTooltip('保存当前预设'));
    await pumpFollowingFrames(tester);
    await tester.enterText(find.byType(TextFormField).first, '我的关注');
    await tester.enterText(find.byType(TextFormField).last, '备注');
    await tester.tap(find.text('保存'));
    await pumpFollowingFrames(tester);
    expect(backend.presets.single['basic'], 'm');
    expect(backend.presets.single['category'], '0');
    expect(find.text('我的关注'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑预设'));
    await pumpFollowingFrames(tester);
    await tester.enterText(find.byType(TextFormField).first, '修改关注');
    await tester.enterText(find.byType(TextFormField).last, '修改备注');
    await tester.tap(find.text('保存'));
    await pumpFollowingFrames(tester);
    expect(find.text('修改关注'), findsOneWidget);
    expect(find.text('修改备注'), findsOneWidget);
    expect(backend.presets.single['styles'], '');

    await tester.tap(find.byTooltip('删除预设'));
    await pumpFollowingFrames(tester);
    expect(
      backend
          .to('/following/presets/1')
          .where((request) => request.method == 'DELETE'),
      isEmpty,
    );
    await tester.tap(find.text('取消'));
    await pumpFollowingFrames(tester);
    expect(backend.presets, hasLength(1));
    await tester.tap(find.byTooltip('删除预设'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('删除预设').last);
    await pumpFollowingFrames(tester);
    expect(backend.presets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预设拖动排序失败恢复服务端顺序，重试可保存', (tester) async {
    final backend = FollowingTestBackend()
      ..presets.addAll([
        {'id': 1, 'name': '预设一', 'category': '0', 'basic': 'm'},
        {'id': 2, 'name': '预设二', 'category': '0', 'basic': 'c'},
        {'id': 3, 'name': '预设三', 'category': '1', 'basic': 'm'},
      ]);
    var failReorder = true;
    backend.respond = (request) =>
        request.path == '/following/presets/reorder' && failReorder
        ? {'success': false, 'error': '排序保存失败'}
        : null;
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    await tester.tap(find.text('关注预设'));
    await pumpFollowingFrames(tester);

    Future<void> reorder() async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.drag_handle_rounded).first),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(
        tester.getBottomLeft(find.text('预设三')) + const Offset(0, 25),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await pumpFollowingFrames(tester);
    }

    await reorder();
    expect(backend.to('/following/presets/reorder'), hasLength(1));
    expect(find.text('排序保存失败'), findsOneWidget);
    expect(backend.presets.map((item) => item['id']), [1, 2, 3]);
    expect(
      tester.getTopLeft(find.text('预设一')).dy,
      lessThan(tester.getTopLeft(find.text('预设二')).dy),
    );
    expect(
      backend
          .to('/following/presets')
          .where((request) => request.method == 'GET')
          .length,
      greaterThan(1),
    );

    failReorder = false;
    await reorder();
    expect(backend.to('/following/presets/reorder'), hasLength(2));
    expect(backend.presets.map((item) => item['id']), [2, 1, 3]);
    expect(
      tester.getTopLeft(find.text('预设二')).dy,
      lessThan(tester.getTopLeft(find.text('预设一')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
