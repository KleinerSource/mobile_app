import 'package:flutter/material.dart';

/// 从屏幕左侧向右滑动触发返回动作。
///
/// 组件只监听原始指针事件，不加入手势竞技场，避免边缘手势抢占首页的
/// 纵向滚动和横向轮播；只有在释放时满足距离和方向条件才触发动作。
class EdgeSwipeBack extends StatefulWidget {
  const EdgeSwipeBack({
    super.key,
    required this.child,
    required this.onTriggered,
    this.enabled = true,
    this.edgeWidth = 28,
    this.triggerDistance = 80,
    this.axisRatio = 1.2,
  });

  final Widget child;
  final VoidCallback onTriggered;
  final bool enabled;
  final double edgeWidth;
  final double triggerDistance;
  final double axisRatio;

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  int? _pointer;
  Offset? _startPosition;

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    if (event.position.dx > widget.edgeWidth) return;
    _pointer = event.pointer;
    _startPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final start = _startPosition;
    _reset();
    if (!widget.enabled || start == null) return;

    final delta = event.position - start;
    final horizontalDistance = delta.dx;
    final verticalDistance = delta.dy.abs();
    if (horizontalDistance < widget.triggerDistance ||
        horizontalDistance < verticalDistance * widget.axisRatio) {
      return;
    }
    widget.onTriggered();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _reset() {
    _pointer = null;
    _startPosition = null;
  }

  @override
  void didUpdateWidget(covariant EdgeSwipeBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? _handlePointerDown : null,
      onPointerUp: widget.enabled ? _handlePointerUp : null,
      onPointerCancel: widget.enabled ? _handlePointerCancel : null,
      child: widget.child,
    );
  }
}
