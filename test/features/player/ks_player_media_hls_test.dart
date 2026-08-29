import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/ks_player_playback_engine.dart';

void main() {
  test('按地址扩展名与容器提示识别 HLS', () {
    expect(
      KsPlayerPlaybackEngine.mediaIsHls(
        'http://10.0.0.50:9090/api/video/x/online-play/playlist.m3u8?target=a',
        null,
      ),
      isTrue,
      reason: '带查询参数的 m3u8 地址',
    );
    expect(
      KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/hls', 'mpegurl'),
      isTrue,
    );
    for (final hint in ['m3u8', 'hls', 'M3U8', ' HLS ']) {
      expect(
        KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/play', hint),
        isTrue,
        reason: 'hint=$hint',
      );
    }
  });

  test('普通媒体与回环代理文件不误判为 HLS', () {
    expect(
      KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/movie.mp4', null),
      isFalse,
    );
    expect(
      KsPlayerPlaybackEngine.mediaIsHls(
        'http://127.0.0.1:12345/token.mkv',
        null,
      ),
      isFalse,
    );
    expect(
      KsPlayerPlaybackEngine.mediaIsHls('https://a.com/v/movie.mp4', 'mp4'),
      isFalse,
    );
  });

  test('回环代理上的 m3u8 文件仍按 HLS 处理', () {
    expect(
      KsPlayerPlaybackEngine.mediaIsHls(
        'http://127.0.0.1:12345/tok.m3u8',
        null,
      ),
      isTrue,
    );
  });
}
