import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/movies/movies_providers.dart';

void main() {
  test('封面缓存版本为零时保留原始地址', () {
    const url = 'https://example.com/api/images/poster-1?token=abc';

    expect(imageUrlWithCacheRevision(url, 0), url);
  });

  test('刷新封面时追加新的缓存键并保留已有查询参数', () {
    const url = 'https://example.com/api/images/poster-1?token=abc';

    final refreshed = Uri.parse(imageUrlWithCacheRevision(url, 3));

    expect(refreshed.queryParameters['token'], 'abc');
    expect(refreshed.queryParameters['_mdc_image_revision'], '3');
  });
}
