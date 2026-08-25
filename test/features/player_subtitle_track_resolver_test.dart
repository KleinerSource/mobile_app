import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:omm/features/player/player_subtitle_track_resolver.dart';

void main() {
  test('优先使用 media_kit 的内嵌字幕轨道 ID', () {
    const tracks = [
      SubtitleTrack('auto', null, null),
      SubtitleTrack('no', null, null),
      SubtitleTrack('7', '中文', 'zh'),
    ];

    expect(resolveSubtitleTrack(tracks, '7', fallbackIndex: 0), tracks.last);
  });

  test('轨道 ID 不一致时按内嵌字幕顺序回退', () {
    const tracks = [
      SubtitleTrack('auto', null, null),
      SubtitleTrack('no', null, null),
      SubtitleTrack('3', '英文', 'en'),
      SubtitleTrack('4', '中文', 'zh'),
    ];

    expect(resolveSubtitleTrack(tracks, '99', fallbackIndex: 1), tracks[3]);
    expect(resolveSubtitleTrack(tracks, '99', fallbackIndex: 2), isNull);
  });
}
