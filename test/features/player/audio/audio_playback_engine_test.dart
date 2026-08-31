import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/audio/audio_playback_engine.dart';
import 'package:omm/features/player/audio/audio_playback_service.dart';
import 'package:omm/features/player/audio/audio_metadata.dart';
import 'package:omm/features/player/common/playback_engine.dart';
import 'package:omm/features/player/common/player_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('Scratch 交接会追上原生游标并在关闭输出前恢复主播放', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final nativeCommands = <String>[];
    final handoffEvents = <String>[];
    var stateCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          return _scratchState(positionMs: 10000);
        case 'start':
          nativeCommands.add('scratch-start');
          return null;
        case 'setRate':
          return null;
        case 'state':
          stateCalls++;
          return _scratchState(
            positionMs: switch (stateCalls) {
              1 => 10000,
              _ => 10600,
            },
          );
        case 'stop':
          nativeCommands.add('scratch-stop');
          handoffEvents.add('scratch-stop');
          return null;
      }
      return null;
    });

    final handler = _FakeAudioHandler()..eventLog = handoffEvents;
    final engine = AudioPlaybackEngine(handler: handler);
    try {
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/audio.mp3',
          play: false,
        ),
      );
      expect(
        await engine.startScratch(
          const Duration(seconds: 10),
          resumePlayback: true,
        ),
        isTrue,
      );

      final handoff = await engine.finishScratch(resumePlayback: true);

      expect(handler.seekPositions, [
        const Duration(milliseconds: 10500),
        const Duration(milliseconds: 11300),
      ]);
      expect(handoff, const Duration(milliseconds: 11300));
      expect(engine.state.value.position, const Duration(milliseconds: 11300));
      expect(handler.commands, containsAllInOrder(['pause', 'play']));
      expect(nativeCommands, ['scratch-start', 'scratch-stop']);
      expect(handoffEvents, containsAllInOrder(['play', 'scratch-stop']));
    } finally {
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('Scratch 原生游标实时驱动播放进度并屏蔽主播放器旧位置', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var nativePositionMs = 10000;
    var stateCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          return _scratchState(positionMs: nativePositionMs);
        case 'start':
        case 'setRate':
        case 'stop':
          return null;
        case 'state':
          stateCalls++;
          return _scratchState(positionMs: nativePositionMs);
      }
      return null;
    });

    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    try {
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/audio.mp3',
          play: false,
        ),
      );
      expect(
        await engine.startScratch(
          const Duration(seconds: 10),
          resumePlayback: false,
        ),
        isTrue,
      );

      nativePositionMs = 15000;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.state.value.position, const Duration(seconds: 15));

      handler.playbackState.add(
        audio_service.PlaybackState(
          processingState: audio_service.AudioProcessingState.ready,
          playing: false,
          updatePosition: const Duration(seconds: 2),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.state.value.position, const Duration(seconds: 15));

      nativePositionMs = 8000;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.state.value.position, const Duration(seconds: 8));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.state.value.position, const Duration(seconds: 8));

      expect(
        await engine.finishScratch(resumePlayback: false),
        const Duration(seconds: 8),
      );
      final callsAfterFinish = stateCalls;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stateCalls, callsAfterFinish);
      expect(engine.state.value.position, const Duration(seconds: 8));
    } finally {
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('Scratch 取消和销毁后停止查询原生游标', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var stateCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
        case 'state':
          if (call.method == 'state') stateCalls++;
          return _scratchState(positionMs: 10000);
        case 'start':
        case 'setRate':
        case 'stop':
          return null;
      }
      return null;
    });

    final handler = _FakeAudioHandler();
    var engine = AudioPlaybackEngine(handler: handler);
    try {
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/audio.mp3',
          play: false,
        ),
      );
      expect(
        await engine.startScratch(
          const Duration(seconds: 10),
          resumePlayback: false,
        ),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(stateCalls, greaterThan(0));

      await engine.cancelScratchStart();
      final callsAfterCancel = stateCalls;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stateCalls, callsAfterCancel);

      await engine.dispose();
      engine = AudioPlaybackEngine(handler: handler);
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/audio.mp3',
          play: false,
        ),
      );
      expect(
        await engine.startScratch(
          const Duration(seconds: 10),
          resumePlayback: false,
        ),
        isTrue,
      );
      await engine.dispose();
      final callsAfterDispose = stateCalls;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stateCalls, callsAfterDispose);
    } finally {
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Map<String, Object> _scratchState({required int positionMs}) => {
  'positionMs': positionMs,
  'durationMs': 120000,
  'rate': 1.0,
  'playing': true,
  'ready': true,
  'outputReady': true,
  'lastWriteResult': 1024,
};

class _FakeAudioHandler extends audio_service.BaseAudioHandler {
  String? customActionName;
  Map<String, dynamic>? customActionExtras;
  final List<String> commands = <String>[];
  final List<Duration> seekPositions = <Duration>[];
  List<String>? eventLog;

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    customActionName = name;
    customActionExtras = extras;
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    eventLog?.add('pause');
  }

  @override
  Future<void> play() async {
    commands.add('play');
    eventLog?.add('play');
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek');
    eventLog?.add('seek');
    seekPositions.add(position);
  }
}
