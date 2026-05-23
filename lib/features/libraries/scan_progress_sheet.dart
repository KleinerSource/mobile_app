import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/library.dart';
import '../../core/platform/app_theme.dart';
import 'libraries_providers.dart';

/// 扫描进度 sheet · 启动扫描后弹出,轮询任务进度,可暂停/恢复/取消
class ScanProgressSheet extends ConsumerStatefulWidget {
  const ScanProgressSheet({
    super.key,
    required this.libraryId,
    required this.libraryName,
    required this.taskId,
  });

  final int libraryId;
  final String libraryName;
  final String taskId;

  static Future<void> show(
    BuildContext context, {
    required int libraryId,
    required String libraryName,
    required String taskId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors(context).bg,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (_) => ScanProgressSheet(
        libraryId: libraryId,
        libraryName: libraryName,
        taskId: taskId,
      ),
    );
  }

  @override
  ConsumerState<ScanProgressSheet> createState() => _ScanProgressSheetState();
}

class _ScanProgressSheetState extends ConsumerState<ScanProgressSheet> {
  Timer? _timer;
  ScanTask? _task;
  String? _error;
  bool _busy = false;
  String? _resolvedTaskId; // 后端首次 scan 返回 null 时, 从 activeScans 解析

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _effectiveTaskId => _resolvedTaskId ?? widget.taskId;

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final repo = ref.read(librariesRepositoryProvider);
      // 任务 id 未知时, 从 active scans 找
      if (_effectiveTaskId.isEmpty) {
        final active = await repo.activeScans(widget.libraryId);
        if (active.isNotEmpty) {
          _resolvedTaskId = active.first.taskId;
        } else {
          // 还没启动到, 下次再试
          return;
        }
      }
      final t = await repo.scanProgress(widget.libraryId, _effectiveTaskId);
      if (!mounted) return;
      setState(() {
        _task = t;
        _error = null;
      });
      if (!t.isActive) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiException(e).message);
    }
  }

  Future<void> _act(Future<void> Function() action, {String? errPrefix}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _poll();
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = '${errPrefix ?? '操作失败'}: ${toApiException(e).message}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final t = _task;
    final isDone =
        t != null && !t.isActive && t.status != 'failed' && t.status != 'cancelled';
    final isFailed = t?.status == 'failed' || t?.status == 'cancelled';
    final ratio = t?.progressRatio ?? 0.0;
    final processed = t?.processedFiles ?? 0;
    final total = t?.totalFiles ?? 0;

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
                      Text('SCANNING', style: AppText.eyebrow(context)),
                      const SizedBox(height: 4),
                      Text(widget.libraryName, style: AppText.sectionTitle(context)),
                    ],
                  ),
                ),
                _StatusPill(status: t?.status ?? 'pending'),
              ],
            ),
            const SizedBox(height: 22),

            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio == 0 && t?.isActive == true ? null : ratio,
                minHeight: 6,
                backgroundColor: c.chipBg,
                valueColor: AlwaysStoppedAnimation(
                  isFailed ? c.danger : c.accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  total > 0 ? '$processed / $total' : '准备中...',
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (total > 0)
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

            // 统计
            if (t != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _StatCell(label: '新增', value: t.addedFiles),
                    _StatDivider(),
                    _StatCell(label: '更新', value: t.updatedFiles),
                    _StatDivider(),
                    _StatCell(label: '移除', value: t.removedFiles),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // current file
            if (t?.currentFile != null && t!.currentFile!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT', style: AppText.eyebrow(context)),
                    const SizedBox(height: 4),
                    Text(
                      t.currentFile!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text2,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
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
                      child: Text(_error!,
                          style: TextStyle(
                              color: c.danger,
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 操作按钮
            Row(
              children: [
                if (t?.isActive == true) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _act(
                                () => ref
                                    .read(librariesRepositoryProvider)
                                    .cancelScan(widget.libraryId, _effectiveTaskId),
                                errPrefix: '取消失败',
                              ),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('取消',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.danger,
                        side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              if (t!.isPaused) {
                                _act(
                                  () => ref
                                      .read(librariesRepositoryProvider)
                                      .resumeScan(widget.libraryId, _effectiveTaskId),
                                  errPrefix: '恢复失败',
                                );
                              } else {
                                _act(
                                  () => ref
                                      .read(librariesRepositoryProvider)
                                      .pauseScan(widget.libraryId, _effectiveTaskId),
                                  errPrefix: '暂停失败',
                                );
                              }
                            },
                      icon: Icon(
                          t!.isPaused
                              ? Icons.play_arrow
                              : Icons.pause,
                          size: 18),
                      label: Text(
                        t.isPaused ? '继续' : '暂停',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.text,
                        foregroundColor: c.bg,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFailed ? c.danger : c.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isDone
                            ? '完成 · 关闭'
                            : (isFailed ? '出错了 · 关闭' : '关闭'),
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
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
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: c.muted,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(width: 1, height: 22, color: c.divider);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final (text, color) = switch (status) {
      'running' => ('扫描中', c.accent),
      'paused' => ('已暂停', c.warning),
      'completed' => ('已完成', AppHues.top(AppHues.mint)),
      'failed' => ('失败', c.danger),
      'cancelled' => ('已取消', c.muted),
      _ => ('准备中', c.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
