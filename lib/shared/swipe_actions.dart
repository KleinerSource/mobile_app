import 'package:flutter/material.dart';

import '../core/platform/app_haptics.dart';

/// 页面级左滑展开协调器：持有的值是当前展开行的 cellKey，同一时刻只展开一行。
typedef SwipeActionGroup = ValueNotifier<Object?>;

/// 左滑展开后显露的单个操作。
class SwipeActionData {
  const SwipeActionData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
}

/// 列表行左滑展开操作，操作按钮贴右缘排在卡片下方。
///
/// - 跟随手指拖动，松手按速度/位移吸附展开或收起（240ms easeOutCubic）
/// - 同一 [group] 内同时只展开一行；滚动、进入多选或操作失效时由调用方置空收起
/// - 展开状态下点击卡片本体只收起，不穿透到卡片内部点击
/// - [actions] 为空或 [enabled] 为 false 时禁用滑动
/// - iOS 风格双逻辑：拖开可点磁贴执行；继续拖动时 [fullSwipeIndex] 对应的
///   默认磁贴随手指拉长铺满腾出的空间，拖过阈值后磁贴铺满整行、
///   执行默认操作并回弹收起（不提供甩动速度触发）
/// - 操作磁贴相连成一个整块，按 [actionBorderRadius] 倒角：
///   分组容器内的行传零（外层容器统一裁剪）；连排分页列表首行只圆上角、
///   末行只圆下角（与行本身的圆角一致，避免磁贴顶出行轮廓）
class SwipeActionCell extends StatefulWidget {
  const SwipeActionCell({
    super.key,
    required this.group,
    required this.cellKey,
    required this.actions,
    required this.enabled,
    required this.child,
    this.actionBorderRadius = BorderRadius.zero,
    this.fullSwipeIndex = 0,
  });

  final SwipeActionGroup group;
  final Object cellKey;
  final List<SwipeActionData> actions;
  final bool enabled;
  final Widget child;

  /// 操作整块的圆角，应与所在行的可见圆角一致。
  final BorderRadius actionBorderRadius;

  /// 滑到头拉长执行的默认操作下标（从 0 起）。
  /// 多按钮列表需按列表语义单独指定；传 null 关闭拉长直触。
  final int? fullSwipeIndex;

  @override
  State<SwipeActionCell> createState() => _SwipeActionCellState();
}

class _SwipeActionCellState extends State<SwipeActionCell>
    with TickerProviderStateMixin {
  static const _actionWidth = 78.0;

  /// 拖过完整展开后再拖多少像素触发默认操作。
  static const _fullSwipeTriggerExtent = 44.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    // 值需要超过 1.0 表达"拉长默认磁贴"的延展量。
    upperBound: double.infinity,
  );

  /// 提交阶段默认磁贴从当前宽度铺满整行的补间。
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  );

  /// 正在执行拉长直触的提交流程（填充 → 执行 → 收起）。
  bool _committing = false;

  /// 触发提交时默认磁贴已被拉长的像素，填充动画从这里继续铺满。
  double _commitExtra = 0;

  double get _openExtent => widget.actions.length * _actionWidth;

  double get _triggerExtentPx => _openExtent + _fullSwipeTriggerExtent;

  bool get _isOpen => widget.group.value == widget.cellKey;

  bool get _hasFullSwipeAction =>
      widget.fullSwipeIndex != null &&
      widget.fullSwipeIndex! < widget.actions.length;

  double get _maxDragValue =>
      _hasFullSwipeAction ? _triggerExtentPx / _openExtent : 1.0;

  @override
  void initState() {
    super.initState();
    widget.group.addListener(_handleGroupChange);
  }

  @override
  void didUpdateWidget(covariant SwipeActionCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isOpen) widget.group.value = null;
  }

  @override
  void dispose() {
    widget.group.removeListener(_handleGroupChange);
    _controller.dispose();
    _fill.dispose();
    super.dispose();
  }

  void _handleGroupChange() {
    if (!mounted) return;
    if (_isOpen) {
      _controller.animateTo(1, curve: Curves.easeOutCubic);
    } else if (_controller.value > 0) {
      _controller.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  void _setOpen(bool open) {
    if (open) {
      AppHaptics.selection();
      widget.group.value = widget.cellKey;
    } else if (widget.group.value == widget.cellKey) {
      widget.group.value = null;
    } else {
      _controller.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_committing) return;
    // 手指向左 (delta.dx < 0) 展开操作，向右收起；超过完整展开的部分
    // 由默认磁贴拉长补齐，拖过 [_fullSwipeTriggerExtent] 像素提交执行。
    final raw = (_controller.value * _openExtent) - details.delta.dx;
    if (_hasFullSwipeAction && raw >= _triggerExtentPx) {
      _commitFullSwipe();
      return;
    }
    _controller.value = (raw / _openExtent).clamp(0.0, _maxDragValue);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_committing) return;
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity.abs() > 350 ? velocity < 0 : _controller.value > 0.5;
    _setOpen(open);
  }

  /// 拉长提交：默认磁贴铺满整行后执行操作，再收回。
  void _commitFullSwipe() {
    if (!_hasFullSwipeAction || _committing) return;
    _committing = true;
    _commitExtra =
        (_controller.value - 1.0).clamp(0.0, double.infinity) * _openExtent;
    if (_isOpen) widget.group.value = null;
    AppHaptics.medium();
    _fill.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      widget.actions[widget.fullSwipeIndex!].onPressed();
      _fill.reverse();
      _controller.animateTo(0, curve: Curves.easeOutCubic).whenComplete(() {
        if (mounted) _committing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.actions.isNotEmpty;
    return GestureDetector(
      onHorizontalDragUpdate: enabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: enabled ? _handleDragEnd : null,
      onTap: enabled && _isOpen ? () => _setOpen(false) : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _fill]),
        child: widget.child,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final rowWidth = constraints.maxWidth;
              final value = _controller.value;
              final reveal = value.clamp(0.0, 1.0);
              // 超过完整展开的部分由默认磁贴 1:1 拉长补齐。
              final dragExtra = _hasFullSwipeAction
                  ? (value - 1.0).clamp(0.0, double.infinity) * _openExtent
                  : 0.0;
              // 提交阶段：从触发时的宽度继续铺满整行。
              final extra = _committing
                  ? _commitExtra +
                        _fill.value *
                            (rowWidth - _actionWidth - _commitExtra).clamp(
                              0.0,
                              double.infinity,
                            )
                  : dragExtra;
              final defaultWidth = _actionWidth + extra;
              return Stack(
                children: [
                  if (value > 0.001 || _committing)
                    Positioned.fill(
                      // 按钮贴卡片右缘随拖动滑入，收起时整体移出裁剪区——
                      // 实色滑入不透明渐变，也不受半透明卡片透色影响。
                      child: ClipRect(
                        child: IgnorePointer(
                          ignoring: !_committing && reveal < 0.99,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FractionalTranslation(
                              translation: Offset(1 - reveal, 0),
                              child:
                                  widget.actionBorderRadius == BorderRadius.zero
                                  ? _buildActionRow(defaultWidth)
                                  : ClipRRect(
                                      borderRadius: widget.actionBorderRadius,
                                      child: _buildActionRow(defaultWidth),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(-(reveal * _openExtent + extra), 0),
                    child: AbsorbPointer(absorbing: _isOpen, child: child),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionRow(double defaultWidth) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.actions.length; i++)
          _buildAction(
            i,
            i == widget.fullSwipeIndex ? defaultWidth : _actionWidth,
          ),
      ],
    );
  }

  Widget _buildAction(int index, double width) {
    final action = widget.actions[index];
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        _setOpen(false);
        action.onPressed();
      },
      child: Container(
        width: width,
        color: action.color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              action.label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
