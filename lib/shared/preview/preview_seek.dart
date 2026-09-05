import 'dart:ui';

/// 将横版封面上的横向拖动位置转换为预览视频时间。
///
/// 返回值为空时表示播放器还没有有效时长或封面宽度不可用。
Duration? previewSeekPositionForLocalOffset({
  required Offset localPosition,
  required double width,
  required Duration duration,
}) {
  if (!width.isFinite || width <= 0 || duration <= Duration.zero) return null;
  final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
  return Duration(microseconds: (duration.inMicroseconds * fraction).round());
}
