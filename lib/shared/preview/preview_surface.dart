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
    this.showAvailabilityBadge = false,
    this.availabilityLabel = '',
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
  final bool showAvailabilityBadge;
  final String availabilityLabel;
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
        if (showAvailabilityBadge)
          Positioned(
            top: 10,
            right: 10,
            child: PreviewAvailabilityBadge(label: availabilityLabel),
          ),
        if (loading)
          Positioned(
            top: 14,
            right: showAvailabilityBadge ? 34 : 14,
            child: const IgnorePointer(
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
            right: 48,
            child: IgnorePointer(
              child: Icon(Icons.swipe_rounded, size: 20, color: Colors.white70),
            ),
          ),
      ],
    );
  }
}

/// 表示封面存在可播放预览视频的轻量标识，视觉上接近 Live Photo 图标。
class PreviewAvailabilityBadge extends StatelessWidget {
  const PreviewAvailabilityBadge({super.key, this.label = ''});

  final String label;

  @override
  Widget build(BuildContext context) {
    final badge = const Icon(
      Icons.motion_photos_on_rounded,
      size: 16,
      color: Colors.white,
      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
    );
    final labeledBadge = label.trim().isEmpty
        ? badge
        : Tooltip(message: label, child: badge);
    return Semantics(
      label: label.trim().isEmpty ? null : label,
      image: true,
      child: IgnorePointer(child: labeledBadge),
    );
  }
}
