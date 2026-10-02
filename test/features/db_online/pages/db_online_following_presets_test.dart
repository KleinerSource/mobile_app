import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/db_online/pages/db_online_following_page.dart';
import 'package:omm/features/db_online/widgets/db_online_following_presets_sheet.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/shared/filter_chip.dart';

import '../support/following_test_support.dart';

void main() {
  Finder presetText(String name) => find.descendant(
    of: find.byType(DbOnlineFollowingPresetsSheet),
    matching: find.text(name),
  );

  testWidgets('全部预设单行滚动，末尾加号直接添加，齿轮打开管理并保留影片间距', (tester) async {
    final backend = FollowingTestBackend()
      ..presets.addAll([
        for (var id = 1; id <= 7; id++)
          {
            'id': id,
            'name': '关注列表$id较长名称',
            'category': id == 1 ? '0' : '1',
            'basic': id == 1 ? 'm' : 'c',
          },
      ]);
    await pumpFollowingTest(tester, backend, const DbOnlineFollowingPage());
    expect(backend.to('/subs/tags'), isEmpty);
    expect(find.byType(DbOnlineFollowingPresetsSheet), findsNothing);
    final buttons = tester
        .widgetList<CompactFilterButton>(find.byType(CompactFilterButton))
        .toList();
    expect(buttons.map((button) => button.label), [
      for (var id = 1; id <= 7; id++) '关注列表$id较长名称',
      '',
      '',
    ]);
    expect(buttons[7].icon, Icons.add_rounded);
    expect(buttons[8].icon, Icons.settings_outlined);
    expect(
      tester.getCenter(find.text('关注列表1较长名称')).dy,
      tester.getCenter(find.text('关注列表7较长名称')).dy,
    );
    await tester.tap(find.text('关注列表1较长名称'));
    await pumpFollowingFrames(tester);
    expect(
      backend.to('/subs/tags').last.queryParameters['filter_by'],
      '0:t:m::::',
    );
    expect(
      tester.getTopLeft(find.byType(DbOnlineMovieCard)).dy -
          tester.getBottomLeft(find.byType(CompactFilterButton).first).dy,
      greaterThanOrEqualTo(16),
    );
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(horizontal, const Offset(-1400, 0));
    await pumpFollowingFrames(tester);
    await tester.tap(find.text('关注列表7较长名称'));
    await pumpFollowingFrames(tester);
    expect(
      backend.to('/subs/tags').last.queryParameters['filter_by'],
      '1:t:c::::',
    );
    expect(backend.to('/subs/tags').last.queryParameters['page'], 1);
    expect(
      tester
          .widgetList<CompactFilterButton>(find.byType(CompactFilterButton))
          .singleWhere((button) => button.active)
          .label,
      '关注列表7较长名称',
    );
    await tester.tap(find.byTooltip('添加预设'));
    await pumpFollowingFrames(tester);
    expect(find.text('保存当前预设'), findsOneWidget);
    expect(find.byType(DbOnlineFollowingPresetsSheet), findsNothing);
    await tester.tap(find.text('取消'));
    await pumpFollowingFrames(tester);
    expect(backend.presets, hasLength(7));
    await tester.tap(find.byTooltip('管理预设'));
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineFollowingPresetsSheet), findsOneWidget);
    expect(presetText('关注列表7较长名称'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('嵌套导航中取消保存或编辑预设只关闭弹窗，不保存或退出列表', (tester) async {
    final backend = FollowingTestBackend()
      ..presets.add({'id': 1, 'name': '原预设', 'category': '0', 'basic': 'm'});
    await pumpFollowingTest(
      tester,
      backend,
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const DbOnlineFollowingPage(),
        ),
      ),
    );
    for (final tooltip in ['保存当前预设', '编辑预设']) {
      if (tooltip == '编辑预设') {
        await tester.tap(find.byTooltip('管理预设'));
        await pumpFollowingFrames(tester);
        await tester.tap(find.byTooltip(tooltip));
      } else {
        await tester.tap(find.byTooltip('添加预设'));
      }
      await pumpFollowingFrames(tester);
      await tester.enterText(find.byType(TextFormField).first, '未保存名称');
      await tester.enterText(find.byType(TextFormField).last, '未保存备注');
      await tester.tap(find.text('取消'));
      await pumpFollowingFrames(tester);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(DbOnlineFollowingPage), findsOneWidget);
      if (tooltip == '编辑预设') {
        expect(find.byType(DbOnlineFollowingPresetsSheet), findsOneWidget);
        expect(presetText('原预设'), findsOneWidget);
      } else {
        expect(find.byType(DbOnlineFollowingPresetsSheet), findsNothing);
      }
      expect(
        backend.requests.where((request) => request.method != 'GET'),
        isEmpty,
      );
      expect(backend.presets.single['name'], '原预设');
      expect(backend.to('/subs/tags'), isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('预设保存、修改名称备注和确认删除', (tester) async {
    final backend = FollowingTestBackend();
    await pumpFollowingTest(
      tester,
      backend,
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const DbOnlineFollowingPage(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('添加预设'));
    await pumpFollowingFrames(tester);
    await tester.enterText(find.byType(TextFormField).first, '我的关注');
    await tester.enterText(find.byType(TextFormField).last, '备注');
    await tester.tap(find.text('保存'));
    await pumpFollowingFrames(tester);
    expect(backend.presets.single['basic'], 'm');
    expect(backend.presets.single['category'], '0');
    expect(find.text('我的关注'), findsOneWidget);

    await tester.tap(find.byTooltip('管理预设'));
    await pumpFollowingFrames(tester);
    await tester.tap(find.byTooltip('编辑预设'));
    await pumpFollowingFrames(tester);
    await tester.enterText(find.byType(TextFormField).first, '修改关注');
    await tester.enterText(find.byType(TextFormField).last, '修改备注');
    await tester.tap(find.text('保存'));
    await pumpFollowingFrames(tester);
    expect(presetText('修改关注'), findsOneWidget);
    expect(find.text('我的关注'), findsNothing);
    expect(find.text('修改备注'), findsOneWidget);
    expect(backend.presets.single['styles'], '');
    expect(
      tester
          .widgetList<CompactFilterButton>(find.byType(CompactFilterButton))
          .singleWhere((button) => button.active)
          .label,
      '修改关注',
    );

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
    Navigator.of(
      tester.element(find.byType(DbOnlineFollowingPresetsSheet)),
    ).pop();
    await pumpFollowingFrames(tester);
    expect(find.text('修改关注'), findsNothing);
    expect(find.byTooltip('添加预设'), findsOneWidget);
    expect(find.byTooltip('管理预设'), findsOneWidget);
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
    await tester.tap(find.byTooltip('管理预设'));
    await pumpFollowingFrames(tester);

    Future<void> reorder() async {
      final headerY = tester.getTopLeft(find.text('关注预设').last).dy;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.drag_handle_rounded).first),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(
        tester.getBottomLeft(presetText('预设三')) + const Offset(0, 25),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getTopLeft(find.text('关注预设').last).dy, headerY);
      await gesture.up();
      await pumpFollowingFrames(tester);
    }

    await reorder();
    expect(backend.to('/following/presets/reorder'), hasLength(1));
    expect(find.text('排序保存失败'), findsOneWidget);
    expect(backend.presets.map((item) => item['id']), [1, 2, 3]);
    expect(
      tester.getTopLeft(presetText('预设一')).dy,
      lessThan(tester.getTopLeft(presetText('预设二')).dy),
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
      tester.getTopLeft(presetText('预设二')).dy,
      lessThan(tester.getTopLeft(presetText('预设一')).dy),
    );
    await tester.drag(find.text('关注预设').last, const Offset(0, 180));
    await pumpFollowingFrames(tester);
    expect(find.byType(DbOnlineFollowingPresetsSheet), findsNothing);
    expect(
      tester
          .widgetList<CompactFilterButton>(find.byType(CompactFilterButton))
          .map((button) => button.label),
      ['预设二', '预设一', '预设三', '', ''],
    );
    expect(tester.takeException(), isNull);
  });
}
