import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/status_pill.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_page.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'task_center_provider.dart';
import 'task_model.dart';
import 'task_name_labels.dart';

class TaskCenterPage extends ConsumerStatefulWidget {
  const TaskCenterPage({super.key});

  @override
  ConsumerState<TaskCenterPage> createState() => _TaskCenterPageState();
}

class _TaskCenterPageState extends ConsumerState<TaskCenterPage> {
  String _filter = 'all';
  final Set<String> _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final tasks = ref.watch(taskCenterProvider);
    final meta = ref.watch(taskCenterMetaProvider);
    final visible = tasks.where(_matchesFilter).toList();
    final totalCount = meta.total > 0 ? meta.total : tasks.length;
    final activeCount =
        meta.stats['running'] ?? tasks.where((task) => task.isActive).length;

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.taskCenterEyebrow,
              title: l.taskCenterTitle,
              subtitle: activeCount == 0
                  ? l.taskCenterSubtitleIdle(totalCount)
                  : l.taskCenterSubtitleActive(activeCount, totalCount),
            ),
            body: RefreshIndicator(
              onRefresh: ref.read(taskCenterProvider.notifier).refresh,
              child: ListView(
                primary: true,
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                children: [
                  _buildSummary(colors, tasks, activeCount, meta),
                  const SizedBox(height: 14),
                  _buildFilterBar(colors),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _buildEmpty(colors)
                  else
                    _buildTaskTable(colors, visible),
                  if (meta.hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: meta.loading
                            ? null
                            : ref.read(taskCenterProvider.notifier).loadMore,
                        child: Text(
                          meta.loading ? l.taskLoadingMore : l.taskLoadMore,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(TaskItem task) {
    return switch (_filter) {
      'active' => task.isActive,
      'completed' => task.isCompleted,
      'failed' => task.isFailed,
      'canceled' => task.isCanceled,
      _ => true,
    };
  }

  String _filterLabel(AppL10n l, String filter) {
    return switch (filter) {
      'active' => l.taskFilterActive,
      'completed' => l.taskFilterCompleted,
      'failed' => l.taskFilterFailed,
      'canceled' => l.taskFilterCanceled,
      _ => l.taskFilterAll,
    };
  }

  Widget _buildSummary(
    AppColors colors,
    List<TaskItem> tasks,
    int activeCount,
    TaskCenterMeta meta,
  ) {
    final l = AppL10n.of(context);
    final stats = meta.stats;
    final failedCount =
        stats['failed'] ?? tasks.where((task) => task.isFailed).length;
    final completedCount =
        stats['completed'] ?? tasks.where((task) => task.isCompleted).length;
    final canceledCount =
        stats['canceled'] ?? tasks.where((task) => task.isCanceled).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: settingsCardDecoration(context),
      child: Row(
        children: [
          _SummaryValue(
            label: l.taskFilterAll,
            value: (meta.total > 0 ? meta.total : tasks.length).toString(),
          ),
          _SummaryDivider(color: colors.divider),
          _SummaryValue(
            label: l.taskFilterActive,
            value: activeCount.toString(),
          ),
          _SummaryDivider(color: colors.divider),
          _SummaryValue(
            label: l.taskFilterFailed,
            value: failedCount.toString(),
          ),
          _SummaryDivider(color: colors.divider),
          _SummaryValue(
            label: l.taskFilterCompleted,
            value: completedCount.toString(),
          ),
          _SummaryDivider(color: colors.divider),
          _SummaryValue(
            label: l.taskFilterCanceled,
            value: canceledCount.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppColors colors) {
    final l = AppL10n.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in const [
            'all',
            'active',
            'completed',
            'failed',
            'canceled',
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_filterLabel(l, entry)),
                selected: _filter == entry,
                onSelected: (_) => setState(() => _filter = entry),
                labelStyle: TextStyle(
                  color: _filter == entry ? colors.tabActiveText : colors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                selectedColor: colors.tabActiveBg,
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.cardBorder),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskTable(AppColors colors, List<TaskItem> tasks) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: colors.divider),
            _buildTaskRow(tasks[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskRow(TaskItem task) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final percent = task.progress.clampedPercent / 100;
    final progressValue = task.progress.total <= 0 && task.isActive
        ? null
        : percent.clamp(0.0, 1.0);
    final busy = _busy.contains(task.key);
    final canOpenDetail = _canOpenMovieDetail(task);
    final title = task.movieTitle.isNotEmpty
        ? task.movieTitle
        : task.libraryName.isNotEmpty
        ? task.libraryName
        : task.movieFileName.isNotEmpty
        ? task.movieFileName
        : task.fileName;

    return _TaskSwipeCard(
      key: ValueKey(task.key),
      actions: _taskActions(task, colors, busy),
      onTap: canOpenDetail ? () => _openMovieDetail(task) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_taskIcon(task), size: 21, color: _taskColor(task)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taskNameLabel(l, task.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: StatusPill(status: task.status),
                  ),
                ),
                if (canOpenDetail) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.muted,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: colors.divider,
                    color: _taskColor(task),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '${task.progress.clampedPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              task.message.isEmpty
                  ? l.taskMsgWaitingUpdate
                  : taskMessageLabel(l, task.message),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.muted,
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canOpenMovieDetail(TaskItem task) {
    return (task.name == '字幕转译' && task.isCompleted || task.name == '预览生成') &&
        task.movieId > 0;
  }

  Future<void> _openMovieDetail(TaskItem task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: task.movieId)),
    );
    if (mounted) {
      await ref.read(taskCenterProvider.notifier).refresh();
    }
  }

  List<_TaskAction> _taskActions(TaskItem task, AppColors colors, bool busy) {
    final l = AppL10n.of(context);
    return [
      if (task.canRetry)
        _TaskAction(
          label: l.taskActionRetry,
          icon: Icons.refresh_rounded,
          color: colors.accent,
          onPressed: busy ? null : () => _runTaskAction(task, false),
        ),
      if (task.canCancel)
        _TaskAction(
          label: busy ? l.taskActionBusy : l.cancel,
          icon: Icons.stop_circle_outlined,
          color: colors.warning,
          onPressed: busy ? null : () => _runTaskAction(task, true),
        ),
      if (task.isTerminal)
        _TaskAction(
          label: l.delete,
          icon: Icons.delete_outline_rounded,
          color: colors.danger,
          onPressed: busy ? null : () => _deleteTask(task),
        ),
    ];
  }

  Future<void> _deleteTask(TaskItem task) async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.delete),
        content: Text(l.taskRecordDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(taskCenterProvider.notifier);
    try {
      await notifier.remove(task);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.taskRecordRemoved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
    }
  }

  String _emptyTitle(AppL10n l) {
    return switch (_filter) {
      'active' => l.taskEmptyActive,
      'completed' => l.taskEmptyCompleted,
      'failed' => l.taskEmptyFailed,
      'canceled' => l.taskEmptyCanceled,
      _ => l.taskEmptyAll,
    };
  }

  Widget _buildEmpty(AppColors colors) {
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 48),
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 38, color: colors.muted),
          const SizedBox(height: 12),
          Text(
            _emptyTitle(l),
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l.taskEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Future<void> _runTaskAction(TaskItem task, bool cancel) async {
    if (!_busy.add(task.key)) return;
    setState(() {});
    try {
      final notifier = ref.read(taskCenterProvider.notifier);
      if (cancel) {
        await notifier.cancel(task);
      } else {
        await notifier.retry(task);
      }
      if (mounted) {
        final l = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cancel ? l.taskCancelSubmitted : l.taskMsgRequeued),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message.toString()
            : toApiException(error).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(taskErrorLabel(AppL10n.of(context), message))),
        );
      }
    } finally {
      _busy.remove(task.key);
      if (mounted) setState(() {});
    }
  }
}

class _TaskAction {
  const _TaskAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
}

class _TaskSwipeCard extends StatefulWidget {
  const _TaskSwipeCard({
    super.key,
    required this.child,
    required this.actions,
    this.onTap,
  });

  final Widget child;
  final List<_TaskAction> actions;
  final VoidCallback? onTap;

  @override
  State<_TaskSwipeCard> createState() => _TaskSwipeCardState();
}

class _TaskSwipeCardState extends State<_TaskSwipeCard>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 76.0;
  static const _snapVelocity = 180.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double get _actionExtent => widget.actions.length * _actionWidth;

  @override
  void didUpdateWidget(covariant _TaskSwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actions.length != oldWidget.actions.length &&
        widget.actions.isEmpty) {
      _close();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_actionExtent <= 0) return;
    final delta = details.primaryDelta ?? 0;
    final next = ((_controller.value * _actionExtent) - delta) / _actionExtent;
    _controller.value = next.clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final target = velocity < -_snapVelocity
        ? 1.0
        : velocity > _snapVelocity
        ? 0.0
        : (_controller.value >= 0.45 ? 1.0 : 0.0);
    _animateTo(target);
  }

  void _animateTo(double target) {
    _controller.animateTo(target, curve: Curves.easeOutCubic);
  }

  void _close() => _animateTo(0);

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) {
      if (widget.onTap == null) return widget.child;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // 卡片背景是半透明玻璃，按钮层不能常驻垫在卡片下方，否则会透过
          // 卡片与正文重叠；让按钮随卡片位移从右缘滑入，收起时完全移出
          // ClipRRect 裁剪区。
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.translate(
                offset: Offset(_actionExtent * (1 - _controller.value), 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final action in widget.actions)
                      _TaskSwipeActionButton(
                        action: action,
                        width: _actionWidth,
                        onTap: () {
                          _close();
                          action.onPressed?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_controller.value > 0.01) {
                  _close();
                  return;
                }
                widget.onTap?.call();
              },
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: widget.child,
            ),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-_actionExtent * _controller.value, 0),
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TaskSwipeActionButton extends StatelessWidget {
  const _TaskSwipeActionButton({
    required this.action,
    required this.width,
    required this.onTap,
  });

  final _TaskAction action;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null;
    final color = action.color.withValues(alpha: enabled ? 1 : 0.4);
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      child: SizedBox(
        width: width,
        child: Material(
          color: color,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: Colors.white, size: 19),
                  const SizedBox(height: 4),
                  Text(
                    action.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _taskIcon(TaskItem task) {
  if (task.name == 'NFO 同步') return Icons.description_outlined;
  if (task.name == '字幕转译') return Icons.cloud_sync_outlined;
  if (task.name == '音频提取') return Icons.audiotrack_outlined;
  if (task.name == '资源扫描') return Icons.manage_search_outlined;
  if (task.name == '演员关联同步') return Icons.people_outline;
  if (task.name.contains('扫描')) return Icons.folder_open_outlined;
  if (task.name == '预览生成') return Icons.video_settings_outlined;
  if (task.name.contains('预览图')) return Icons.image_outlined;
  return Icons.construction_outlined;
}

Color _taskColor(TaskItem task) {
  if (task.name == '字幕转译') return AppHues.top(AppHues.sky);
  if (task.name == '音频提取') return AppHues.top(AppHues.lavender);
  if (task.name == 'NFO 同步') return AppHues.top(AppHues.solar);
  return AppHues.top(AppHues.mint);
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Inter',
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: colors.muted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: color);
  }
}
