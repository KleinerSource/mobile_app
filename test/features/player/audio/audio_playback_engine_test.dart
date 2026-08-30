import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/audio/audio_playback_engine.dart';
import 'package:omm/features/player/audio/audio_playback_service.dart';
import 'package:omm/features/player/audio/audio_metadata.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_queue.dart';

void main() {
  test('音频打开请求只发送音频队列并保留顺序和索引', () async {
    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    const queue = [
      PlayerQueueItem(
        title: '第一首.mp3',
        type: PlayerQueueItemType.audio,
        mediaId: 'webdav:/music/one.mp3',
        directUrl: 'https://example.test/one.mp3',
      ),
      PlayerQueueItem(
        title: '第二首.flac',
        type: PlayerQueueItemType.audio,
        mediaId: 'webdav:/music/two.flac',
        directUrl: 'https://example.test/two.flac',
      ),
    ];

    await engine.open(
      const PlaybackOpenRequest(
        url: 'https://example.test/one.mp3',
        play: false,
        queue: queue,
        queueIndex: 1,
      ),
    );

    expect(handler.customActionName, audioOpenQueueAction);
    final payload = handler.customActionExtras!;
    expect(payload['queueIndex'], 1);
    expect(payload['play'], isFalse);
    final items = (payload['queue'] as List).cast<Map<String, dynamic>>();
    expect(items.map((item) => item['title']), ['第一首.mp3', '第二首.flac']);
    expect(
      items.map((item) => item['mediaId']),
      everyElement(startsWith('file:')),
    );
    expect(items.map((item) => item['url']), [
      'https://example.test/one.mp3',
      'https://example.test/two.flac',
    ]);

    await engine.dispose();
  });

  test('后台播放状态映射当前标题、进度、队列、随机和循环模式', () async {
    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    handler.mediaItem.add(
      const audio_service.MediaItem(
        id: 'file:audio',
        title: '正在播放.flac',
        duration: Duration(minutes: 3),
      ),
    );
    handler.playbackState.add(
      audio_service.PlaybackState(
        processingState: audio_service.AudioProcessingState.ready,
        playing: true,
        updatePosition: const Duration(seconds: 42),
        bufferedPosition: const Duration(seconds: 55),
        speed: 1.5,
        queueIndex: 2,
        shuffleMode: audio_service.AudioServiceShuffleMode.all,
        repeatMode: audio_service.AudioServiceRepeatMode.one,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = engine.state.value;
    expect(state.lifecycle, PlaybackLifecycle.ready);
    expect(state.playing, isTrue);
    expect(state.currentTitle, '正在播放.flac');
    expect(state.position.inSeconds, 42);
    expect(state.duration, const Duration(minutes: 3));
    expect(state.buffered, const Duration(seconds: 55));
    expect(state.rate, 1.5);
    expect(state.queueIndex, 2);
    expect(state.shuffleEnabled, isTrue);
    expect(state.repeatMode, PlaybackRepeatMode.one);

    await engine.dispose();
  });

  test('当前曲目元数据更新只传递本地封面 URI和非敏感字段', () async {
    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    handler.mediaItem.add(
      const audio_service.MediaItem(id: 'file:audio', title: '歌曲.mp3'),
    );
    await Future<void>.delayed(Duration.zero);

    await engine.updateCurrentMetadata(
      const AudioTrackMetadata(
        artworkPath: r'C:\Temp\cover.jpg',
        artist: '歌手',
        album: '专辑',
      ),
    );

    expect(handler.customActionName, audioUpdateMetadataAction);
    expect(handler.customActionExtras?['mediaId'], 'file:audio');
    expect(handler.customActionExtras?['artworkUri'], startsWith('file:'));
    expect(handler.customActionExtras?['artworkUri'], isNot(contains('token')));
    expect(handler.customActionExtras?['artist'], '歌手');
    expect(handler.customActionExtras?['album'], '专辑');

    await engine.dispose();
  });

  test('当前曲目元数据不会把远程封面地址传给后台服务', () async {
    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    handler.mediaItem.add(
      const audio_service.MediaItem(id: 'file:audio', title: '歌曲.mp3'),
    );
    await Future<void>.delayed(Duration.zero);

    await engine.updateCurrentMetadata(
      const AudioTrackMetadata(
        artworkPath: 'https://example.test/cover.jpg?token=secret',
      ),
    );

    expect(handler.customActionExtras?['artworkUri'], isEmpty);

    await engine.dispose();
  });
}

class _FakeAudioHandler extends audio_service.BaseAudioHandler {
  String? customActionName;
  Map<String, dynamic>? customActionExtras;

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    customActionName = name;
    customActionExtras = extras;
  }
}
