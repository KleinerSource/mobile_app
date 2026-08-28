import 'dart:async';

import 'package:flutter/material.dart';

/// 从屏幕左侧向右滑动触发返回动作。
///
/// 组件只监听原始指针事件，不加入手势竞技场，避免边缘手势抢占首页的
/// 纵向滚动和横向轮播；页面位移在拖动过程中跟随手指，释放后按阈值回弹
/// 或完成返回。
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

class _EdgeSwipeBackState extends State<EdgeSwipeBack>
    with TickerProviderStateMixin {
  int? _pointer;
  Offset? _startPosition;
  double _dragOffset = 0;
  AnimationController? _settleController;
  int _settleGeneration = 0;

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    if (event.position.dx > widget.edgeWidth) return;
    _cancelSettle();
    _pointer = event.pointer;
    _startPosition = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final start = _startPosition;
    if (start == null) return;

    final delta = event.position - start;
    final horizontalDistance = delta.dx;
    final verticalDistance = delta.dy.abs();
    if (horizontalDistance <= 0 ||
        horizontalDistance < verticalDistance * widget.axisRatio) {
      if (_dragOffset != 0) setState(() => _dragOffset = 0);
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    final nextOffset = horizontalDistance.clamp(0.0, width);
    if (nextOffset != _dragOffset) {
      setState(() => _dragOffset = nextOffset);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final start = _startPosition;
    if (!widget.enabled || start == null) {
      _resetPointer();
      return;
    }

    final delta = event.position - start;
    final horizontalDistance = delta.dx;
    final verticalDistance = delta.dy.abs();
    final shouldTrigger =
        horizontalDistance >= widget.triggerDistance &&
        horizontalDistance >= verticalDistance * widget.axisRatio;
    _resetPointer();
    if (shouldTrigger) widget.onTriggered();
    // 最终出场由 Navigator 的页面转场负责；组件本身回到原位，避免
    // 回调未实际导航时留下屏幕外页面，也保证下一次手势仍能命中。
    unawaited(_settleTo(0));
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _resetPointer();
    unawaited(_settleTo(0));
  }

  void _resetPointer() {
    _pointer = null;
    _startPosition = null;
  }

  Future<void> _settleTo(double target) async {
    final begin = _dragOffset;
    if ((begin - target).abs() < 0.5) {
      if (target == 0 && mounted) setState(() => _dragOffset = 0);
      return;
    }

    final generation = ++_settleGeneration;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: target == 0 ? 180 : 220),
    );
    _settleController = controller;
    final animation = Tween<double>(
      begin: begin,
      end: target,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    controller.addListener(() {
      if (mounted && generation == _settleGeneration) {
        setState(() => _dragOffset = animation.value);
      }
    });
    try {
      await controller.forward();
    } on TickerCanceled {
      return;
    } finally {
      if (identical(_settleController, controller)) {
        _settleController = null;
        controller.dispose();
      }
    }
    if (mounted && generation == _settleGeneration) {
      setState(() => _dragOffset = target);
    }
  }

  void _cancelSettle() {
    _settleGeneration++;
    final controller = _settleController;
    _settleController = null;
    controller?.stop();
    controller?.dispose();
  }

  @override
  void didUpdateWidget(covariant EdgeSwipeBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _resetPointer();
      _cancelSettle();
      if (_dragOffset != 0) setState(() => _dragOffset = 0);
    }
  }

  @override
  void dispose() {
    _cancelSettle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: widget.enabled ? _handlePointerDown : null,
          onPointerMove: widget.enabled ? _handlePointerMove : null,
          onPointerUp: widget.enabled ? _handlePointerUp : null,
          onPointerCancel: widget.enabled ? _handlePointerCancel : null,
          child: widget.child,
        ),
      ),
    );
  }
}
