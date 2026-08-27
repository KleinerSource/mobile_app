import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/player_page.dart';

void main() {
  test('dbonline 直连播放器入口不需要 OMM 整数影片 ID', () {
    const page = PlayerPage.direct(
      title: 'ABC-001 · 第 1 集',
      directUrl: 'https://example.test/api/video/ABC-001/playlist.m3u8',
    );

    expect(page.movieId, isNull);
    expect(page.directUrl, contains('.m3u8'));
    expect(page.title, contains('ABC-001'));
  });
}
