import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import 'scan_progress_sheet.dart';
import 'scan_tasks_provider.dart';

/// 常驻进度面板 · 只在有活动扫描任务时显示, 浮于底部 tab bar 之上
///
/// 显示当前第一个任务的简略进度, 点击展开完整 sheet 看详情/暂停/取消
class ScanProgressDock extends ConsumerWidget {
  const ScanProgressDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(scanTasksProvider);
    if (tasks.isEmpty) return const SizedBox.shrink();
    return _DockBody(tasks: tasks);
  }
}

class _DockBody extends StatelessWidget {
  const _DockBody({required this.tasks});
  final List<dynamic> tasks; // List<TrackedScan>

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final first = tasks.first;
    final extra = tasks.length - 1;
    final task = first.task; // 可能 null
    final ratio = (task?.progressRatio ?? 0).clamp(0.0, 1.0).toDouble();
    final processed = task?.processedFiles ?? 0;
    final total = task?.totalFiles ?? 0;
    final indeterminate = task == null || (total == 0 && (task?.isActive ?? true));

    return GestureDetector(
      onTap: () {
        ScanProgressSheet.show(
          context,
          libraryId: first.libraryId,
          libraryName: first.libraryName,
          taskId: first.taskId,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: c.tabBg,
              border: Border.all(color: c.tabBorder),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.42
                          : 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: indeterminate ? null : ratio,
                        valueColor: AlwaysStoppedAnimation(c.accent),
                        backgroundColor: c.chipBg,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '扫描 ${first.libraryName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.text,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (extra > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: c.accent.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    '+$extra',
                                    style: TextStyle(
                                      color: c.accent,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            total > 0
                                ? '$processed / $total · ${(ratio * 100).toStringAsFixed(0)}%'
                                : '准备中...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.muted,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.expand_less_rounded,
                        color: c.muted, size: 18),
                  ],
                ),
                if (!indeterminate) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      backgroundColor: c.chipBg,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
