import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/db_online/providers/db_online_scheduler_provider.dart';

import '../support/watched_test_support.dart';

void main() {
  test('裸广播解析进度/队列，重复完成消息只触发一次结束', () {
    var value = const DbOnlineSchedulerSnapshot().connection(true);
    value = value.update(
      watchedTask(running: true, task: 'other', queued: true),
    );
    expect(value.recheckQueued, isTrue);
    value = value.update(watchedTask(completed: 5));
    expect(value.rechecking, isTrue);
    expect(value.total, 12);
    expect(value.completed, 5);
    value = value.update(watchedTask(running: false, completed: 12));
    expect(value.completionRevision, 1);
    value = value.update(watchedTask(running: false, completed: 12));
    expect(value.completionRevision, 1);
  });

  test('首次收到历史完成快照不会误报当前任务完成', () {
    final value = const DbOnlineSchedulerSnapshot().update(
      watchedTask(running: false, completed: 12),
    );
    expect(value.completionRevision, 0);
  });

  test('断线重连恢复快照，关闭连接后不再重连', () async {
    final sockets = WatchedTestSockets();
    final connection = DbOnlineSchedulerConnection(
      uri: Uri.parse('wss://a.test/ws/scheduler/status'),
      connect: sockets.connect,
      reconnectDelay: const Duration(milliseconds: 5),
    );
    final events = <DbOnlineSchedulerSnapshot>[];
    final subscription = connection.stream.listen(events.add);
    addTearDown(() async {
      connection.close();
      await subscription.cancel();
    });
    connection.start();
    await Future<void>.delayed(Duration.zero);
    sockets.sockets.first.send(watchedTask(completed: 3));
    await Future<void>.delayed(Duration.zero);
    expect(events.last.completed, 3);
    await sockets.sockets.first.incoming.close();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(sockets.sockets, hasLength(2));
    sockets.sockets.last.send(watchedTask(running: false, completed: 12));
    await Future<void>.delayed(Duration.zero);
    expect(events.last.completionRevision, 1);
    expect(events.last.connectionRevision, 2);
    connection.close();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(sockets.sockets.last.closed, isTrue);
    expect(sockets.sockets, hasLength(2));
  });

  test('无效消息不影响之后的正常广播', () async {
    final sockets = WatchedTestSockets();
    final connection = DbOnlineSchedulerConnection(
      uri: Uri.parse('ws://a.test/ws/scheduler/status'),
      connect: sockets.connect,
    );
    final events = <DbOnlineSchedulerSnapshot>[];
    final subscription = connection.stream.listen(events.add);
    connection.start();
    await Future<void>.delayed(Duration.zero);
    sockets.sockets.first.incoming.add('not json');
    sockets.sockets.first.send(watchedTask(completed: 2));
    await Future<void>.delayed(Duration.zero);
    expect(events.last.completed, 2);
    connection.close();
    await subscription.cancel();
  });
}
