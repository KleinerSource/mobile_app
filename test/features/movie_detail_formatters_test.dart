import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/movie_detail/movie_detail_formatters.dart';

void main() {
  test('续播位置始终使用 HH:MM:SS 格式', () {
    expect(formatResumePosition(0), '00:00:00');
    expect(formatResumePosition(65), '00:01:05');
    expect(formatResumePosition(1 * 3600 + 23 * 60 + 22), '01:23:22');
  });

  test('负数续播位置按零处理', () {
    expect(formatResumePosition(-1), '00:00:00');
  });

  test('简介换行统一支持 HTML 和平台换行符', () {
    expect(
      normalizeMoviePlot('第一行\r\n第二行\r第三行\n第四行<br>第五行<br/>第六行<br />第七行'),
      '第一行\n第二行\n第三行\n第四行\n第五行\n第六行\n第七行',
    );
    expect(normalizeMoviePlot('上&lt;br&gt;下'), '上\n下');
    expect(normalizeMoviePlot('上\u2028下\u2029末'), '上\n下\n末');
  });
}
