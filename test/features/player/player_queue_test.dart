import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/player_page.dart';
import 'package:omm/features/player/player_queue.dart';

void main() {
  test('直链队列项保存文件播放信息而不需要 OMM 影片 ID', () {
    const item = PlayerQueueItem(
      title: '第二部.mkv',
      directUrl: 'http://127.0.0.1:1234/video-2.mkv',
      directHeaders: {'Authorization': 'Bearer test'},
      directFormatHint: 'mkv',
      directPlaybackFileName: '第二部.mkv',
      directPreferFfmpegForHls: true,
    );

    expect(item.movieId, isNull);
    expect(item.title, '第二部.mkv');
    expect(item.directUrl, contains('video-2.mkv'));
    expect(item.directHeaders, {'Authorization': 'Bearer test'});
    expect(item.directFormatHint, 'mkv');
    expect(item.directPlaybackFileName, '第二部.mkv');
    expect(item.directPreferFfmpegForHls, isTrue);
  });

  test('直链播放器入口保留队列和当前索引', () {
    const queue = [
      PlayerQueueItem(
        title: '第一部.mp4',
        directUrl: 'https://example.test/one.mp4',
        directPlaybackFileName: '第一部.mp4',
      ),
      PlayerQueueItem(
        title: '第二部.mp4',
        directUrl: 'https://example.test/two.mp4',
        directPlaybackFileName: '第二部.mp4',
      ),
    ];
    const page = PlayerPage.direct(
      title: '第二部.mp4',
      directUrl: 'https://example.test/two.mp4',
      directPlaybackFileName: '第二部.mp4',
      queue: queue,
      queueIndex: 1,
    );

    expect(page.queue, same(queue));
    expect(page.queueIndex, 1);
    expect(page.directUrl, 'https://example.test/two.mp4');
  });
}
