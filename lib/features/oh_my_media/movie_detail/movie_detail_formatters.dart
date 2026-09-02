/// 将续播位置格式化为固定的 HH:MM:SS，便于在影片详情播放按钮中展示。
String formatResumePosition(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = (safeSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((safeSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final remainingSeconds = (safeSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$remainingSeconds';
}

/// 将详情简介中常见的 HTML 和平台换行符统一为 Flutter 可渲染的换行。
String normalizeMoviePlot(String value) {
  return value
      .replaceAll(RegExp(r'<br\b[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'&lt;br\s*/?&gt;', caseSensitive: false), '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u2028', '\n')
      .replaceAll('\u2029', '\n');
}

/// 将文件字节数格式化为 B/KB/MB/GB/TB;OMM 与 Emby/Jellyfin/fnos
/// 详情页的「文件大小」行共用同一格式。
String formatFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit <= 1 ? 0 : 1)} ${units[unit]}';
}
