import 'dart:async';

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

  test('Scratch 按住到边界不切歌，释放恢复播放后允许曲末推进', () {
    bool shouldAdvance({required bool scratching, required Duration position}) {
      return AudioPlaybackService.shouldAutoAdvanceScratchTrack(
        modeActive: true,
        playbackIntent: true,
        scratching: scratching,
        completionInFlight: false,
        position: position,
        duration: const Duration(seconds: 90),
        rate: 1,
      );
    }

    expect(shouldAdvance(scratching: true, position: Duration.zero), isFalse);
    expect(
      shouldAdvance(scratching: true, position: const Duration(seconds: 90)),
      isFalse,
    );
    expect(
      shouldAdvance(scratching: false, position: const Duration(seconds: 90)),
      isTrue,
    );
  });

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

  test('Scratch 恢复正常倍率后继续复用原生游标和输出', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final nativeCommands = <String>[];
    var prepareCalls = 0;
    var preparedSourceId = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          prepareCalls++;
          preparedSourceId = _sourceId(call);
          return _scratchState(positionMs: 10000, sourceId: preparedSourceId);
        case 'start':
          nativeCommands.add('scratch-start');
          return null;
        case 'play':
          nativeCommands.add('scratch-play');
          return null;
        case 'setRate':
          return null;
        case 'state':
          return _scratchState(positionMs: 10600, sourceId: preparedSourceId);
        case 'stop':
          nativeCommands.add('scratch-stop');
          return null;
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
          resumePlayback: true,
        ),
        isTrue,
      );
      expect(handler.scratchModePayloads.last['scratching'], isTrue);

      final handoff = await engine.finishScratch(resumePlayback: true);

      expect(handoff, const Duration(milliseconds: 10600));
      expect(engine.state.value.position, const Duration(milliseconds: 10600));
      expect(handler.seekPositions, isEmpty);
      expect(handler.commands, ['pause']);
      expect(nativeCommands, ['scratch-start']);
      expect(handler.scratchModePayloads.last['scratching'], isFalse);

      expect(
        await engine.startScratch(
          const Duration(milliseconds: 10600),
          resumePlayback: true,
        ),
        isTrue,
      );
      expect(prepareCalls, 1);
      expect(nativeCommands, ['scratch-start', 'scratch-play']);
      expect(handler.scratchModePayloads.last['scratching'], isTrue);
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
    var preparedSourceId = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          preparedSourceId = _sourceId(call);
          return _scratchState(
            positionMs: nativePositionMs,
            sourceId: preparedSourceId,
          );
        case 'start':
        case 'setRate':
        case 'stop':
          return null;
        case 'pause':
          return null;
        case 'state':
          stateCalls++;
          return _scratchState(
            positionMs: nativePositionMs,
            sourceId: preparedSourceId,
          );
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

      nativePositionMs = 17000;
      await engine.seek(const Duration(seconds: 17));
      expect(handler.seekPositions.last, const Duration(seconds: 17));
      expect(engine.state.value.position, const Duration(seconds: 17));

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
      expect(stateCalls, greaterThan(callsAfterFinish));
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
    var preparedSourceId = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          preparedSourceId = _sourceId(call);
          return _scratchState(positionMs: 10000, sourceId: preparedSourceId);
        case 'state':
          stateCalls++;
          return _scratchState(positionMs: 10000, sourceId: preparedSourceId);
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

  test('重新打开播放页会复用后台 Scratch 会话而不重新准备音轨', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var prepareCalls = 0;
    var startCalls = 0;
    var playCalls = 0;
    const sourceId = 'file:audio';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          prepareCalls++;
          return _scratchState(positionMs: 12000, sourceId: sourceId);
        case 'start':
          startCalls++;
          return null;
        case 'play':
          playCalls++;
          return null;
        case 'state':
          return _scratchState(positionMs: 12000, sourceId: sourceId);
        case 'setRate':
          return null;
      }
      return null;
    });

    final handler = _FakeAudioHandler()
      ..scratchModeResult = <String, dynamic>{
        'active': true,
        'playbackIntent': true,
        'positionMs': 12000,
        'durationMs': 120000,
        'sourceId': sourceId,
      };
    handler.mediaItem.add(
      const audio_service.MediaItem(
        id: 'file:audio',
        title: '歌曲.mp3',
        extras: <String, dynamic>{'audioUrl': 'https://example.test/audio.mp3'},
      ),
    );
    final engine = AudioPlaybackEngine(handler: handler);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prepareCalls, 0);

      expect(
        await engine.startScratch(
          const Duration(seconds: 12),
          resumePlayback: true,
        ),
        isTrue,
      );
      expect(prepareCalls, 0);
      expect(startCalls, 0);
      expect(playCalls, 1);
    } finally {
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('Scratch 准备结果属于其他音轨时拒绝启动', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var startCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          return _scratchState(positionMs: 0, sourceId: 'file:other');
        case 'start':
          startCalls++;
          return null;
        case 'setRate':
        case 'stop':
          return null;
      }
      return null;
    });

    const item = PlayerQueueItem(
      title: 'A.mp3',
      type: PlayerQueueItemType.audio,
      mediaId: 'library:a',
      directUrl: 'https://example.test/a.mp3',
    );
    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    try {
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/a.mp3',
          play: false,
          queue: [item],
        ),
      );

      expect(
        await engine.startScratch(Duration.zero, resumePlayback: false),
        isFalse,
      );
      expect(startCalls, 0);
    } finally {
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('快速切歌后只用新音轨身份启动 Scratch', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final prepareCompleters = <Completer<Map<String, Object>>>[];
    final preparedIds = <String>[];
    final startedIds = <String>[];
    var installedSourceId = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          preparedIds.add(_sourceId(call));
          final completer = Completer<Map<String, Object>>();
          prepareCompleters.add(completer);
          return completer.future;
        case 'start':
          final sourceId = _sourceId(call);
          startedIds.add(sourceId);
          if (sourceId != installedSourceId) {
            throw PlatformException(code: 'SCRATCH_AUDIO');
          }
          return null;
        case 'state':
          return _scratchState(positionMs: 0, sourceId: installedSourceId);
        case 'setRate':
        case 'stop':
          return null;
      }
      return null;
    });

    const first = PlayerQueueItem(
      title: 'A.mp3',
      type: PlayerQueueItemType.audio,
      mediaId: 'library:a',
      directUrl: 'https://example.test/a.mp3',
    );
    const second = PlayerQueueItem(
      title: 'B.mp3',
      type: PlayerQueueItemType.audio,
      mediaId: 'library:b',
      directUrl: 'https://example.test/b.mp3',
    );
    final handler = _FakeAudioHandler();
    final engine = AudioPlaybackEngine(handler: handler);
    try {
      await Future<void>.delayed(Duration.zero);
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/a.mp3',
          play: false,
          queue: [first],
        ),
      );
      await engine.open(
        const PlaybackOpenRequest(
          url: 'https://example.test/b.mp3',
          play: false,
          queue: [second],
        ),
      );
      expect(prepareCompleters, hasLength(2));

      final start = engine.startScratch(Duration.zero, resumePlayback: false);
      installedSourceId = second.safeMediaId;
      prepareCompleters[1].complete(
        _scratchState(positionMs: 0, sourceId: installedSourceId),
      );
      expect(await start, isTrue);

      prepareCompleters[0].complete(
        _scratchState(positionMs: 0, sourceId: installedSourceId),
      );
      await Future<void>.delayed(Duration.zero);
      expect(preparedIds, [first.safeMediaId, second.safeMediaId]);
      expect(startedIds, [second.safeMediaId]);
    } finally {
      for (final completer in prepareCompleters) {
        if (!completer.isCompleted) {
          completer.complete(
            _scratchState(positionMs: 0, sourceId: installedSourceId),
          );
        }
      }
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('页面重开不会复用其他音轨的后台 Scratch 会话', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('omm/scratch_audio');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var preparedSourceId = '';
    var stopCalls = 0;
    var startCalls = 0;
    var playCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'prepare':
          preparedSourceId = _sourceId(call);
          return _scratchState(positionMs: 0, sourceId: preparedSourceId);
        case 'state':
          return _scratchState(positionMs: 0, sourceId: preparedSourceId);
        case 'start':
          startCalls++;
          return null;
        case 'play':
          playCalls++;
          return null;
        case 'stop':
          stopCalls++;
          return null;
        case 'setRate':
          return null;
      }
      return null;
    });

    final handler = _FakeAudioHandler()
      ..scratchModeResult = <String, dynamic>{
        'active': true,
        'playbackIntent': true,
        'sourceId': 'file:b',
      };
    handler.mediaItem.add(
      const audio_service.MediaItem(
        id: 'file:a',
        title: 'A.mp3',
        extras: <String, dynamic>{'audioUrl': 'https://example.test/a.mp3'},
      ),
    );
    final engine = AudioPlaybackEngine(handler: handler);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(stopCalls, 1);
      expect(preparedSourceId, 'file:a');

      expect(
        await engine.startScratch(Duration.zero, resumePlayback: true),
        isTrue,
      );
      expect(startCalls, 1);
      expect(playCalls, 0);
    } finally {
      await engine.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

String _sourceId(MethodCall call) =>
    (call.arguments as Map<Object?, Object?>)['sourceId']?.toString() ?? '';

Map<String, Object> _scratchState({
  required int positionMs,
  required String sourceId,
}) => {
  'positionMs': positionMs,
  'durationMs': 120000,
  'rate': 1.0,
  'playing': true,
  'ready': true,
  'outputReady': true,
  'lastWriteResult': 1024,
  'sourceId': sourceId,
};

class _FakeAudioHandler extends audio_service.BaseAudioHandler {
  String? customActionName;
  Map<String, dynamic>? customActionExtras;
  final List<String> commands = <String>[];
  final List<Duration> seekPositions = <Duration>[];
  final List<Map<String, dynamic>> scratchModePayloads =
      <Map<String, dynamic>>[];
  List<String>? eventLog;
  Map<String, dynamic>? scratchModeResult;

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    customActionName = name;
    customActionExtras = extras;
    if (name == audioSetScratchModeAction && extras != null) {
      scratchModePayloads.add(Map<String, dynamic>.from(extras));
    }
    if (name == audioGetScratchModeAction) return scratchModeResult;
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
