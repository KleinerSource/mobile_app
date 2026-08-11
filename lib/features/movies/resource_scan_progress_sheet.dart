import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/resource_scan.dart';
import '../../core/platform/app_theme.dart';
import 'movies_providers.dart';

/// 资源扫描进度面板。任务没有暂停/取消接口，因此关闭面板只会停止轮询，
/// 后端任务仍会继续执行。
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors(context).bg,
      showDragHandle: true,
      builder: (_) => ResourceScanProgressSheet(
        taskId: taskId,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<ResourceScanProgressSheet> createState() =>
      _ResourceScanProgressSheetState();
}

class _ResourceScanProgressSheetState
    extends ConsumerState<ResourceScanProgressSheet> {
  Timer? _timer;
  ResourceScanTask? _task;
  String? _error;
  bool _notifiedCompleted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final task = await ref
          .read(moviesRepositoryProvider)
          .resourceScanProgress(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _error = null;
      });
      if (!task.isActive) {
        _timer?.cancel();
        if (!_notifiedCompleted) {
          _notifiedCompleted = true;
          widget.onCompleted?.call();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiException(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final task = _task;
    final active = task?.isActive ?? true;
    final failed = task?.status == 'error';
    final ratio = task?.progressRatio ?? 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RESOURCE SCAN', style: AppText.eyebrow(context)),
                      const SizedBox(height: 4),
                      Text('扫描资源', style: AppText.sectionTitle(context)),
                    ],
                  ),
                ),
                _ResourceScanStatusPill(status: task?.status ?? 'pending'),
              ],
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
                      ? '正在连接...'
                      : '${task.currentIndex} / ${task.totalCount}',
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (task != null)
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: c.muted,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (task != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _ResourceScanStat(label: '成功', value: task.successCount),
                    _ResourceScanDivider(),
                    _ResourceScanStat(label: '失败', value: task.failedCount),
                    _ResourceScanDivider(),
                    _ResourceScanStat(label: '新资源', value: task.newMovieCount),
                  ],
                ),
              ),
            if (task?.currentMovie.trim().isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  task!.currentMovie,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text2,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.1),
                  border: Border.all(color: c.danger.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: c.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: c.danger,
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (task != null && task.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                task.errors.take(3).join('\n'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(active ? Icons.arrow_downward_rounded : Icons.check),
                label: Text(active ? '后台运行' : (failed ? '关闭' : '完成')),
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

class _ResourceScanStat extends StatelessWidget {
  const _ResourceScanStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: c.muted,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceScanDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: appColors(context).divider);
  }
}

class _ResourceScanStatusPill extends StatelessWidget {
  const _ResourceScanStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final (label, color) = switch (status) {
      'running' => ('扫描中', c.accent),
      'completed' => ('已完成', c.accent),
      'error' => ('失败', c.danger),
      _ => ('准备中', c.muted),
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
