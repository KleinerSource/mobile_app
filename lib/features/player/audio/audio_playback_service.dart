import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:omm_scratch_audio/omm_scratch_audio.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/generated/app_localizations_en.dart';
import '../../../l10n/generated/app_localizations_zh.dart';

/// 后台音频服务的自定义动作名。
const audioOpenQueueAction = 'omm.openAudioQueue';
const audioUpdateMetadataAction = 'omm.updateAudioMetadata';
const audioSetScratchModeAction = 'omm.setScratchMode';
const audioGetScratchModeAction = 'omm.getScratchMode';

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
  static Locale? _localeOverride;

  static AppL10n _l10n() {
    final locale = _localeOverride ?? PlatformDispatcher.instance.locale;
    return locale.languageCode.toLowerCase() == 'zh'
        ? AppL10nZh(locale.languageCode)
        : AppL10nEn(locale.languageCode);
  }

  @visibleForTesting
  static bool shouldAutoAdvanceScratchTrack({
    required bool modeActive,
    required bool playbackIntent,
    required bool scratching,
    required bool completionInFlight,
    required Duration position,
    required Duration duration,
    required double rate,
  }) {
    return modeActive &&
        playbackIntent &&
        !scratching &&
        !completionInFlight &&
        duration > Duration.zero &&
        rate > 0 &&
        duration - position <= const Duration(milliseconds: 20);
  }

  static StreamSubscription<Object?>? _resourceEventsSubscription;

  /// 应用启动时调用一次。返回的 handler 是 UI isolate 使用的代理。
  static Future<audio_service.AudioHandler> initialize({Locale? locale}) async {
    _localeOverride = locale;
    final current = _handler;
    if (current != null) return current;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final l = _l10n();
    final handler = await audio_service.AudioService.init<AudioPlaybackService>(
      builder: AudioPlaybackService.new,
      config: audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.ohmymedia.audio',
        androidNotificationChannelName: l.audioNotificationChannelName,
        androidNotificationChannelDescription:
            l.audioNotificationChannelDescription,
        androidNotificationOngoing: true,
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
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
  Future<void> _seekOperation = Future<void>.value();
  var _queueGeneration = 0;
  var _seekGeneration = 0;
  Duration? _pendingSeekTarget;
  String? _queueKey;
  bool _playRequested = false;
  String? _errorMessage;
  final Set<int> _failedIndices = <int>{};
  Timer? _scratchPositionTimer;
  ScratchAudioState? _scratchState;
  bool _scratchStateRequestInFlight = false;
  bool _scratchCompletionInFlight = false;
  bool _scratchModeActive = false;
  bool _scratchPlaybackIntent = false;
  bool _scratchGestureActive = false;
  bool _scratchCompleted = false;
  int _scratchModeGeneration = 0;
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
      _invalidatePendingSeek();
      final generation = ++_queueGeneration;
      return _enqueue(() => _replaceQueue(payload, generation));
    }
    if (name == audioUpdateMetadataAction) {
      return _enqueue(() => _updateCurrentMetadata(payload));
    }
    if (name == audioSetScratchModeAction) {
      return _setScratchMode(payload);
    }
    if (name == audioGetScratchModeAction) {
      return Future<dynamic>.value(<String, dynamic>{
        'active': _scratchModeActive,
        'playbackIntent': _scratchPlaybackIntent,
        'positionMs': _scratchState?.position.inMilliseconds ?? 0,
        'durationMs': _scratchState?.duration.inMilliseconds ?? 0,
        'sourceId': _scratchState?.sourceId ?? '',
        'scratching': _scratchGestureActive,
      });
    }
    return super.customAction(name, extras);
  }

  Future<void> _setScratchMode(Map<String, dynamic> payload) async {
    final active = payload['active'] == true;
    if (!active) {
      _clearScratchMode();
      _publishState();
      return;
    }

    await _cancelAndDrainPendingSeek();

    final sourceId = payload['sourceId']?.toString() ?? '';
    if (sourceId.isEmpty) throw StateError('Scratch 音轨身份为空');
    final scratching = payload['scratching'] == true;
    if (scratching &&
        _scratchModeActive &&
        _scratchState?.sourceId == sourceId) {
      // 重抓唱片时先关闭曲末推进窗口，再等待平台状态往返。
      _scratchGestureActive = true;
    }
    final generation = ++_scratchModeGeneration;
    final state = await OmmScratchAudio.state();
    if (!state.ready || state.sourceId != sourceId) {
      throw StateError('Scratch 音轨身份不匹配');
    }
    final index = _player.currentIndex;
    final currentId = index != null && index >= 0 && index < _items.length
        ? _items[index].id
        : null;
    if (currentId != sourceId) throw StateError('Scratch 不是当前播放音轨');
    if (generation != _scratchModeGeneration) return;
    _scratchModeActive = true;
    _scratchPlaybackIntent = payload['playbackIntent'] == true;
    _scratchGestureActive = scratching;
    _scratchCompleted = false;
    _playRequested = _scratchPlaybackIntent;
    _scratchState = state;
    _startScratchPositionPolling();
    _publishState();
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

    await _stopScratchOutput();
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
        // 音频代理会在首次 GET 时完整缓存文件。这里不能再预加载，
        // 否则 setAudioSources 会等待底层解码进入 ready，页面会一直卡在 loading；
        // 后续由 play() 触发实际加载和播放。
        preload: false,
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
      title: title.isEmpty ? _l10n().audioUnknownTitle : title,
      artist: 'Oh My Media',
      album: _l10n().audioFileManagerAlbum,
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
    if (_scratchModeActive) {
      _scratchPlaybackIntent = true;
      if (_scratchCompleted) {
        await OmmScratchAudio.seek(Duration.zero);
        _scratchCompleted = false;
      }
      await OmmScratchAudio.setRate(_player.speed);
      await OmmScratchAudio.play();
      await _refreshScratchState();
      _publishState();
      return;
    }
    await _player.play();
    _publishState();
  }

  @override
  Future<void> pause() async {
    _playRequested = false;
    if (_scratchModeActive) {
      _scratchPlaybackIntent = false;
      await OmmScratchAudio.pause();
      await _refreshScratchState();
      _publishState();
      return;
    }
    await _player.pause();
    _publishState();
  }

  @override
  Future<void> stop() async {
    // stop 不能排在 setAudioSources 后面：后者可能正在等待远端文件响应。
    // 先使正在加载的队列失效并通知资源注册表，下载代理才能立即断开上游连接。
    ++_queueGeneration;
    _invalidatePendingSeek();
    _playRequested = false;
    await _stopScratchOutput();
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
  Future<void> seek(Duration position) {
    final duration = _scratchModeActive
        ? _scratchState?.duration
        : _player.duration;
    final target = duration == null
        ? (position < Duration.zero ? Duration.zero : position)
        : _clampDuration(position, Duration.zero, duration);
    final generation = ++_seekGeneration;
    _pendingSeekTarget = target;
    _publishState();
    final next = _seekOperation.then<void>(
      (_) => _performSeek(target, generation),
    );
    _seekOperation = next.catchError((_) {});
    return next;
  }

  Future<void> _performSeek(Duration target, int generation) async {
    if (generation != _seekGeneration) return;
    try {
      if (_scratchModeActive) {
        _scratchCompleted = false;
        final scratchGeneration = ++_scratchModeGeneration;
        await OmmScratchAudio.seek(target);
        if (generation != _seekGeneration ||
            scratchGeneration != _scratchModeGeneration ||
            !_scratchModeActive) {
          return;
        }
        final state = await OmmScratchAudio.state();
        if (generation != _seekGeneration ||
            scratchGeneration != _scratchModeGeneration ||
            !_scratchModeActive) {
          return;
        }
        if (state.ready && state.sourceId == _scratchState?.sourceId) {
          _scratchState = state;
        }
      } else {
        await _player.seek(target);
        if (generation != _seekGeneration) return;
      }
      _pendingSeekTarget = null;
      _publishState();
    } catch (_) {
      if (generation == _seekGeneration) {
        _pendingSeekTarget = null;
        _publishState();
      }
      rethrow;
    }
  }

  @override
  Future<void> fastForward() => seek(
    (_pendingSeekTarget ?? _scratchState?.position ?? _player.position) +
        const Duration(seconds: 10),
  );

  @override
  Future<void> rewind() => seek(
    (_pendingSeekTarget ?? _scratchState?.position ?? _player.position) -
        const Duration(seconds: 10),
  );

  @override
  Future<void> skipToNext() async {
    await _cancelAndDrainPendingSeek();
    final shouldPlay = await _leaveScratchForTrackChange();
    if (_player.hasNext) await _player.seekToNext();
    if (shouldPlay) unawaited(_player.play());
    _publishState();
  }

  @override
  Future<void> skipToPrevious() async {
    await _cancelAndDrainPendingSeek();
    final shouldPlay = await _leaveScratchForTrackChange();
    if (_player.hasPrevious) await _player.seekToPrevious();
    if (shouldPlay) unawaited(_player.play());
    _publishState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    await _cancelAndDrainPendingSeek();
    final shouldPlay = await _leaveScratchForTrackChange();
    await _player.seek(Duration.zero, index: index);
    if (shouldPlay) unawaited(_player.play());
    _publishState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    final target = speed.clamp(0.25, 4.0).toDouble();
    await _player.setSpeed(target);
    if (_scratchModeActive) await OmmScratchAudio.setRate(target);
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

  void _startScratchPositionPolling() {
    _scratchPositionTimer?.cancel();
    _scratchPositionTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => unawaited(_pollScratchState()),
    );
  }

  Future<void> _pollScratchState() async {
    await _refreshScratchState();
    if (!_scratchModeActive) return;
    if (await _completeScratchTrackIfNeeded()) return;
    _publishState();
  }

  Future<void> _refreshScratchState() async {
    if (!_scratchModeActive || _scratchStateRequestInFlight) return;
    final generation = _scratchModeGeneration;
    _scratchStateRequestInFlight = true;
    try {
      final state = await OmmScratchAudio.state();
      if (_scratchModeActive &&
          generation == _scratchModeGeneration &&
          state.ready &&
          state.sourceId == _scratchState?.sourceId) {
        _scratchState = state;
      }
    } catch (_) {
      // 短暂的平台通道失败不应切回另一播放器；下一次轮询继续使用同一游标。
    } finally {
      _scratchStateRequestInFlight = false;
    }
  }

  void _invalidatePendingSeek() {
    _seekGeneration++;
    _pendingSeekTarget = null;
  }

  Future<void> _cancelAndDrainPendingSeek() async {
    _invalidatePendingSeek();
    await _seekOperation;
  }

  Future<bool> _completeScratchTrackIfNeeded() async {
    final state = _scratchState;
    if (state == null ||
        !shouldAutoAdvanceScratchTrack(
          modeActive: _scratchModeActive,
          playbackIntent: _scratchPlaybackIntent,
          scratching: _scratchGestureActive,
          completionInFlight: _scratchCompletionInFlight,
          position: state.position,
          duration: state.duration,
          rate: state.rate,
        )) {
      return false;
    }

    _scratchCompletionInFlight = true;
    try {
      if (_repeatMode == audio_service.AudioServiceRepeatMode.one) {
        await OmmScratchAudio.seek(Duration.zero);
        await OmmScratchAudio.setRate(_player.speed);
        await OmmScratchAudio.play();
        _scratchCompleted = false;
        await _refreshScratchState();
        _publishState();
        return true;
      }
      if (_player.hasNext) {
        await skipToNext();
        return true;
      }

      _scratchPlaybackIntent = false;
      _playRequested = false;
      _scratchCompleted = true;
      await OmmScratchAudio.pause();
      _publishState();
      return true;
    } finally {
      _scratchCompletionInFlight = false;
    }
  }

  Future<bool> _leaveScratchForTrackChange() async {
    if (!_scratchModeActive) return false;
    final shouldPlay = _scratchPlaybackIntent;
    await _stopScratchOutput();
    _playRequested = shouldPlay;
    return shouldPlay;
  }

  Future<void> _stopScratchOutput() async {
    if (!_scratchModeActive) return;
    _clearScratchMode();
    try {
      await OmmScratchAudio.stop();
    } catch (_) {}
  }

  void _clearScratchMode() {
    _invalidatePendingSeek();
    _scratchModeGeneration++;
    _scratchPositionTimer?.cancel();
    _scratchPositionTimer = null;
    _scratchState = null;
    _scratchStateRequestInFlight = false;
    _scratchCompletionInFlight = false;
    _scratchModeActive = false;
    _scratchPlaybackIntent = false;
    _scratchGestureActive = false;
    _scratchCompleted = false;
  }

  Future<void> _handlePlayerError(just_audio.PlayerException error) async {
    final errorMessage = error.message ?? _l10n().audioPlaybackFailedGeneric;
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
    final scratchState = _scratchModeActive ? _scratchState : null;
    final duration = scratchState?.duration ?? _player.duration;
    if (current != null && duration != null && current.duration != duration) {
      final updated = current.copyWith(duration: duration);
      _items[index!] = updated;
      queue.add(List<audio_service.MediaItem>.unmodifiable(_items));
      mediaItem.add(updated);
    } else {
      mediaItem.add(current);
    }
    final processingState = scratchState?.ready == true
        ? (_scratchCompleted
              ? audio_service.AudioProcessingState.completed
              : audio_service.AudioProcessingState.ready)
        : switch (_player.processingState) {
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
    final playing = _scratchModeActive
        ? _scratchPlaybackIntent
        : _player.playing;
    playbackState.add(
      audio_service.PlaybackState(
        controls: current == null
            ? const []
            : [
                audio_service.MediaControl.skipToPrevious,
                if (playing)
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
        playing: playing,
        updatePosition:
            _pendingSeekTarget ?? scratchState?.position ?? _player.position,
        bufferedPosition: scratchState?.duration ?? _player.bufferedPosition,
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
