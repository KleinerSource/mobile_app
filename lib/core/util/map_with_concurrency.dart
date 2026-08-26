import 'dart:async';

/// 有界并发的 map: 同时最多 [concurrency] 个 [task] 在跑,结果顺序与
/// [items] 一致。任一任务抛错时整体以该错误失败(已在跑的任务继续跑完,
/// 不再启动新任务),语义与 `Future.wait` 一致,只是加了并发上限。
///
/// 用于批量详情拉取这类 N+1 扇出场景,避免选中大量条目时瞬间打满服务端。
Future<List<R>> mapWithConcurrency<T, R>(
  Iterable<T> items,
  Future<R> Function(T item) task, {
  int concurrency = 6,
}) {
  final list = items.toList(growable: false);
  if (list.isEmpty) return Future.value(const []);

  var nextIndex = 0;
  var pending = list.length;
  final results = List<R?>.filled(list.length, null);
  final completer = Completer<List<R>>();
  var failed = false;

  void runNext() {
    while (!failed && nextIndex < list.length) {
      final i = nextIndex++;
      task(list[i]).then(
        (value) {
          if (failed) return;
          results[i] = value;
          pending--;
          if (pending == 0) {
            if (!completer.isCompleted) {
              completer.complete(List<R>.from(results.cast<R>()));
            }
          } else {
            runNext();
          }
        },
        onError: (Object error, StackTrace trace) {
          failed = true;
          if (!completer.isCompleted) completer.completeError(error, trace);
        },
      );
      // 每个 worker 循环只领一个任务;runNext 的递归由完成回调驱动,
      // 这里直接返回让出调度。
      return;
    }
  }

  for (var i = 0; i < concurrency && i < list.length; i++) {
    scheduleMicrotask(runNext);
  }
  return completer.future;
}
