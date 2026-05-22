import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/media_info.dart';

void main() {
  test('MediaInfo.fromJson decodes flat fields', () {
    final mi = MediaInfo.fromJson({
      'container': 'mkv',
      'video_codec': 'hevc',
      'video_width': 1920,
      'video_height': 1080,
      'audio_codec': 'aac',
      'audio_channels': 2,
      'duration_sec': 5430.0,
      'bit_rate': 8000000,
      'file_size': 4500000000,
    });
    expect(mi.videoCodec, 'hevc');
    expect(mi.videoWidth, 1920);
    expect(mi.audioChannels, 2);
    expect(mi.fileSize, 4500000000);
  });

  test('MediaInfo.fromJson with empty map yields all-null fields', () {
    final mi = MediaInfo.fromJson(const {});
    expect(mi.container, isNull);
    expect(mi.videoCodec, isNull);
  });
}
