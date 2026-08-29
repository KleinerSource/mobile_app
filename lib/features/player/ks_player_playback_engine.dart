import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omm_ksplayer/omm_ksplayer.dart';

import '../../core/platform/app_log_store.dart';
import 'ks_player_seek_recovery.dart';
import 'playback_engine.dart';

class KsPlayerPlaybackEngine implements PlaybackEngine {
  KsPlayerPlaybackEngine()
    : _playerFuture = OmmKsPlayer.create(),
      _state = ValueNotifier(
        const PlaybackViewState(engineKind: PlaybackEngineKind.ksPlayer),
      );

  final Future<OmmKsPlayer> _playerFuture;
  final ValueNotifier<PlaybackViewState> _state;
  OmmKsPlayer? _player;
  StreamSubscription<KsPlayerEvent>? _eventSubscription;
  PlaybackPictureInPictureRequest? _pictureInPictureRequest;
  List<_WebVttCue> _subtitleCues = const [];
  Duration _subtitleDelay = Duration.zero;
  bool _disposed = false;
  bool _suppressErrorsUntilOpen = false;
  int _preloadBytes = 250 * 1024 * 1024;
  bool _hardwareAcceleration = true;
  Timer? _seekRecoveryTimer;
  int _seekRecoveryGeneration = 0;
  PlaybackOpenRequest? _lastOpenRequest;
  Duration? _pendingSeekTarget;
  int _stallReopenCount = 0;

  /// KSAVPlayer 的 seek completion 在目标分片无法加载时可能永远不回调。
  static const _seekReplyTimeout = Duration(seconds: 10);
  static const _seekRecoveryPolicy = KsPlayerSeekRecoveryPolicy();

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.ksPlayer;

  @override
  PlaybackEngineCapabilities get capabilities =>
      PlaybackEngineCapabilities.ksPlayer(
        framePreview: _mediaSupportsFramePreview,
      );

  /// KSPlayer fork 的帧预览会对整个媒体均匀生成 100 帧缩略图。本地文件
  /// 可按 Range 取帧没有问题；但 HLS 无法按区间取帧，生成缩略图等于在
  /// 后台下载整部视频，并与定位目标分片抢占连接池，导致长距离拖拽后
  /// 长时间无法恢复播放。因此网络 HLS 关闭拖拽帧预览。
  static bool mediaIsHls(String url, String? formatHint) {
    final hint = formatHint?.trim().toLowerCase() ?? '';
    if (hint == 'm3u8' || hint == 'hls' || hint.contains('mpegurl')) {
      return true;
    }
    final uri = Uri.tryParse(url.trim());
    final path = uri?.path.toLowerCase() ?? url.trim().toLowerCase();
    return path.endsWith('.m3u8');
  }

  bool _mediaSupportsFramePreview = true;

  @override
  ValueListenable<PlaybackViewState> get state => _state;

  Future<OmmKsPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = await _playerFuture;
    if (_disposed) {
      await player.dispose();
      throw StateError('播放器已释放');
    }
    _player = player;
    appLog('[KsPlayer] 原生播放器已创建: id=${player.playerId}');
    _eventSubscription = player.events.listen(_onEvent);
    return player;
  }

  void _update(PlaybackViewState Function(PlaybackViewState) update) {
    if (!_disposed) _state.value = update(_state.value);
  }

  void _onEvent(KsPlayerEvent event) {
    switch (event.type) {
      case KsPlayerEventType.ready:
        appLog('[KsPlayer] 收到 ready 事件');
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.ready,
            buffering: false,
          ),
        );
        unawaited(_refreshAudioTracks());
      case KsPlayerEventType.playing:
        _update((state) => state.copyWith(playing: event.boolValue ?? false));
      case KsPlayerEventType.buffering:
        _update((state) => state.copyWith(buffering: event.boolValue ?? false));
      case KsPlayerEventType.position:
        final position = Duration(
          milliseconds: (event.numberValue ?? 0).round(),
        );
        _update(
          (state) => state.copyWith(
            position: position,
            subtitleText: _subtitleAt(position),
          ),
        );
      case KsPlayerEventType.duration:
        _update(
          (state) => state.copyWith(
            duration: Duration(milliseconds: (event.numberValue ?? 0).round()),
          ),
        );
      case KsPlayerEventType.size:
        final nativeMediaInfo = PlaybackMediaInfo.fromJsonString(
          event.stringValue,
        );
        _update(
          (state) => state.copyWith(
            videoSize: Size(
              event.numberValue ?? 0,
              event.secondaryNumberValue ?? 0,
            ),
            mediaInfo: _mergeMediaInfo(state.mediaInfo, nativeMediaInfo),
          ),
        );
      case KsPlayerEventType.completed:
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.completed,
            playing: false,
          ),
        );
      case KsPlayerEventType.error:
        appLog('[KsPlayer] 收到 error 事件: ${event.stringValue ?? '未知错误'}');
        // KSPlayer 在已出首帧并开始推进时间后，底层播放器切换时可能迟到回调
        // 一次错误；此时画面仍在正常播放，不能把它变成统一播放失败状态。
        // stop() 到下一次 open() 之间的旧媒体错误同样不能污染新会话。
        if (_suppressErrorsUntilOpen ||
            shouldIgnoreKsPlayerError(_state.value)) {
          return;
        }
        _update(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.failed,
            error: event.stringValue ?? 'KSPlayer 播放失败',
          ),
        );
      case KsPlayerEventType.firstFrame:
        appLog('[KsPlayer] 收到 firstFrame 事件');
        _update((state) => state.copyWith(firstFrameRendered: true));
      case KsPlayerEventType.pictureInPicture:
        final active = event.boolValue ?? false;
        _update((state) => state.copyWith(inPictureInPicture: active));
        if (!active) {
          final request = _pictureInPictureRequest;
          _pictureInPictureRequest = null;
          if (request?.onStopped != null) {
            unawaited(request!.onStopped!(_state.value.position));
          }
        }
    }
  }

  Future<void> _refreshAudioTracks() async {
    final player = await _ensurePlayer();
    final tracks = await player.audioTracks();
    if (_disposed) return;
    String? selected;
    final mapped = <PlaybackAudioTrackState>[
      for (final track in tracks)
        PlaybackAudioTrackState(
          id: track.id,
          title: track.title,
          language: track.language,
          isSelected: track.selected,
        ),
    ];
    for (final track in mapped) {
      if (track.isSelected) {
        selected = track.id;
        break;
      }
    }
    _update(
      (state) => state.copyWith(
        audioTracks: mapped,
        selectedAudioTrackId: selected,
        clearSelectedAudioTrackId: selected == null,
      ),
    );
  }

  @override
  Future<void> open(PlaybackOpenRequest request) async {
    _cancelSeekRecovery();
    _lastOpenRequest = request;
    _stallReopenCount = 0;
    _suppressErrorsUntilOpen = false;
    _mediaSupportsFramePreview = !mediaIsHls(request.url, request.formatHint);
    _subtitleCues = const [];
    _update(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.opening,
        playing: false,
        buffering: true,
        position: request.startAt ?? Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        videoSize: Size.zero,
        mediaInfo: _initialMediaInfo(request),
        clearMediaInfo: true,
        subtitleText: const [],
        firstFrameRendered: false,
        clearError: true,
      ),
    );
    final player = await _ensurePlayer();
    appLog(
      '[KsPlayer] 调用原生 open: id=${player.playerId} '
      'url=${request.url} formatHint=${request.formatHint ?? ''} '
      'hw=$_hardwareAcceleration',
    );
    try {
      await player.open(
        request.url,
        startAt: request.startAt,
        autoplay: request.play,
        headers: request.headers,
        formatHint: request.formatHint,
        videoCodec: request.mediaInfo?.videoCodec,
        preloadBytes: _preloadBytes,
        hardwareAcceleration: _hardwareAcceleration,
      );
      appLog('[KsPlayer] 原生 open 已返回: id=${player.playerId}');
    } catch (error, stackTrace) {
      appLog('[KsPlayer] 原生 open 失败: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> play() async => (await _ensurePlayer()).play();

  @override
  Future<void> pause() async {
    // 暂停后不再补发 play，避免与用户意图对抗。
    _cancelSeekRecovery();
    await (await _ensurePlayer()).pause();
  }

  @override
  Future<void> playOrPause() => _state.value.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async {
    final player = await _ensurePlayer();
    final wasPlaying = _state.value.playing;
    _cancelSeekRecovery();
    _pendingSeekTarget = position;
    final generation = ++_seekRecoveryGeneration;
    // 目标分片拉取受阻时 KSAVPlayer 可能不回调 seek completion，超时兜底
    // 避免统一 seek 未来悬挂；卡死场景由恢复观察负责恢复。
    await player
        .seek(position)
        .timeout(_seekReplyTimeout, onTimeout: () {})
        .catchError((_) {});
    if (!wasPlaying || _disposed || generation != _seekRecoveryGeneration) {
      return;
    }
    _startSeekRecovery(player, generation);
  }

  /// 定位后观察缓冲状态：窗口内补发 play 推动内核恢复解码（与 libmpv
  /// 引擎定位后 paused-for-cache 的恢复语义一致）；确认卡死后优先按目标
  /// 位置重开媒体——重开走“起播+初始定位”这条已验证可用的路径，可绕过
  /// 内核远距离 seek 的任何内部僵死；重开后仍卡死才上报错误。
  void _startSeekRecovery(OmmKsPlayer player, int generation) {
    final startedAt = DateTime.now();
    appLog('[KsPlayer] 定位恢复观察启动');
    _seekRecoveryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || generation != _seekRecoveryGeneration) {
        timer.cancel();
        return;
      }
      final state = _state.value;
      final action = _seekRecoveryPolicy.evaluate(
        elapsed: DateTime.now().difference(startedAt),
        buffering: state.buffering,
        lifecycle: state.lifecycle,
      );
      switch (action) {
        case KsPlayerSeekRecoveryAction.stop:
          _cancelSeekRecovery();
        case KsPlayerSeekRecoveryAction.wait:
          break;
        case KsPlayerSeekRecoveryAction.nudgePlay:
          appLog('[KsPlayer] 定位后仍在缓冲，补发 play 恢复解码');
          unawaited(player.play().catchError((_) {}));
        case KsPlayerSeekRecoveryAction.reportStalled:
          _cancelSeekRecovery();
          unawaited(_recoverFromSeekStall(player));
      }
    });
  }

  Future<void> _recoverFromSeekStall(OmmKsPlayer player) async {
    if (_disposed) return;
    final request = _lastOpenRequest;
    final target = _pendingSeekTarget;
    if (_stallReopenCount > 0 || request == null || target == null) {
      appLog('[KsPlayer] 定位恢复失败，上报错误');
      _update(
        (current) => current.copyWith(
          lifecycle: PlaybackLifecycle.failed,
          error: '定位后播放长时间未恢复，请重试或切换画质',
        ),
      );
      return;
    }
    appLog('[KsPlayer] 定位恢复失败，自动按目标位置重开媒体: $target');
    try {
      await open(
        PlaybackOpenRequest(
          url: request.url,
          startAt: target,
          headers: request.headers,
          play: true,
          formatHint: request.formatHint,
          mediaInfo: request.mediaInfo,
        ),
      );
    } catch (error, stackTrace) {
      appLog('[KsPlayer] 卡死自动重开失败: $error\n$stackTrace');
      if (_disposed) return;
      _update(
        (current) => current.copyWith(
          lifecycle: PlaybackLifecycle.failed,
          error: '定位后播放长时间未恢复，请重试或切换画质',
        ),
      );
      return;
    }
    if (_disposed || _seekRecoveryTimer != null) return;
    // 本次 open 会话已用掉自动重开机会；重开后初始定位若仍卡死，直接上报。
    // （重开期间用户又拖拽会启动新的观察，此时不再叠加。）
    _stallReopenCount = 1;
    _startSeekRecovery(player, _seekRecoveryGeneration);
  }

  void _cancelSeekRecovery() {
    _seekRecoveryGeneration++;
    _seekRecoveryTimer?.cancel();
    _seekRecoveryTimer = null;
  }

  @override
  Future<void> setRate(double rate) async {
    await (await _ensurePlayer()).setRate(rate);
    _update((state) => state.copyWith(rate: rate));
  }

  @override
  Future<void> configure({
    bool? hardwareAcceleration,
    int? preloadBytes,
  }) async {
    if (preloadBytes != null && preloadBytes > 0) {
      _preloadBytes = preloadBytes;
    }
    if (hardwareAcceleration != null) {
      _hardwareAcceleration = hardwareAcceleration;
    }
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    await (await _ensurePlayer()).selectAudioTrack(id);
    await _refreshAudioTracks();
  }

  @override
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  }) async {
    await (await _ensurePlayer()).selectSubtitleTrack(id, fallbackIndex);
    _update((state) => state.copyWith(selectedSubtitleTrackId: id));
  }

  @override
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  }) async {
    _subtitleCues = _parseWebVtt(content);
    _update(
      (state) => state.copyWith(subtitleText: _subtitleAt(state.position)),
    );
  }

  @override
  Future<void> clearSubtitle() async {
    _subtitleCues = const [];
    final player = _player;
    if (player != null) await player.clearSubtitleTrack();
    _update(
      (state) => state.copyWith(
        subtitleText: const [],
        clearSelectedSubtitleTrackId: true,
      ),
    );
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    _subtitleDelay = delay;
    _update(
      (state) => state.copyWith(subtitleText: _subtitleAt(state.position)),
    );
  }

  List<String> _subtitleAt(Duration position) {
    final adjusted = position - _subtitleDelay;
    return [
      for (final cue in _subtitleCues)
        if (adjusted >= cue.start && adjusted < cue.end) cue.text,
    ];
  }

  @override
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  }) async => (await _ensurePlayer()).captureFrame(position);

  @override
  Future<void> clearFramePreview() async {
    final player = _player;
    if (player != null) await player.cancelFramePreview();
  }

  @override
  Future<bool> enterPictureInPicture(
    PlaybackPictureInPictureRequest request,
  ) async {
    _pictureInPictureRequest = request;
    final player = await _ensurePlayer();
    if (request.autoplay) {
      await player.play();
    } else {
      await player.pause();
    }
    final started = await player.startPictureInPicture();
    if (!started) _pictureInPictureRequest = null;
    return started;
  }

  @override
  Future<void> stopPictureInPicture() async {
    final player = _player;
    if (player != null) await player.stopPictureInPicture();
  }

  @override
  Future<void> stop() async {
    _cancelSeekRecovery();
    _lastOpenRequest = null;
    _pendingSeekTarget = null;
    _suppressErrorsUntilOpen = true;
    // 新建播放页首次加载时还没有原生播放器；stop 不应为了清理不存在的
    // 媒体而触发 Pigeon create/stop 往返，否则 iOS 可能阻塞后续直链 open。
    final player = _player;
    if (player != null) await player.stop();
    _update(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.stopped,
        playing: false,
        buffering: false,
      ),
    );
  }

  @override
  Widget buildSurface({BoxFit fit = BoxFit.contain}) {
    return FutureBuilder<OmmKsPlayer>(
      future: _playerFuture,
      builder: (_, snapshot) {
        final player = snapshot.data;
        return player == null
            ? const ColoredBox(color: Colors.black)
            : player.buildView(fit: fit);
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelSeekRecovery();
    _lastOpenRequest = null;
    _pendingSeekTarget = null;
    await _eventSubscription?.cancel();
    final player = _player ?? await _playerFuture;
    await player.dispose();
    _state.dispose();
  }

  PlaybackMediaInfo _initialMediaInfo(PlaybackOpenRequest request) {
    final initial =
        request.mediaInfo ??
        PlaybackMediaInfo.fromSource(
          url: request.url,
          formatHint: request.formatHint,
        );
    final inferredInternalPlayer =
        PlaybackMediaInfo.inferInternalPlayer(
          request.url,
          request.formatHint,
          videoCodec: initial.videoCodec,
        ) ??
        PlaybackMediaInfo.inferInternalPlayer('', initial.container);
    return initial.copyWith(internalPlayer: inferredInternalPlayer);
  }

  PlaybackMediaInfo? _mergeMediaInfo(
    PlaybackMediaInfo? current,
    PlaybackMediaInfo? incoming,
  ) {
    if (incoming == null) return current;
    final info = current ?? const PlaybackMediaInfo();
    return info.copyWith(
      container: incoming.container,
      videoCodec: incoming.videoCodec,
      videoBitrate: incoming.videoBitrate,
      videoFps: incoming.videoFps,
      videoDecoder: incoming.videoDecoder,
      audioCodec: incoming.audioCodec,
      audioBitrate: incoming.audioBitrate,
      internalPlayer: incoming.internalPlayer,
    );
  }
}

/// 判断 KSPlayer 的错误回调是否属于已成功开始播放后的迟到错误。
///
/// 打开期间的错误由 [PlaybackEngine.open] 的 Future 返回；播放期间已出首帧
/// 的迟到错误则不能把仍在工作的会话标记为失败。
bool shouldIgnoreKsPlayerError(PlaybackViewState state) =>
    state.lifecycle == PlaybackLifecycle.opening ||
    (state.firstFrameRendered &&
        (state.playing || state.position > Duration.zero));

@immutable
class _WebVttCue {
  const _WebVttCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

List<_WebVttCue> _parseWebVtt(String content) {
  final lines = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final cues = <_WebVttCue>[];
  for (var index = 0; index < lines.length; index++) {
    var timeline = lines[index].trim();
    if (!timeline.contains('-->') && index + 1 < lines.length) {
      final next = lines[index + 1].trim();
      if (next.contains('-->')) {
        index++;
        timeline = next;
      }
    }
    if (!timeline.contains('-->')) continue;
    final parts = timeline.split('-->');
    if (parts.length != 2) continue;
    final start = _parseWebVttTime(parts[0].trim());
    final endToken = parts[1].trim().split(RegExp(r'\s+')).first;
    final end = _parseWebVttTime(endToken);
    if (start == null || end == null || end <= start) continue;
    final text = <String>[];
    while (index + 1 < lines.length && lines[index + 1].trim().isNotEmpty) {
      text.add(lines[++index]);
    }
    if (text.isNotEmpty) {
      cues.add(_WebVttCue(start: start, end: end, text: text.join('\n')));
    }
  }
  return cues;
}

Duration? _parseWebVttTime(String value) {
  final parts = value.replaceAll(',', '.').split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final seconds = double.tryParse(parts.last);
  final minutes = int.tryParse(parts[parts.length - 2]);
  final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
  if (seconds == null || minutes == null || hours == null) return null;
  return Duration(
    milliseconds: ((hours * 3600 + minutes * 60 + seconds) * 1000).round(),
  );
}
