import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/library.dart';
import 'libraries_providers.dart';

/// 一个正在跟踪的扫描任务 · 跨页面共享
@immutable
class TrackedScan {
  const TrackedScan({
    required this.libraryId,
    required this.libraryName,
    required this.taskId,
    this.task,
  });

  /// 后端 task_id, 可能为空 (启动后立即注册 + active scans 解析)
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

class ScanTasksNotifier extends StateNotifier<List<TrackedScan>> {
  ScanTasksNotifier(this._ref) : super(const []) {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _pollAll());
  }

  final Ref _ref;
  Timer? _timer;

  /// 启动扫描后注册;  taskId 可能为空, 由轮询从 active scans 解析
  void register({
    required int libraryId,
    required String libraryName,
    required String taskId,
  }) {
    // 同一个 lib 只保留一个任务
    final filtered = state.where((s) => s.libraryId != libraryId).toList();
    state = [
      ...filtered,
      TrackedScan(
        libraryId: libraryId,
        libraryName: libraryName,
        taskId: taskId,
      ),
    ];
    // 立即拉一次, 让 UI 快点出现进度
    _pollAll();
  }

  void remove(int libraryId) {
    state = state.where((s) => s.libraryId != libraryId).toList();
  }

  Future<void> _pollAll() async {
    if (state.isEmpty) return;
    final repo = _ref.read(librariesRepositoryProvider);
    final next = <TrackedScan>[];
    for (final s in state) {
      try {
        var taskId = s.taskId;
        if (taskId.isEmpty) {
          final active = await repo.activeScans(s.libraryId);
          if (active.isEmpty) {
            // 还没起来, 保留等下次
            next.add(s);
            continue;
          }
          taskId = active.first.taskId;
          next.add(s.copyWith(taskId: taskId, task: active.first));
          continue;
        }
        final t = await repo.scanProgress(s.libraryId, taskId);
        if (t.isActive) {
          next.add(s.copyWith(task: t));
        }
        // 已完成 / 取消 / 失败: 移除 (任何状态都不再保留)
      } catch (_) {
        // 短暂错误: 保留一次, 下次再试
        next.add(s);
      }
    }
    if (mounted) state = next;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final scanTasksProvider =
    StateNotifierProvider<ScanTasksNotifier, List<TrackedScan>>(
  (ref) => ScanTasksNotifier(ref),
);
