import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/media_info.dart';
import 'package:md_center/core/models/playback.dart';
import 'package:md_center/features/player/playback_decision.dart'
    as player_decision;

void main() {
  test('移动端能力声明允许原画 H.264/HEVC 直传', () {
    final caps = PlaybackClientCaps.mobile(
      qualityPreset: 'original',
      userAgent: 'md_center/test',
    );
    final json = caps.toJson();
    final videoCodecs = json['video_codecs'] as Map<String, dynamic>;

    expect(videoCodecs['h264']['max_level'], 999);
    expect(videoCodecs['hevc']['max_level'], 999);
    expect(
      videoCodecs['hevc']['pix_formats'],
      containsAll(<String>['yuv420p', 'yuv420p10le']),
    );
    expect(json['quality_preset'], 'original');
  });

  test('H.264/HEVC 不因平台自动切换到服务端 HLS', () {
    for (final codec in <String>['h264', 'hevc', 'h265']) {
      final source = player_decision.PlaybackDecision.decide(
        streamUrl: '/stream',
        hlsUrl: '/stream.m3u8',
        mediaInfo: MediaInfo(
          container: 'matroska',
          videoCodec: codec,
          videoPixFmt: 'yuv420p10le',
        ),
      );

      expect(source.type, player_decision.PlaybackSourceType.direct,
          reason: codec);
      expect(source.url, '/stream', reason: codec);
    }
  });

  test('手动选择分辨率仍然强制使用服务端 HLS', () {
    final source = player_decision.PlaybackDecision.decide(
      streamUrl: '/stream',
      hlsUrl: '/stream.m3u8?quality=720p',
      forceHls: true,
    );

    expect(source.type, player_decision.PlaybackSourceType.hls);
    expect(source.url, contains('quality=720p'));
  });
}
