import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

/// 后台音频服务的自定义动作名。
const audioOpenQueueAction = 'omm.openAudioQueue';
const audioUpdateMetadataAction = 'omm.updateAudioMetadata';

/// 运行在主 isolate 的 SMB 代理资源注册表。
///
/// audio_service 的 handler 可能运行在后台 isolate，不能直接持有主
/// isolate 的回调；通过 customEvent 把“停止/替换/失败”事件传回来。
class AudioPlaybackResourceRegistry {
  AudioPlaybackResourceRegistry._();

  static final AudioPlaybackResourceRegistry instance =
      AudioPlaybackResourceRegistry._();

  final Map<String, List<Future<void> Function()>> _resources =
      <String, List<Future<void> Function()>>{};

  void register(String queueKey, Future<void> Function() dispose) {
    _resources
        .putIfAbsent(queueKey, () => <Future<void> Function()>[])
        .add(dispose);
  }

  void handleEvent(Object? event) {
    if (event is! Map) return;
    final type = event['type']?.toString();
    if (type != 'queue_resources') return;
    final queueKey = event['queueKey']?.toString();
    if (queueKey == null || queueKey.isEmpty) return;
    final disposers = _resources.remove(queueKey);
    if (disposers == null) return;
    for (final dispose in disposers) {
      unawaited(dispose());
    }
  }
}

/// 连接系统媒体会话的后台音频处理器。
class AudioPlaybackService extends audio_service.BaseAudioHandler
    with audio_service.SeekHandler {
  AudioPlaybackService() {
    _subscriptions.add(
      _player.playbackEventStream.listen((_) => _publishState()),
    );
    // playbackEventStream 不会持续发出播放位置；位置流负责驱动进度条和计时器。
    _subscriptions.add(_player.positionStream.listen((_) => _publishState()));
    _subscriptions.add(_player.errorStream.listen(_handlePlayerError));
    _subscriptions.add(
      _player.currentIndexStream.listen((_) => _publishState()),
    );
    _subscriptions.add(
      _player.sequenceStateStream.listen((_) => _publishState()),
    );
    _subscriptions.add(_player.durationStream.listen((_) => _publishState()));
  }

  static audio_service.AudioHandler? _handler;
  static StreamSubscription<Object?>? _resourceEventsSubscription;

  /// 应用启动时调用一次。返回的 handler 是 UI isolate 使用的代理。
  static Future<audio_service.AudioHandler> initialize() async {
    final current = _handler;
    if (current != null) return current;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final handler = await audio_service.AudioService.init<AudioPlaybackService>(
      builder: AudioPlaybackService.new,
      config: const audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.ohmymedia.audio',
        androidNotificationChannelName: '音乐播放',
        androidNotificationChannelDescription: '文件管理器音乐播放控制',
        androidNotificationOngoing: true,
        fastForwardInterval: Duration(seconds: 10),
        rewindInterval: Duration(seconds: 10),
      ),
    );
    _handler = handler;
    _bindResourceEvents(handler);
    return handler;
  }

  /// 测试或未经过应用入口初始化时使用本地 handler；正式启动会先执行
  /// [initialize]，因此生产环境仍由 audio_service 管理后台生命周期。
  static audio_service.AudioHandler get handler {
    final current = _handler;
    if (current != null) return current;
    final local = AudioPlaybackService();
    _handler = local;
    _bindResourceEvents(local);
    return local;
  }

  static void _bindResourceEvents(audio_service.AudioHandler handler) {
    _resourceEventsSubscription?.cancel();
    _resourceEventsSubscription = handler.customEvent.listen(
      AudioPlaybackResourceRegistry.instance.handleEvent,
    );
  }

  static void registerResources(
    String queueKey,
    Future<void> Function() dispose,
  ) {
    AudioPlaybackResourceRegistry.instance.register(queueKey, dispose);
  }

  final just_audio.AudioPlayer _player = just_audio.AudioPlayer(
    maxSkipsOnError: 0,
  );
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final List<audio_service.MediaItem> _items = <audio_service.MediaItem>[];
  Future<void> _operation = Future<void>.value();
  var _queueGeneration = 0;
  String? _queueKey;
  bool _playRequested = false;
  String? _errorMessage;
  final Set<int> _failedIndices = <int>{};
  audio_service.AudioServiceRepeatMode _repeatMode =
      audio_service.AudioServiceRepeatMode.none;
  audio_service.AudioServiceShuffleMode _shuffleMode =
      audio_service.AudioServiceShuffleMode.none;

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _operation.then<void>((_) => action());
    _operation = next.catchError((_) {});
    return next;
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) {
    final payload = extras ?? const <String, dynamic>{};
    if (name == audioOpenQueueAction) {
      final generation = ++_queueGeneration;
      return _enqueue(() => _replaceQueue(payload, generation));
    }
    if (name == audioUpdateMetadataAction) {
      return _enqueue(() => _updateCurrentMetadata(payload));
    }
    return super.customAction(name, extras);
  }

  Future<void> _updateCurrentMetadata(Map<String, dynamic> payload) async {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _items.length) return;
    final expectedId = payload['mediaId']?.toString().trim();
    final current = _items[index];
    if (expectedId == null || expectedId.isEmpty || current.id != expectedId) {
      return;
    }
    final rawArtwork = payload['artworkUri']?.toString().trim() ?? '';
    final artwork = rawArtwork.isEmpty ? null : Uri.tryParse(rawArtwork);
    final artist = payload['artist']?.toString().trim();
    final album = payload['album']?.toString().trim();
    final updated = current.copyWith(
      artUri: artwork,
      artist: artist == null || artist.isEmpty ? current.artist : artist,
      album: album == null || album.isEmpty ? current.album : album,
    );
    _items[index] = updated;
    queue.add(List<audio_service.MediaItem>.unmodifiable(_items));
    mediaItem.add(updated);
  }

  Future<void> _replaceQueue(
    Map<String, dynamic> extras,
    int generation,
  ) async {
    final rawQueue = extras['queue'];
    if (rawQueue is! List || rawQueue.isEmpty) {
      throw StateError('音频播放队列为空');
    }
    final nextItems = <audio_service.MediaItem>[];
    for (final raw in rawQueue) {
      if (raw is! Map) continue;
      final item = _mediaItemFromPayload(Map<String, dynamic>.from(raw));
      final url = _urlFor(item);
      if (url.isNotEmpty) nextItems.add(item);
    }
    if (nextItems.isEmpty) throw StateError('音频播放地址为空');

    await _releaseQueueResources('replaced');
    if (generation != _queueGeneration) return;
    await _player.stop();
    if (generation != _queueGeneration) return;
    await _player.clearAudioSources();
    if (generation != _queueGeneration) return;
    _items
      ..clear()
      ..addAll(nextItems);
    _queueKey = extras['queueKey']?.toString();
    _errorMessage = null;
    _failedIndices.clear();
    final initialIndex = _clampIndex(
      extras['queueIndex'] is num ? (extras['queueIndex'] as num).toInt() : 0,
      _items.length,
    );
    final positionMs = extras['positionMs'] is num
        ? (extras['positionMs'] as num).toInt()
        : 0;
    final sources = _items.map(_audioSourceFor).toList();
    queue.add(List<audio_service.MediaItem>.unmodifiable(_items));
    try {
      await _player.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: Duration(
          milliseconds: positionMs.clamp(0, 1 << 31).toInt(),
        ),
      );
      if (generation != _queueGeneration) {
        await _player.stop();
        await _player.clearAudioSources();
        return;
      }
      await _player.setLoopMode(_justAudioLoopMode(_repeatMode));
      if (_shuffleMode == audio_service.AudioServiceShuffleMode.all) {
        await _player.shuffle();
      }
      await _player.setShuffleModeEnabled(
        _shuffleMode == audio_service.AudioServiceShuffleMode.all,
      );
      _publishState();
      final shouldPlay = extras['play'] != false;
      // just_audio.play() 会在当前媒体结束后才完成；后台命令必须在开始
      // 播放后立即返回，否则替换队列的 customAction 会一直悬挂到歌曲结束。
      if (shouldPlay && generation == _queueGeneration) unawaited(play());
    } catch (_) {
      final failedQueueKey = _queueKey;
      await _clearQueueState();
      if (failedQueueKey != null) {
        _notifyResourceEvent(failedQueueKey, 'failed');
      }
      _queueKey = null;
      rethrow;
    }
  }

  audio_service.MediaItem _mediaItemFromPayload(Map<String, dynamic> payload) {
    final title = payload['title']?.toString().trim() ?? '';
    final safeId = payload['mediaId']?.toString().trim() ?? '';
    final headers = payload['headers']?.toString() ?? '{}';
    return audio_service.MediaItem(
      id: safeId.isEmpty ? 'item:${title.hashCode.abs()}' : safeId,
      title: title.isEmpty ? '未知音频' : title,
      artist: 'Oh My Media',
      album: '文件管理器',
      playable: true,
      extras: <String, dynamic>{
        'audioUrl': payload['url']?.toString() ?? '',
        'headersJson': headers,
        'formatHint': payload['formatHint']?.toString() ?? '',
        'fileName': payload['fileName']?.toString() ?? title,
      },
    );
  }

  just_audio.AudioSource _audioSourceFor(audio_service.MediaItem item) {
    return just_audio.AudioSource.uri(
      Uri.parse(_urlFor(item)),
      headers: _headersFor(item),
      tag: item,
    );
  }

  String _urlFor(audio_service.MediaItem item) =>
      item.extras?['audioUrl']?.toString().trim() ?? '';

  Map<String, String>? _headersFor(audio_service.MediaItem item) {
    final value = item.extras?['headersJson']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> play() async {
    _playRequested = true;
    await _player.play();
    _publishState();
  }

  @override
  Future<void> pause() async {
    _playRequested = false;
    await _player.pause();
    _publishState();
  }

  @override
  Future<void> stop() async {
    // stop 不能排在 setAudioSources 后面：后者可能正在等待远端文件响应。
    // 先使正在加载的队列失效并通知资源注册表，下载代理才能立即断开上游连接。
    ++_queueGeneration;
    _playRequested = false;
    await _releaseQueueResources('stopped');
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.clearAudioSources();
    } catch (_) {}
    await _clearQueueState();
  }

  @override
  Future<void> seek(Duration position) async {
    final duration = _player.duration;
    final target = duration == null
        ? (position < Duration.zero ? Duration.zero : position)
        : _clampDuration(position, Duration.zero, duration);
    await _player.seek(target);
    _publishState();
  }

  @override
  Future<void> fastForward() =>
      seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => seek(_player.position - const Duration(seconds: 10));

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
    _publishState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
    _publishState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    await _player.seek(Duration.zero, index: index);
    _publishState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed.clamp(0.25, 4.0).toDouble());
    _publishState();
  }

  @override
  Future<void> setShuffleMode(
    audio_service.AudioServiceShuffleMode shuffleMode,
  ) async {
    _shuffleMode = shuffleMode == audio_service.AudioServiceShuffleMode.all
        ? audio_service.AudioServiceShuffleMode.all
        : audio_service.AudioServiceShuffleMode.none;
    if (_shuffleMode == audio_service.AudioServiceShuffleMode.all) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(
      _shuffleMode == audio_service.AudioServiceShuffleMode.all,
    );
    _publishState();
  }

  @override
  Future<void> setRepeatMode(
    audio_service.AudioServiceRepeatMode repeatMode,
  ) async {
    _repeatMode = switch (repeatMode) {
      audio_service.AudioServiceRepeatMode.one =>
        audio_service.AudioServiceRepeatMode.one,
      audio_service.AudioServiceRepeatMode.all =>
        audio_service.AudioServiceRepeatMode.all,
      _ => audio_service.AudioServiceRepeatMode.none,
    };
    await _player.setLoopMode(_justAudioLoopMode(_repeatMode));
    _publishState();
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final index = _items.indexWhere((item) => item.id == mediaId);
    if (index >= 0) await skipToQueueItem(index);
    await play();
  }

  @override
  Future<void> playMediaItem(audio_service.MediaItem mediaItem) async {
    final index = _items.indexOf(mediaItem);
    if (index >= 0) {
      await skipToQueueItem(index);
      await play();
    }
  }

  Future<void> _handlePlayerError(just_audio.PlayerException error) async {
    final errorMessage = error.message ?? '音频播放失败';
    final failedIndex = error.index ?? _player.currentIndex;
    if (failedIndex != null) _failedIndices.add(failedIndex);
    if (_player.hasNext && !_failedIndices.contains(_player.nextIndex)) {
      final shouldPlay = _playRequested;
      try {
        await _player.seekToNext();
        if (shouldPlay) await _player.play();
        _errorMessage = null;
        _publishState();
        return;
      } catch (_) {}
    }
    _errorMessage = errorMessage;
    _publishState();
    await stop();
  }

  void _publishState() {
    final index = _player.currentIndex;
    final current = index != null && index >= 0 && index < _items.length
        ? _items[index]
        : null;
    final duration = _player.duration;
    if (current != null && duration != null && current.duration != duration) {
      final updated = current.copyWith(duration: duration);
      _items[index!] = updated;
      queue.add(List<audio_service.MediaItem>.unmodifiable(_items));
      mediaItem.add(updated);
    } else {
      mediaItem.add(current);
    }
    final processingState = switch (_player.processingState) {
      just_audio.ProcessingState.idle =>
        audio_service.AudioProcessingState.idle,
      just_audio.ProcessingState.loading =>
        audio_service.AudioProcessingState.loading,
      just_audio.ProcessingState.buffering =>
        audio_service.AudioProcessingState.buffering,
      just_audio.ProcessingState.ready =>
        audio_service.AudioProcessingState.ready,
      just_audio.ProcessingState.completed =>
        audio_service.AudioProcessingState.completed,
    };
    playbackState.add(
      audio_service.PlaybackState(
        controls: current == null
            ? const []
            : [
                audio_service.MediaControl.skipToPrevious,
                if (_player.playing)
                  audio_service.MediaControl.pause
                else
                  audio_service.MediaControl.play,
                audio_service.MediaControl.stop,
                audio_service.MediaControl.skipToNext,
              ],
        androidCompactActionIndices: current == null ? null : const [0, 1, 3],
        systemActions: const {
          audio_service.MediaAction.seek,
          audio_service.MediaAction.seekForward,
          audio_service.MediaAction.seekBackward,
        },
        processingState: _errorMessage == null
            ? processingState
            : audio_service.AudioProcessingState.error,
        errorMessage: _errorMessage,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: index,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      ),
    );
  }

  just_audio.LoopMode _justAudioLoopMode(
    audio_service.AudioServiceRepeatMode mode,
  ) => switch (mode) {
    audio_service.AudioServiceRepeatMode.one => just_audio.LoopMode.one,
    audio_service.AudioServiceRepeatMode.all => just_audio.LoopMode.all,
    _ => just_audio.LoopMode.off,
  };

  Future<void> _releaseQueueResources(String reason) async {
    final key = _queueKey;
    if (key == null || key.isEmpty) return;
    _queueKey = null;
    _notifyResourceEvent(key, reason);
  }

  void _notifyResourceEvent(String queueKey, String reason) {
    customEvent.add(<String, dynamic>{
      'type': 'queue_resources',
      'queueKey': queueKey,
      'reason': reason,
    });
  }

  Future<void> _clearQueueState() async {
    _items.clear();
    queue.add(const <audio_service.MediaItem>[]);
    mediaItem.add(null);
    playbackState.add(
      audio_service.PlaybackState(
        processingState: audio_service.AudioProcessingState.idle,
        playing: false,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      ),
    );
  }

  int _clampIndex(int value, int length) {
    if (length <= 0) return 0;
    return value.clamp(0, length - 1).toInt();
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
