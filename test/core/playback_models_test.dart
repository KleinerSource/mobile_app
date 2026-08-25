import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/playback.dart';

void main() {
  test('播放决策解析模式、音轨和字幕轨', () {
    final decision = PlaybackDecision.fromJson(const {
      'mode': 'transcode',
      'stream_url': '/api/movies/id/1/stream.m3u8?quality=1080p',
      'mime_type': 'application/vnd.apple.mpegurl',
      'container': 'matroska,webm',
      'video_codec': 'hevc',
      'duration_sec': 123.5,
      'bit_rate': 4000000,
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
          'id': 'subtitle-2',
          'index': 2,
          'source': 'external',
          'language': 'zh',
          'title': '简体中文',
          'codec': 'ass',
          'url': '/api/movies/id/1/subtitles/2?format=vtt',
          'default': true,
          'render_mode': 'overlay',
          'playable': true,
          'forced': true,
        },
      ],
    });

    expect(decision.isTranscode, isTrue);
    expect(decision.audioTracks.single.language, 'jpn');
    expect(decision.subtitleTracks.single.url, contains('format=vtt'));
    expect(decision.subtitleTracks.single.isExternal, isTrue);
    expect(decision.subtitleTracks.single.canLoad, isTrue);
    expect(decision.subtitleTracks.single.id, 'subtitle-2');
    expect(decision.subtitleTracks.single.renderMode, 'overlay');
    expect(decision.subtitleTracks.single.forced, isTrue);
    expect(decision.targetHeight, 1080);
    expect(decision.container, 'matroska,webm');
    expect(decision.videoCodec, 'hevc');
    expect(decision.durationSec, 123.5);
    expect(decision.bitRate, 4000000);
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

  test('PGS 内嵌字幕可识别为原生位图字幕', () {
    const track = SubtitleTrack(
      index: 4,
      source: 'embedded',
      language: 'eng',
      title: 'English PGS',
      codec: 'hdmv_pgs_subtitle',
      url: '',
      isDefault: false,
    );

    expect(track.isPgs, isTrue);
    expect(track.typeLabel, 'PGS');
    expect(track.sourceLabel, '内嵌');
    expect(track.isEmbedded, isTrue);
    expect(track.canLoad, isTrue);
  });

  test('普通文本字幕不启用 PGS 原生渲染', () {
    const track = SubtitleTrack(
      index: 3,
      source: 'embedded',
      language: 'zh',
      title: '中文',
      codec: 'ass',
      url: '/embedded.ass',
      isDefault: false,
    );

    expect(track.isPgs, isFalse);
    expect(track.typeLabel, 'ASS');
    expect(track.sourceLabel, '内嵌');
  });

  test('KSPlayer 能力声明宽格式客户端容器和编解码', () {
    final json = PlaybackClientCaps.ksPlayer(
      qualityPreset: 'original',
    ).toJson();

    expect(json['containers'], contains('mkv'));
    expect((json['video_codecs'] as Map).keys, contains('vp9'));
    expect((json['audio_codecs'] as Map).keys, contains('flac'));
  });
}
