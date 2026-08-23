import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
/// - 拖动期间 1:1 直接跟手（direct manipulation）；弹簧物理（果冻手感）
///   用于松手后的展开/收起吸附、快甩飞行与提交铺满，松手速度会续接到弹簧
/// - 同一 [group] 内同时只展开一行；滚动、进入多选或操作失效时由调用方置空收起
/// - 展开状态下点击卡片本体只收起，不穿透到卡片内部点击
/// - [actions] 为空或 [enabled] 为 false 时禁用滑动
/// - iOS 原生触发语义（[fullSwipeIndex] 指定默认操作）：
///   · 慢拖：拖开按钮后继续拖，默认磁贴随手指拉长铺满腾出的空间，
///     拖过提交点（不低于按钮区+44px，也不低于行宽的 55%）立即执行
///     ——未过提交点前随时滑回即撤销；
///   · 快甩：松手左向速度足够时带惯性飞到满宽并执行（原生整行滑动）；
///   · 松手未达提交点：按位移/速度正常吸附展开或收起
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

  /// 展开/收起吸附：轻回弹的果冻感。
  static const _settleSpring = SpringDescription(
    mass: 1,
    stiffness: 340,
    damping: 26,
  );

  /// 提交铺满：更明显的果冻过冲。
  static const _fillSpring = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 16,
  );

  /// 进度：0 收起，1 完整展开，>1 为默认磁贴的拉长量（可超 1 表达弹性）。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    upperBound: double.infinity,
  );

  /// 提交阶段默认磁贴从当前宽度铺满整行的补间（弹簧驱动）。
  late final AnimationController _fill = AnimationController(
    vsync: this,
    upperBound: double.infinity,
  );

  /// 快甩触发：松手左向速度不超过该值 (px/s) 时带惯性飞到满宽并执行，
  /// 对应 iOS 原生"快速整行滑动直接执行默认操作"。
  static const _flingVelocity = -1000;

  /// 慢拖提交的保底触发距离：按钮区完全展开后再拖 44px。
  static const _fullSwipeTriggerExtent = 44.0;

  /// 慢拖提交距离占行宽的比例。整行宽度从行中部起拖物理上不可达
  /// （手指到屏幕边缘就没了），取 55% 保证大多数起拖位置都能触发；
  /// 更短的距离靠快甩触发。
  static const _commitDragFraction = 0.55;

  /// 正在执行拉长直触的提交流程（填充 → 执行 → 收起）。
  bool _committing = false;

  /// 触发提交时默认磁贴已被拉长的像素，填充动画从这里继续铺满。
  double _commitExtra = 0;

  /// 手指目标进度（按累计位移维护，独立于带弹性的视觉进度）。
  double _target = 0;

  /// 松手速度（进度/秒，进度增大为正），续接到吸附弹簧。
  double _springVelocity = 0;

  /// 行宽（build 时由 LayoutBuilder 更新），换算提交触发距离用。
  double _rowWidth = 0;

  double get _openExtent => widget.actions.length * _actionWidth;

  bool get _isOpen => widget.group.value == widget.cellKey;

  bool get _hasFullSwipeAction =>
      widget.fullSwipeIndex != null &&
      widget.fullSwipeIndex! < widget.actions.length;

  /// 可拖至整行宽度；超过按钮区的部分由默认磁贴拉长补齐。
  double get _maxDragValue =>
      _hasFullSwipeAction && _rowWidth > 0 ? _rowWidth / _openExtent : 1.0;

  /// 慢拖提交触发距离（px）：不低于保底距离，也不低于行宽的 55%。
  double get _commitDragPx {
    final floor = _openExtent + _fullSwipeTriggerExtent;
    final fractional = _rowWidth * _commitDragFraction;
    return fractional > floor ? fractional : floor;
  }

  /// 拖拽距离是否已过提交点（磁贴拉长越点即触发，iOS 原生语义）。
  bool get _reachedFullSwipe =>
      _hasFullSwipeAction &&
      _rowWidth > 0 &&
      _target * _openExtent >= _commitDragPx;

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

  void _springTo(
    double target, {
    SpringDescription spring = _settleSpring,
    double velocity = 0,
  }) {
    _controller.animateWith(
      SpringSimulation(spring, _controller.value, target, velocity),
    );
  }

  void _handleGroupChange() {
    if (!mounted || _committing) return;
    final target = _isOpen ? 1.0 : 0.0;
    if (_isOpen || _controller.value > 0) {
      _springTo(target, velocity: _springVelocity);
    }
    _springVelocity = 0;
  }

  void _setOpen(bool open) {
    if (open) {
      AppHaptics.selection();
    }
    // 行已是展开状态时再赋同一个 key，ValueNotifier 不会通知监听器，
    // 吸附弹簧将无人启动——需直接吸附，否则卡在松手位置不回弹。
    if (open && widget.group.value == widget.cellKey) {
      _springTo(1.0, velocity: _springVelocity);
      _springVelocity = 0;
      return;
    }
    if (open) {
      widget.group.value = widget.cellKey; // 监听器内吸附到 1
    } else if (widget.group.value == widget.cellKey) {
      widget.group.value = null; // 监听器内吸附到 0
    } else {
      _springTo(0, velocity: _springVelocity);
      _springVelocity = 0;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (_committing) return;
    // 从当前状态续滑：已展开的行也能继续左滑拉长提交。
    _target = _controller.value.clamp(0.0, 1.0);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_committing) return;
    // 手指向左 (delta.dx < 0) 展开操作，向右收起；超过完整展开的部分
    // 由默认磁贴拉长补齐。拖过提交点那一刻立即提交——
    // iOS 原生语义；未拖满前可随时滑回，不会执行任何操作。
    // 拖动中直接赋值 1:1 跟手（direct manipulation），
    // 弹簧只用于松手后的吸附/甩动与提交动画。
    final step = -details.delta.dx / _openExtent;
    _target = (_target + step).clamp(0.0, _maxDragValue);
    if (_reachedFullSwipe) {
      _commitFullSwipe();
      return;
    }
    _controller.value = _target;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_committing) return;
    final velocityPx = details.primaryVelocity ?? 0;
    // iOS 原生：快速整行左甩带惯性飞到满宽并执行默认操作。
    if (_hasFullSwipeAction && velocityPx <= _flingVelocity) {
      _flingFullSwipe(velocityPx);
      return;
    }
    // 像素速度（左负右正）换算为进度速度：进度增大为正，故取反。
    _springVelocity = -velocityPx / _openExtent;
    final open = velocityPx.abs() > 350
        ? velocityPx < 0
        : _controller.value > 0.5 || _target > 0.5;
    _setOpen(open);
  }

  /// 快甩提交：带松手速度飞到满宽后走提交流程。
  void _flingFullSwipe(double velocityPx) {
    if (_committing) return;
    _committing = true;
    _controller
        .animateWith(
          SpringSimulation(
            _settleSpring,
            _controller.value,
            _rowWidth / _openExtent,
            -velocityPx / _openExtent,
          ),
        )
        .whenComplete(() {
          if (!mounted) return;
          _committing = false;
          _commitFullSwipe();
        });
  }

  /// 拉长提交：默认磁贴以弹簧铺满整行后执行操作，再带弹回收起。
  void _commitFullSwipe() {
    if (!_hasFullSwipeAction || _committing) return;
    _committing = true;
    _commitExtra =
        (_controller.value - 1.0).clamp(0.0, double.infinity) * _openExtent;
    if (_isOpen) widget.group.value = null;
    AppHaptics.medium();
    _fill.animateWith(SpringSimulation(_fillSpring, 0, 1, 0)).whenComplete(() {
      if (!mounted) return;
      widget.actions[widget.fullSwipeIndex!].onPressed();
      _fill.animateWith(SpringSimulation(_settleSpring, 1, 0, 0));
      _controller
          .animateWith(SpringSimulation(_settleSpring, _controller.value, 0, 0))
          .whenComplete(() {
            if (mounted) _committing = false;
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.actions.isNotEmpty;
    return GestureDetector(
      onHorizontalDragStart: enabled ? _handleDragStart : null,
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
              _rowWidth = rowWidth;
              final value = _controller.value;
              final reveal = value.clamp(0.0, 1.0);
              // 超过完整展开的部分由默认磁贴 1:1 拉长补齐。
              final dragExtra = _hasFullSwipeAction
                  ? (value - 1.0).clamp(0.0, double.infinity) * _openExtent
                  : 0.0;
              // 提交阶段：从触发时的宽度继续铺满整行（弹簧过冲被裁剪）。
              final extra = _committing
                  ? _commitExtra +
                        _fill.value *
                            (rowWidth - _actionWidth - _commitExtra).clamp(
                              0.0,
                              double.infinity,
                            )
                  : dragExtra;
              final defaultWidth = _actionWidth + extra;
              // 卡片随手指平移；按钮块钉在固定坐标系的 `行宽 - 平移量`
              // 处——左缘恒等于卡片右缘，随卡片尾缘滑入，无定位换算。
              // Stack 默认按行边界裁剪：收起时按钮在右边界外不可见，
              // 也保证展开后按钮可正常命中（不会因越界被 hitTest 拦截）。
              // Positioned 只约束 left/top/bottom，宽度无界，Row 取自然
              // 宽度即可，拉长/弹簧过冲超出行宽也不会触发布局溢出。
              final offsetPx = reveal * _openExtent + extra;
              final actionRow = _buildActionRow(defaultWidth);
              return Stack(
                children: [
                  Transform.translate(
                    offset: Offset(-offsetPx, 0),
                    child: AbsorbPointer(absorbing: _isOpen, child: child),
                  ),
                  if (value > 0.001 || _committing)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: rowWidth - offsetPx,
                      child: IgnorePointer(
                        ignoring: !_committing && reveal < 0.99,
                        child: widget.actionBorderRadius == BorderRadius.zero
                            ? actionRow
                            : ClipRRect(
                                borderRadius: widget.actionBorderRadius,
                                child: actionRow,
                              ),
                      ),
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
