import 'dart:math' as math;

/// 公共媒体时长的输入单位。
enum MediaDurationUnit { minutes, seconds, milliseconds, ticks }

/// 将协议层文本归一化为空值或去除首尾空白后的文本。
String? normalizeMediaText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// 从日期、年份数字或可解析的日期文本中提取年份。
int? normalizeMediaYear(Object? value) {
  if (value is DateTime) return _validYear(value.year);
  final text = normalizeMediaText(value);
  if (text == null) return null;

  final numeric = int.tryParse(text);
  if (numeric != null) return _validYear(numeric);
  final date = DateTime.tryParse(text);
  return date == null ? null : _validYear(date.year);
}

/// 将数值或常见协议时长文本统一为分钟。
///
/// 没有有效正数时返回 null。带秒的小数时长向上取整，避免短视频被
/// 展示成 0 分钟；公共模型仍只保留分钟，精确值由来源 DTO 保存。
int? normalizeMediaDurationMinutes(
  Object? value, {
  MediaDurationUnit unit = MediaDurationUnit.minutes,
}) {
  if (value == null) return null;
  if (value is num) return _toMinutes(value.toDouble(), unit);

  final text = normalizeMediaText(value);
  if (text == null) return null;
  final compact = text.toLowerCase().replaceAll(',', '').trim();

  final clock = RegExp(
    r'^(\d+):(\d{1,2})(?::(\d{1,2})(?:\.(\d+))?)?$',
  ).firstMatch(compact);
  if (clock != null) {
    final first = double.parse(clock.group(1)!);
    final second = double.parse(clock.group(2)!);
    final third = double.tryParse(clock.group(3) ?? '0') ?? 0;
    final seconds = clock.group(3) == null && first > 23
        ? first * 60 + second
        : first * 3600 + second * 60 + third;
    return _toMinutes(seconds, MediaDurationUnit.seconds);
  }

  final hours = _numberWithUnit(compact, r'(?:h|hr|hrs|hour|hours|小时)');
  final minutes = _numberWithUnit(compact, r'(?:m|min|mins|minute|minutes|分钟)');
  final seconds = _numberWithUnit(compact, r'(?:s|sec|secs|second|seconds|秒)');
  if (hours != null || minutes != null || seconds != null) {
    return _toMinutes(
      (hours ?? 0) * 3600 + (minutes ?? 0) * 60 + (seconds ?? 0),
      MediaDurationUnit.seconds,
    );
  }

  final numeric = double.tryParse(compact);
  return numeric == null ? null : _toMinutes(numeric, unit);
}

/// DBO 常见的字符串时长到分钟转换。
int? dboDurationToMinutes(String? value) =>
    normalizeMediaDurationMinutes(value);

/// MediaBrowser 的 100 纳秒 ticks 到分钟转换。
int? mediaBrowserTicksToMinutes(int? ticks) =>
    normalizeMediaDurationMinutes(ticks, unit: MediaDurationUnit.ticks);

/// FNOS 秒数到分钟转换。
int? secondsToMediaMinutes(num? seconds) =>
    normalizeMediaDurationMinutes(seconds, unit: MediaDurationUnit.seconds);

/// 将 Stash 的 0–100 评分统一为 0–10。
double? stashRating100ToTen(Object? value) =>
    normalizeMediaRating(value, scale: 10);

/// 将评分限制到公共的 0–10 区间；缺失、非数值或非正数返回 null。
double? normalizeMediaRating(Object? value, {double scale = 1}) {
  final raw = value is num
      ? value.toDouble()
      : double.tryParse(normalizeMediaText(value) ?? '');
  if (raw == null || !raw.isFinite || !scale.isFinite || scale <= 0) {
    return null;
  }
  final rating = raw / scale;
  if (!rating.isFinite || rating <= 0) return null;
  return math.min(10, rating);
}

/// 清理空文本并按名称去重；去重忽略大小写但保留第一次出现的文本。
List<String> normalizeMediaLabels(Iterable<Object?> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final text = normalizeMediaText(value);
    if (text == null || !seen.add(text.toLowerCase())) continue;
    result.add(text);
  }
  return result;
}

/// 归一化字符串、列表或逗号分隔的标签字段。
List<String> normalizeMediaLabelValue(Object? value) {
  if (value is Iterable) return normalizeMediaLabels(value);
  final text = normalizeMediaText(value);
  if (text == null) return const <String>[];
  return normalizeMediaLabels(text.split(RegExp(r'[,，、]')));
}

int? _validYear(int value) => value >= 1800 && value <= 3000 ? value : null;

double? _numberWithUnit(String text, String unitPattern) {
  final match = RegExp(r'(\d+(?:\.\d+)?)\s*' + unitPattern).firstMatch(text);
  return match == null ? null : double.tryParse(match.group(1)!);
}

int? _toMinutes(double value, MediaDurationUnit unit) {
  if (!value.isFinite || value <= 0) return null;
  final minutes = switch (unit) {
    MediaDurationUnit.minutes => value,
    MediaDurationUnit.seconds => value / 60,
    MediaDurationUnit.milliseconds => value / 60000,
    MediaDurationUnit.ticks => value / 600000000,
  };
  if (!minutes.isFinite || minutes <= 0) return null;
  return math.max(1, minutes.ceil());
}
