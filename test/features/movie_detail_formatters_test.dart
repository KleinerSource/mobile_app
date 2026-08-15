import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/movie_detail/movie_detail_formatters.dart';

void main() {
  test('续播位置始终使用 HH:MM:SS 格式', () {
    expect(formatResumePosition(0), '00:00:00');
    expect(formatResumePosition(65), '00:01:05');
    expect(formatResumePosition(1 * 3600 + 23 * 60 + 22), '01:23:22');
  });

  test('负数续播位置按零处理', () {
    expect(formatResumePosition(-1), '00:00:00');
  });
}
