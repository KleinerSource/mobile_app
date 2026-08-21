import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'task_center_provider.dart';
import 'task_model.dart';

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
    final tasks = ref.watch(taskCenterProvider);
    final visible = tasks.where(_matchesFilter).toList();
    final activeCount = tasks.where((task) => task.isActive).length;
    final groups = <String, List<TaskItem>>{};
    for (final task in visible) {
      groups.putIfAbsent(task.name, () => <TaskItem>[]).add(task);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: '后台任务',
              title: '任务中心',
              subtitle: activeCount == 0
                  ? '暂无进行中的任务 · 共 ${tasks.length} 条记录'
                  : '$activeCount 条任务正在执行 · 共 ${tasks.length} 条记录',
            ),
            body: RefreshIndicator(
              onRefresh: ref.read(taskCenterProvider.notifier).refresh,
              child: ListView(
                primary: true,
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                children: [
                  _buildSummary(colors, tasks, activeCount),
                  const SizedBox(height: 14),
                  _buildFilterBar(colors),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _buildEmpty(colors)
                  else
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                        child: Text(
                          '${entry.key}  ·  ${entry.value.length}',
                          style: TextStyle(
                            color: colors.muted,
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      for (final task in entry.value) _buildTaskCard(task),
                    ],
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

  Widget _buildSummary(
    AppColors colors,
    List<TaskItem> tasks,
    int activeCount,
  ) {
    final failedCount = tasks
        .where((task) => const {'failed', 'error'}.contains(task.status))
        .length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: settingsCardDecoration(context),
      child: Row(
        children: [
          _SummaryValue(label: '全部', value: tasks.length.toString()),
          _SummaryDivider(color: colors.divider),
          _SummaryValue(label: '进行中', value: activeCount.toString()),
          _SummaryDivider(color: colors.divider),
          _SummaryValue(label: '失败', value: failedCount.toString()),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in const [
            ('all', '全部'),
            ('active', '进行中'),
            ('completed', '已完成'),
            ('failed', '失败'),
            ('canceled', '已取消'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.$2),
                selected: _filter == entry.$1,
                onSelected: (_) => setState(() => _filter = entry.$1),
                labelStyle: TextStyle(
                  color: _filter == entry.$1
                      ? colors.tabActiveText
                      : colors.muted,
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

  Widget _buildTaskCard(TaskItem task) {
    final colors = appColors(context);
    final percent = task.progress.clampedPercent / 100;
    final progressValue = task.progress.total <= 0 && task.isActive
        ? null
        : percent.clamp(0.0, 1.0);
    final busy = _busy.contains(task.key);
    final title = task.movieTitle.isNotEmpty
        ? task.movieTitle
        : task.libraryName.isNotEmpty
        ? task.libraryName
        : task.movieFileName.isNotEmpty
        ? task.movieFileName
        : task.fileName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _TaskSwipeCard(
        key: ValueKey(task.key),
        actions: _taskActions(task, colors, busy),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: settingsCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _taskColor(task).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _taskIcon(task),
                      size: 19,
                      color: _taskColor(task),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.name,
                                style: TextStyle(
                                  color: colors.text,
                                  fontFamily: 'Inter',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StatusPill(status: task.status),
                          ],
                        ),
                        if (title.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progressValue,
                minHeight: 5,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: colors.divider,
                color: _taskColor(task),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.message.isEmpty ? '等待状态更新' : task.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  List<_TaskAction> _taskActions(TaskItem task, AppColors colors, bool busy) {
    return [
      if (task.canRetry)
        _TaskAction(
          label: '重试',
          icon: Icons.refresh_rounded,
          color: colors.accent,
          onPressed: busy ? null : () => _runTaskAction(task, false),
        ),
      if (task.canCancel)
        _TaskAction(
          label: busy ? '处理中' : '取消',
          icon: Icons.stop_circle_outlined,
          color: colors.warning,
          onPressed: busy ? null : () => _runTaskAction(task, true),
        ),
      if (task.isTerminal)
        _TaskAction(
          label: '删除',
          icon: Icons.delete_outline_rounded,
          color: colors.danger,
          onPressed: busy ? null : () => _deleteTask(task),
        ),
    ];
  }

  void _deleteTask(TaskItem task) {
    final notifier = ref.read(taskCenterProvider.notifier);
    notifier.remove(task);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('任务记录已删除'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => notifier.restore(task),
          ),
        ),
      );
  }

  String _emptyTitle() {
    return switch (_filter) {
      'active' => '当前没有进行中的任务',
      'completed' => '当前没有已完成的任务',
      'failed' => '当前没有失败的任务',
      'canceled' => '当前没有已取消的任务',
      _ => '暂无任务记录',
    };
  }

  Widget _buildEmpty(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 48),
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 38, color: colors.muted),
          const SizedBox(height: 12),
          Text(
            _emptyTitle(),
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'NFO、云端转译、音频提取和扫库任务会显示在这里',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cancel ? '任务取消请求已提交' : '任务已重新排队')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message.toString()
            : toApiException(error).message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
  const _TaskSwipeCard({super.key, required this.child, required this.actions});

  final Widget child;
  final List<_TaskAction> actions;

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
    if (widget.actions.isEmpty) return widget.child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
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
          AnimatedBuilder(
            animation: _controller,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_controller.value > 0.01) _close();
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
  if (task.name.contains('预览图')) return Icons.image_outlined;
  return Icons.construction_outlined;
}

Color _taskColor(TaskItem task) {
  if (task.name == '字幕转译') return AppHues.top(AppHues.sky);
  if (task.name == '音频提取') return AppHues.top(AppHues.lavender);
  if (task.name == 'NFO 同步') return AppHues.top(AppHues.solar);
  return AppHues.top(AppHues.mint);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final (label, color) = switch (status) {
      'idle' => ('准备中', colors.muted),
      'pending' || 'queued' => ('排队中', colors.warning),
      'running' => ('进行中', colors.accent),
      'paused' => ('已暂停', colors.warning),
      'completed' => ('已完成', AppHues.top(AppHues.mint)),
      'skipped' => ('已跳过', colors.muted),
      'cancelled' || 'canceled' => ('已取消', colors.muted),
      'failed' || 'error' => ('失败', colors.danger),
      _ => (status.isEmpty ? '未知' : status, colors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
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
