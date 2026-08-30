import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/video/video_player_page.dart';
import 'package:omm/features/player/common/player_queue.dart';

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
    const page = VideoPlayerPage.direct(
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

  test('音频队列按安全媒体 ID 传递运行时地址', () {
    const item = PlayerQueueItem(
      title: '夜曲.flac',
      type: PlayerQueueItemType.audio,
      mediaId: 'smb:/music/夜曲.flac',
      directUrl: 'https://example.test/music.flac?token=secret-token',
      directHeaders: {'Authorization': 'Bearer secret-token'},
      directFormatHint: 'flac',
    );

    expect(item.safeMediaId, startsWith('file:'));
    expect(item.safeMediaId, isNot(contains('secret-token')));
    expect(item.toAudioPayload()['mediaId'], item.safeMediaId);
    expect(item.toAudioPayload()['url'], contains('secret-token'));
  });

  test('音频队列项保留音频类型', () {
    const item = PlayerQueueItem(
      title: '录音.m4a',
      type: PlayerQueueItemType.audio,
    );

    expect(item.type, PlayerQueueItemType.audio);
    expect(item.movieId, isNull);
  });
}
