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
