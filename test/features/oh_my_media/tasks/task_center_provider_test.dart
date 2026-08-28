import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('进度广播交错到达时任务保持稳定顺序', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(taskCenterProvider.notifier);

    void send(String id, {required bool running}) {
      notifier.updateFromSchedulerMessage(<String, dynamic>{
        'type': 'scheduler_status',
        'taskId': id,
        'taskName': '音频提取',
        'status': running ? 'running' : 'completed',
        'isRunning': running,
        'movieTitle': 'movie-$id',
      });
    }

    List<String> ids() =>
        container.read(taskCenterProvider).map((task) => task.id).toList();

    send('a', running: true);
    send('b', running: true);
    expect(ids(), ['b', 'a'], reason: '新任务排在前面');

    // 两个活跃任务交错收到进度广播，updatedAt 不断刷新，顺序不应互换。
    send('a', running: true);
    send('b', running: true);
    send('a', running: true);
    expect(ids(), ['b', 'a'], reason: '进度更新不得改变任务顺序');

    // a 结束后掉到非活跃区，活跃的 b 保持在顶部。
    send('a', running: false);
    final tasks = container.read(taskCenterProvider);
    expect(tasks.map((task) => task.id), ['b', 'a']);
    expect(tasks.first.isActive, isTrue);
    expect(tasks.last.isTerminal, isTrue);
  });
}
