import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/oh_my_media/tasks/task_center_provider.dart';
import 'package:omm/features/oh_my_media/tasks/task_model.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';

/// 资源扫描进度面板。状态直接来自统一任务中心的 HTTP 快照和 WS 更新。
class ResourceScanProgressSheet extends ConsumerStatefulWidget {
  const ResourceScanProgressSheet({
    super.key,
    required this.taskId,
    this.onCompleted,
  });

  final String taskId;
  final VoidCallback? onCompleted;

  static Future<void> show(
    BuildContext context, {
    required String taskId,
    VoidCallback? onCompleted,
  }) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ResourceScanProgressSheet(taskId: taskId, onCompleted: onCompleted),
    );
  }

  @override
  ConsumerState<ResourceScanProgressSheet> createState() =>
      _ResourceScanProgressSheetState();
}

class _ResourceScanProgressSheetState
    extends ConsumerState<ResourceScanProgressSheet> {
  bool _notifiedCompleted = false;

  TaskItem? _findTask(List<TaskItem> tasks) {
    for (final task in tasks) {
      if (task.id == widget.taskId && task.taskType == 'resource_scan') {
        return task;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final task = _findTask(ref.watch(taskCenterProvider));
    final active = task?.isActive ?? true;
    final failed = task?.status == 'failed';
    final ratio = (task?.progress.clampedPercent ?? 0) / 100;
    if (task != null && task.isTerminal && !_notifiedCompleted) {
      _notifiedCompleted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted?.call();
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              icon: Icons.manage_search_outlined,
              title: l.resourceScanTitle,
              subtitle: l.resourceScanProgress,
              trailing: _ResourceScanStatusPill(
                status: task?.status ?? 'queued',
              ),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: active && task == null ? null : ratio,
                minHeight: 6,
                backgroundColor: c.chipBg,
                valueColor: AlwaysStoppedAnimation(
                  failed ? c.danger : c.accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task == null
                      ? l.resourceScanConnecting
                      : '${task.progress.completed} / ${task.progress.total}',
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (task != null)
                  Text(
                    '${task.progress.clampedPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            if (task != null && task.message.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: failed ? c.danger.withValues(alpha: 0.1) : c.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  task.message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: failed ? c.danger : c.text2,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(active ? Icons.arrow_downward_rounded : Icons.check),
                label: Text(
                  active
                      ? l.resourceScanBackground
                      : (failed ? l.resourceScanClose : l.resourceScanDone),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: failed ? c.danger : c.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceScanStatusPill extends StatelessWidget {
  const _ResourceScanStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final (label, color) = switch (status) {
      'running' => (l.resourceScanRunning, c.accent),
      'completed' => (l.resourceScanCompleted, c.accent),
      'failed' => (l.resourceScanFailed, c.danger),
      'canceling' => (l.resourceScanCanceling, c.warning),
      'canceled' => (l.audioStatusCanceled, c.muted),
      _ => (l.resourceScanPreparing, c.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
