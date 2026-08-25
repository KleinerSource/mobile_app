import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/movie_detail/movie_detail_page.dart';
import 'package:omm/features/tasks/task_center_page.dart';
import 'package:omm/features/tasks/task_center_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('已完成的字幕转译卡片点击进入影片详情', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(taskCenterProvider.notifier)
        .updateFromSchedulerMessage(const <String, dynamic>{
          'type': 'scheduler_status',
          'taskId': 'tr-42',
          'taskName': '字幕转译',
          'status': 'completed',
          'isRunning': false,
          'movieId': 7,
          'movieTitle': '示例影片',
        });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TaskCenterPage()),
      ),
    );
    await tester.pump();
    expect(find.byType(MovieDetailPage), findsNothing);

    await tester.tap(find.text('字幕转译'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MovieDetailPage), findsOneWidget);

    // 卸载页面并销毁容器，取消 WebSocket 重连定时器，避免 pending timer。
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
