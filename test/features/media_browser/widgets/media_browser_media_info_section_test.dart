import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/widgets/media_browser_media_info_section.dart';

void main() {
  test('媒体信息使用当前选中的片源', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'movie-multi',
      'Name': '多片源电影',
      'Type': 'Movie',
      'RunTimeTicks': 6000000000,
      'MediaSources': [
        {
          'Id': 'ms-1',
          'Container': 'mkv',
          'Size': 4096,
          'MediaStreams': [
            {'Index': 0, 'Type': 'Video', 'Codec': 'hevc'},
          ],
        },
        {
          'Id': 'ms-2',
          'Container': 'mp4',
          'Size': 2048,
          'MediaStreams': [
            {'Index': 0, 'Type': 'Video', 'Codec': 'h264'},
            {'Index': 1, 'Type': 'Audio', 'Codec': 'aac'},
          ],
        },
      ],
    });

    final detail = mediaBrowserMediaInfoDetail(
      item,
      source: item.mediaSources[1],
      runTimeTicks: 1200000000,
    );

    expect(detail?.container, 'mp4');
    expect(detail?.durationSec, 120);
    expect(detail?.fileSize, 2048);
    expect(detail?.streams.video?.codec, 'h264');
    expect(detail?.streams.audioStreams.single.codec, 'aac');
  });
}
