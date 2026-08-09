import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/url_resolver.dart';
import 'package:md_center/core/config/server_config.dart';

void main() {
  const config = ServerConfig(baseUrl: 'https://media.example/md-center');

  test('相对 API 地址保留反向代理前缀', () {
    expect(
      resolveServerUrl(config, '/api/movies/id/7/stream.m3u8?quality=1080p'),
      'https://media.example/md-center/api/movies/id/7/stream.m3u8?quality=1080p',
    );
  });

  test('图片路径自动补齐 API 前缀', () {
    expect(
      resolveApiUrl(config, '/images/poster-1'),
      'https://media.example/md-center/api/images/poster-1',
    );
  });

  test('HLS token 追加且保留画质 query', () {
    final url = appendQueryToken(
      'https://media.example/md-center/api/stream.m3u8?quality=720p',
      'access.token',
    );
    expect(url, contains('quality=720p'));
    expect(url, contains('token=access.token'));
  });

  test('外部 .strm 地址原样保留', () {
    const external = 'https://cdn.example/video.mp4?sig=abc';
    expect(resolveProtectedUrl(config, external, 'access.token'), external);
  });

  test('区分外部 .strm 地址与本地播放地址', () {
    expect(
      isExternalUrl(config, 'https://cdn.example/video.mp4?sig=abc'),
      isTrue,
    );
    expect(
      isExternalUrl(config, '/api/movies/id/7/stream?mode=direct'),
      isFalse,
    );
    expect(
      isExternalUrl(
        config,
        'https://media.example/md-center/api/movies/id/7/stream',
      ),
      isFalse,
    );
  });

  test('同服务器绝对地址追加 token', () {
    const local = 'https://media.example/api/movies/id/7/stream?mode=direct';
    expect(
      resolveProtectedUrl(config, local, 'access.token'),
      '$local&token=access.token',
    );
  });
}
