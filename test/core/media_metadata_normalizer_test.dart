import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/sources/media/media_metadata_normalizer.dart';

void main() {
  test('日期和年份统一为有效年份', () {
    expect(normalizeMediaYear('2024-03-01'), 2024);
    expect(normalizeMediaYear(2023), 2023);
    expect(normalizeMediaYear('not-a-date'), isNull);
    expect(normalizeMediaYear(0), isNull);
  });

  test('DBO 时长字符串统一为分钟', () {
    expect(dboDurationToMinutes('01:30:00'), 90);
    expect(dboDurationToMinutes('90 分钟'), 90);
    expect(dboDurationToMinutes('2h 5m'), 125);
    expect(dboDurationToMinutes(''), isNull);
    expect(dboDurationToMinutes('unknown'), isNull);
  });

  test('MediaBrowser ticks 和 FNOS 秒数统一为分钟', () {
    expect(mediaBrowserTicksToMinutes(90 * 60 * 10000000), 90);
    expect(secondsToMediaMinutes(90), 2);
    expect(secondsToMediaMinutes(0), isNull);
  });

  test('评分统一为 0 到 10', () {
    expect(normalizeMediaRating(8.5), 8.5);
    expect(normalizeMediaRating(0), isNull);
    expect(normalizeMediaRating(-1), isNull);
    expect(stashRating100ToTen(86), 8.6);
    expect(stashRating100ToTen(0), isNull);
  });

  test('文本和标签过滤空值与重复项', () {
    expect(normalizeMediaText('  '), isNull);
    expect(normalizeMediaLabels(['动作', ' 动作 ', '', 'Drama', 'drama']), [
      '动作',
      'Drama',
    ]);
    expect(normalizeMediaLabelValue('动作, 喜剧，动作'), ['动作', '喜剧']);
  });
}
