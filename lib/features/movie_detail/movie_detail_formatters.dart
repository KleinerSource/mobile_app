/// 将续播位置格式化为固定的 HH:MM:SS，便于在影片详情播放按钮中展示。
String formatResumePosition(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = (safeSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((safeSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final remainingSeconds = (safeSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$remainingSeconds';
}
