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
  });

  final SwipeActionGroup group;
  final Object cellKey;
  final List<SwipeActionData> actions;
  final bool enabled;
  final Widget child;

  /// 操作整块的圆角，应与所在行的可见圆角一致。
  final BorderRadius actionBorderRadius;

  @override
  State<SwipeActionCell> createState() => _SwipeActionCellState();
}

class _SwipeActionCellState extends State<SwipeActionCell>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 78.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  double get _openExtent => widget.actions.length * _actionWidth;

  bool get _isOpen => widget.group.value == widget.cellKey;

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
    // 手指向左 (delta.dx < 0) 展开操作，向右收起。
    final next =
        ((_controller.value * _openExtent) - details.delta.dx) / _openExtent;
    _controller.value = next.clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity.abs() > 350 ? velocity < 0 : _controller.value > 0.5;
    _setOpen(open);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.actions.isNotEmpty;
    return GestureDetector(
      onHorizontalDragUpdate: enabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: enabled ? _handleDragEnd : null,
      onTap: enabled && _isOpen ? () => _setOpen(false) : null,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final value = _controller.value.clamp(0.0, 1.0);
          return Stack(
            children: [
              if (value > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: value < 0.99,
                    child: Opacity(
                      opacity: value,
                      child: Align(
                        alignment: Alignment.centerRight,
                        // 零圆角（分组容器内的行）直接平铺矩形磁贴，
                        // 圆角交由外层分组容器裁剪。
                        child: widget.actionBorderRadius == BorderRadius.zero
                            ? _buildActionRow()
                            : ClipRRect(
                                borderRadius: widget.actionBorderRadius,
                                child: _buildActionRow(),
                              ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(-value * _openExtent, 0),
                child: AbsorbPointer(absorbing: _isOpen, child: child),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.actions.length; i++) _buildAction(i),
      ],
    );
  }

  Widget _buildAction(int index) {
    final action = widget.actions[index];
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        _setOpen(false);
        action.onPressed();
      },
      child: Container(
        width: _actionWidth,
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
