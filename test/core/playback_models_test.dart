import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/playback.dart';

void main() {
  test('播放决策解析模式、音轨和字幕轨', () {
    final decision = PlaybackDecision.fromJson(const {
      'mode': 'transcode',
      'stream_url': '/api/movies/id/1/stream.m3u8?quality=1080p',
      'mime_type': 'application/vnd.apple.mpegurl',
      'hwaccel': 'videotoolbox',
      'target_video': 'h264',
      'target_audio': 'aac',
      'target_height': 1080,
      'target_bitrate': 8000000,
      'reasons': ['container=matroska'],
      'audio_tracks': [
        {
          'index': 1,
          'codec': 'aac',
          'language': 'jpn',
          'title': '日语',
          'channels': 2,
          'default': true,
        },
      ],
      'subtitle_tracks': [
        {
          'index': 2,
          'source': 'external',
          'language': 'zh',
          'title': '简体中文',
          'codec': 'ass',
          'url': '/api/movies/id/1/subtitles/2?format=vtt',
          'default': true,
        },
      ],
    });

    expect(decision.isTranscode, isTrue);
    expect(decision.audioTracks.single.language, 'jpn');
    expect(decision.subtitleTracks.single.url, contains('format=vtt'));
    expect(decision.targetHeight, 1080);
  });

  test('硬解失败状态可识别软解回退', () {
    final status = TranscodeStatus.fromJson(const {
      'active': true,
      'quality': '1080p',
      'hw_accel': 'videotoolbox',
      'hw_decode_ok': false,
      'hw_encode_ok': true,
      'stderr_tail': 'hardware decoder failed',
    });

    expect(status.hasHardwareFallback, isTrue);
  });
}
