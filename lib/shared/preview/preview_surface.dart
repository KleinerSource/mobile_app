import 'package:flutter/material.dart';

/// 预览视频封面的公共交互层。
///
/// 两个媒体模块共用同一套点击、横向拖动、加载提示和滑动提示，
/// 外层卡片仍负责自己的封面、观看进度和媒体信息布局。
class PreviewGestureSurface extends StatelessWidget {
  const PreviewGestureSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.showHint = false,
    this.bottomOverlay,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;
  final bool showHint;
  final Widget? bottomOverlay;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final GestureDragCancelCallback? onHorizontalDragCancel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onHorizontalDragStart: enabled ? onHorizontalDragStart : null,
            onHorizontalDragUpdate: enabled ? onHorizontalDragUpdate : null,
            onHorizontalDragEnd: enabled ? onHorizontalDragEnd : null,
            onHorizontalDragCancel: enabled ? onHorizontalDragCancel : null,
            child: const SizedBox.expand(),
          ),
        ),
        if (bottomOverlay != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: bottomOverlay),
          ),
        if (loading)
          const Positioned(
            top: 14,
            right: 14,
            child: IgnorePointer(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (showHint)
          const Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(
              child: Icon(Icons.swipe_rounded, size: 20, color: Colors.white70),
            ),
          ),
      ],
    );
  }
}
