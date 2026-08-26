import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/library.dart';
import '../tasks/task_center_provider.dart';
import '../tasks/task_model.dart';
import 'libraries_providers.dart';

/// 一个正在跟踪的扫描任务 · 跨页面共享。
@immutable
class TrackedScan {
  const TrackedScan({
    required this.libraryId,
    required this.libraryName,
    required this.taskId,
    this.task,
  });

  final String taskId;
  final int libraryId;
  final String libraryName;
  final ScanTask? task;

  TrackedScan copyWith({String? taskId, ScanTask? task}) => TrackedScan(
    libraryId: libraryId,
    libraryName: libraryName,
    taskId: taskId ?? this.taskId,
    task: task ?? this.task,
  );

  bool get isActive => task?.isActive ?? true;
}

/// 扫描页面消费统一任务中心中的“目录扫描”子集。
///
/// 任务中心负责唯一的 WebSocket 连接，避免打开任务页和媒体库页时重复
/// 建立连接；这里仍保留原有的本地注册和 active fallback 行为。
class ScanTasksNotifier extends Notifier<List<TrackedScan>> {
  bool _disposed = false;

  @override
  List<TrackedScan> build() {
    ref.onDispose(() => _disposed = true);
    ref.listen<List<TaskItem>>(
      taskCenterProvider,
      (_, next) => _syncFromTaskCenter(next),
      fireImmediately: true,
    );
    return const [];
  }

  void register({
    required int libraryId,
    required String libraryName,
    required String taskId,
    ScanTask? task,
  }) {
    final filtered = state
        .where((item) => item.libraryId != libraryId)
        .toList();
    state = [
      ...filtered,
      TrackedScan(
        libraryId: libraryId,
        libraryName: libraryName,
        taskId: taskId,
        task: task,
      ),
    ];
    ref
        .read(taskCenterProvider.notifier)
        .registerScan(
          libraryId: libraryId,
          libraryName: libraryName,
          taskId: taskId,
          task: task,
        );
    _syncFromTaskCenter(ref.read(taskCenterProvider));
    if (task == null) _refreshOnceFallback(libraryId, libraryName);
  }

  void remove(int libraryId) {
    state = state.where((item) => item.libraryId != libraryId).toList();
  }

  Future<void> _refreshOnceFallback(int libraryId, String libraryName) async {
    try {
      final active = await ref
          .read(librariesRepositoryProvider)
          .activeScans(libraryId);
      if (active.isEmpty || _disposed) return;
      final task = active.first;
      ref
          .read(taskCenterProvider.notifier)
          .registerScan(
            libraryId: libraryId,
            libraryName: libraryName,
            taskId: task.taskId,
            task: task,
          );
      _syncFromTaskCenter(ref.read(taskCenterProvider));
    } catch (_) {}
  }

  void _syncFromTaskCenter(List<TaskItem> tasks) {
    if (_disposed || state.isEmpty) return;
    final next = <TrackedScan>[];
    for (final tracked in state) {
      TaskItem? task;
      for (final candidate in tasks) {
        if (_isLibraryScan(candidate) && _matches(candidate, tracked)) {
          task = candidate;
          break;
        }
      }
      if (task == null) {
        next.add(tracked);
        continue;
      }
      if (!task.isActive) continue;
      next.add(
        tracked.copyWith(
          taskId: task.id,
          task: _toScanTask(task, tracked.libraryId),
        ),
      );
    }
    state = next;
  }
}

bool _isLibraryScan(TaskItem task) {
  return task.name.contains('扫描') && task.name != '资源扫描';
}

bool _matches(TaskItem task, TrackedScan tracked) {
  if (task.id == tracked.taskId) return true;
  if (task.libraryIds.contains(tracked.libraryId)) return true;
  return tracked.taskId.isEmpty && task.id.startsWith('scan-placeholder-');
}

ScanTask _toScanTask(TaskItem task, int libraryId) {
  return ScanTask(
    taskId: task.id,
    libraryId: libraryId,
    status: task.status,
    totalFiles: task.progress.total,
    processedFiles: task.progress.completed,
    currentFile: task.message,
    message: task.message,
  );
}

final scanTasksProvider =
    NotifierProvider<ScanTasksNotifier, List<TrackedScan>>(
      ScanTasksNotifier.new,
    );
