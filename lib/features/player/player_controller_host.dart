import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import 'playback_engine.dart';
import 'player_subtitle_track_resolver.dart';

/// 后向（已播放）demuxer 缓冲上限，固定值：既服务回看拖动，也把最坏
/// native 内存约束为 预载档位 + 64 MiB，远离 iOS Jetsam 限额。
const playerPreloadBackBufferBytes = 64 * 1024 * 1024;

/// 媒体时长未知时的预读时间窗兜底；实际预载深度由字节档位约束。
const playerPreloadWindowFallbackSeconds = 3600;

/// HLS seek 后只需要覆盖少量后续切片即可开始解码；如果沿用本地文件的
/// 大缓存窗口，播放器可能会在定位后等待过多前向数据，表现为拖动后久等。
const playerHlsPreloadWindowSeconds = 8;
const playerHlsPreloadBytes = 64 * 1024 * 1024;

/// media_kit 内核封装 · libmpv (内置 ffmpeg 软解 + VideoToolbox 硬解)
///
/// 把命令式播放 API + 状态流收拢到一个对象, 供 PlayerPage 编排。
/// PlayerPage 只通过本类的方法/getter 访问内核, 不直接接触 media_kit 类型。
class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine({
    this.hardwareAcceleration = true,
    this.bufferSize = 32 * 1024 * 1024,
  }) {
    _createPlayer();
    _bindState();
  }

  late Player player;
  late VideoController controller;
  bool hardwareAcceleration;
  int bufferSize;

  final ValueNotifier<PlaybackViewState> _state = ValueNotifier(
    const PlaybackViewState(engineKind: PlaybackEngineKind.libmpv),
  );
  final List<StreamSubscription<Object?>> _stateSubscriptions = [];
  Player? _previewPlayer;
  String? _previewSourceUrl;
  Map<String, String>? _previewHeaders;
  PlaybackOpenRequest? _openRequest;

  @override
  PlaybackEngineKind get kind => PlaybackEngineKind.libmpv;

  @override
  PlaybackEngineCapabilities get capabilities =>
      const PlaybackEngineCapabilities.libmpv();

  @override
  ValueListenable<PlaybackViewState> get state => _state;

  /// 预载（前向 demuxer 缓冲）的内存档位字节数，由播放页在每次打开前按
  /// 用户设置写入；[bufferSize] 只是播放器创建时的安全默认值，档位通过
  /// 运行时属性生效，失败时降级为小缓冲而不是放大内存。
  int preloadBytes = 250 * 1024 * 1024;
  int _openGeneration = 0;
  int _subtitleFileSeq = 0;
  File? _subtitleTempFile;

  void _createPlayer() {
    player = Player(configuration: PlayerConfiguration(bufferSize: bufferSize));
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: hardwareAcceleration,
      ),
    );
  }

  void _updateState(PlaybackViewState Function(PlaybackViewState) update) {
    _state.value = update(_state.value);
  }

  VideoTrack? _findSelectedVideoTrack(
    List<VideoTrack> tracks,
    String selectedId,
  ) {
    if (tracks.isEmpty) return null;
    for (final track in tracks) {
      if (track.id == selectedId && track.id != 'auto' && track.id != 'no') {
        return track;
      }
    }
    for (final track in tracks) {
      if (track.id != 'auto' && track.id != 'no') return track;
    }
    return null;
  }

  AudioTrack? _findSelectedAudioTrack(
    List<AudioTrack> tracks,
    String selectedId,
  ) {
    if (tracks.isEmpty) return null;
    for (final track in tracks) {
      if (track.id == selectedId && track.id != 'auto' && track.id != 'no') {
        return track;
      }
    }
    for (final track in tracks) {
      if (track.id != 'auto' && track.id != 'no') return track;
    }
    return null;
  }

  PlaybackMediaInfo? _mergeMediaInfo(
    PlaybackMediaInfo? current, {
    VideoTrack? videoTrack,
    AudioTrack? audioTrack,
  }) {
    if (videoTrack == null && audioTrack == null) return current;
    final info = current ?? const PlaybackMediaInfo();
    return info.copyWith(
      videoCodec: _nonEmpty(videoTrack?.codec),
      videoBitrate: _positiveInt(videoTrack?.bitrate),
      videoFps: _positiveDouble(videoTrack?.fps),
      videoDecoder: _nonEmpty(videoTrack?.decoder),
      audioCodec: _nonEmpty(audioTrack?.codec),
      audioBitrate: _positiveInt(audioTrack?.bitrate),
    );
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  int? _positiveInt(int? value) => value == null || value <= 0 ? null : value;

  double? _positiveDouble(double? value) =>
      value == null || !value.isFinite || value <= 0 ? null : value;

  void _bindState() {
    for (final subscription in _stateSubscriptions) {
      unawaited(subscription.cancel());
    }
    _stateSubscriptions.clear();
    _stateSubscriptions.addAll([
      player.stream.playing.listen(
        (value) => _updateState((state) => state.copyWith(playing: value)),
      ),
      player.stream.buffering.listen(
        (value) => _updateState((state) => state.copyWith(buffering: value)),
      ),
      player.stream.position.listen(
        (value) => _updateState((state) => state.copyWith(position: value)),
      ),
      player.stream.duration.listen(
        (value) => _updateState((state) => state.copyWith(duration: value)),
      ),
      player.stream.buffer.listen(
        (value) => _updateState((state) => state.copyWith(buffered: value)),
      ),
      player.stream.rate.listen(
        (value) => _updateState((state) => state.copyWith(rate: value)),
      ),
      player.stream.width.listen((value) {
        if (value == null) return;
        _updateState(
          (state) => state.copyWith(
            videoSize: Size(value.toDouble(), state.videoSize.height),
          ),
        );
      }),
      player.stream.height.listen((value) {
        if (value == null) return;
        _updateState(
          (state) => state.copyWith(
            videoSize: Size(state.videoSize.width, value.toDouble()),
          ),
        );
      }),
      player.stream.subtitle.listen(
        (value) => _updateState((state) => state.copyWith(subtitleText: value)),
      ),
      player.stream.tracks.listen((tracks) {
        final selectedId = player.state.track.audio.id;
        final selectedVideoId = player.state.track.video.id;
        final videoTrack = _findSelectedVideoTrack(
          tracks.video,
          selectedVideoId,
        );
        final audioTrack = _findSelectedAudioTrack(tracks.audio, selectedId);
        _updateState(
          (state) => state.copyWith(
            audioTracks: [
              for (final track in tracks.audio)
                PlaybackAudioTrackState(
                  id: track.id,
                  title: track.title ?? '',
                  language: track.language ?? '',
                  isSelected: track.id == selectedId,
                ),
            ],
            selectedAudioTrackId: selectedId,
            mediaInfo: _mergeMediaInfo(
              state.mediaInfo,
              videoTrack: videoTrack,
              audioTrack: audioTrack,
            ),
          ),
        );
      }),
      player.stream.completed.listen((completed) {
        if (!completed) return;
        _updateState(
          (state) => state.copyWith(
            lifecycle: PlaybackLifecycle.completed,
            playing: false,
          ),
        );
      }),
      player.stream.error.listen(
        (error) => _updateState(
          (state) =>
              state.copyWith(lifecycle: PlaybackLifecycle.failed, error: error),
        ),
      ),
    ]);
  }

  /// 打开网络源并起播 · [startAt] 为起播定位 (续播 / 切源保位)
  @override
  Future<void> open(PlaybackOpenRequest request) async {
    _openRequest = request;
    _updateState(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.opening,
        playing: false,
        buffering: true,
        position: request.startAt ?? Duration.zero,
        firstFrameRendered: false,
        mediaInfo:
            request.mediaInfo ??
            PlaybackMediaInfo.fromSource(
              url: request.url,
              formatHint: request.formatHint,
            ),
        clearMediaInfo: true,
        clearError: true,
      ),
    );
    await _openWithBufferOptions(
      request.url,
      startAt: request.startAt,
      headers: request.headers,
      play: request.play,
      formatHint: request.formatHint,
    );
    _updateState(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.ready,
        playing: request.play,
      ),
    );
    unawaited(_markFirstFrameRendered());
  }

  Future<void> _openWithBufferOptions(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
    bool play = true,
    String? formatHint,
  }) async {
    final openGeneration = ++_openGeneration;
    final targetPlayer = player;
    final targetPreloadBytes = preloadBytes;
    final isHls = _isHlsPlaybackUrl(url, formatHint);
    final effectivePreloadBytes =
        isHls && targetPreloadBytes > playerHlsPreloadBytes
        ? playerHlsPreloadBytes
        : targetPreloadBytes;
    try {
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        try {
          await targetPlayer.stop();
        } catch (error) {
          _playerHostLog('关闭旧媒体失败，继续应用缓冲配置: $error');
        }
        // 网络 demuxer 缓冲是播放器必需能力。预载在播放和暂停期间都会
        // 后台填充；时间窗先放宽到兜底值，实际深度由字节档位约束。
        await _setNativeProperty(platform, 'cache', 'yes');
        // media_kit 初始化默认开启 cache-on-disk，会把回退缓冲写成临时文件
        // 并在媒体关闭时删除。没有跨会话缓存需求时显式关闭，避免无谓 IO。
        await _setNativeProperty(platform, 'cache-on-disk', 'no');
        await _setNativeProperty(
          platform,
          'cache-secs',
          isHls
              ? '$playerHlsPreloadWindowSeconds'
              : '$playerPreloadWindowFallbackSeconds',
        );
        await _setNativeProperty(
          platform,
          'demuxer-max-bytes',
          '$effectivePreloadBytes',
        );
        await _setNativeProperty(
          platform,
          'demuxer-max-back-bytes',
          '$playerPreloadBackBufferBytes',
        );
      }
    } catch (_) {
      // 部分平台的 mpv 构建不允许运行时修改缓存选项，仍继续正常播放。
    }
    await targetPlayer.open(
      Media(url, start: startAt, httpHeaders: headers),
      play: play,
    );
    // Player.open() 内部会先 stop 再 loadlist，open 完成后回读确认缓冲
    // 属性仍然生效，避免媒体加载边界覆盖运行时配置。
    await _ensureCacheOptionsAfterOpen(
      targetPlayer,
      openGeneration,
      preloadBytes: effectivePreloadBytes,
      isHls: isHls,
    );
    await _logNativeCacheState(targetPlayer, 'open');
    unawaited(
      _applyPreloadWindow(
        targetPlayer,
        openGeneration,
        preloadBytes: effectivePreloadBytes,
        isHls: isHls,
      ),
    );
  }

  Future<void> _markFirstFrameRendered() async {
    try {
      await controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 8),
      );
      _updateState(
        (state) => state.copyWith(firstFrameRendered: true, buffering: false),
      );
    } catch (_) {
      // 部分平台不回报首帧；播放状态仍由 media_kit 流继续驱动。
    }
  }

  Future<void> _applyPreloadWindow(
    Player targetPlayer,
    int generation, {
    required int preloadBytes,
    required bool isHls,
  }) async {
    // HLS 的时长可能很长；把 cache-secs 扩展到整片会让后续 seek 等待
    // 大量切片，违背“定位后尽快恢复播放”的目标。
    if (isHls) return;
    try {
      final duration = await _waitForDuration(targetPlayer, generation);
      if (duration == null || generation != _openGeneration) return;
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        // 时长已知后把时间窗放开到整个媒体，预载深度完全由字节档位决定。
        final windowSeconds =
            duration.inMilliseconds / Duration.millisecondsPerSecond;
        await _setNativeProperty(
          platform,
          'cache-secs',
          windowSeconds.toStringAsFixed(3),
        );
        await _setNativeProperty(
          platform,
          'demuxer-max-bytes',
          '$preloadBytes',
        );
        await _logNativeCacheState(targetPlayer, 'duration-ready');
      }
    } catch (_) {
      // 部分流媒体无法及时提供总时长，继续使用兜底时间窗和字节档位播放。
    }
  }

  Future<Duration?> _waitForDuration(
    Player targetPlayer,
    int generation,
  ) async {
    // 轮询 state 而不是只订阅 duration 流。open() 可能在订阅前已经发出
    // 第一个有效时长事件,轮询可以覆盖 iOS 快速解析媒体的情况。
    for (var attempt = 0; attempt < 300; attempt++) {
      if (generation != _openGeneration) return null;
      try {
        final duration = targetPlayer.state.duration;
        if (duration > Duration.zero) return duration;
      } catch (_) {
        return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _ensureCacheOptionsAfterOpen(
    Player targetPlayer,
    int generation, {
    required int preloadBytes,
    required bool isHls,
  }) async {
    if (generation != _openGeneration) return;
    final platform = targetPlayer.platform;
    if (platform is! NativePlayer) return;

    final expected = <String, String>{
      'cache': 'yes',
      'cache-on-disk': 'no',
      'cache-secs': isHls
          ? '$playerHlsPreloadWindowSeconds'
          : '$playerPreloadWindowFallbackSeconds',
      'demuxer-max-bytes': '$preloadBytes',
      'demuxer-max-back-bytes': '$playerPreloadBackBufferBytes',
    };
    for (final entry in expected.entries) {
      if (generation != _openGeneration) return;
      await _ensureNativeProperty(platform, entry.key, entry.value);
    }
  }

  Future<void> _ensureNativeProperty(
    NativePlayer platform,
    String property,
    String requested,
  ) async {
    try {
      final actual = '${await (platform as dynamic).getProperty(property)}'
          .trim();
      if (_nativePropertyMatches(property, requested, actual)) return;
      _playerHostLog(
        'open 后重新应用 mpv 属性: '
        '$property requested=$requested actual=$actual',
      );
      await _setNativeProperty(platform, property, requested);
    } catch (error) {
      _playerHostLog('校验 mpv 属性失败: $property, $error');
    }
  }

  void _playerHostLog(String message) {
  if (!kReleaseMode) debugPrint('[PlayerControllerHost] $message');
}

Future<void> _logNativeCacheState(Player targetPlayer, String phase) async {
    // 缓冲属性轮询 + 日志仅用于排障,release 下跳过避免无谓的 getProperty 往返。
    if (kReleaseMode) return;
    final platform = targetPlayer.platform;
    if (platform is! NativePlayer) return;
    final native = platform as dynamic;
    try {
      final values = <String, String>{};
      for (final property in <String>[
        'cache-secs',
        'demuxer-max-bytes',
        'demuxer-max-back-bytes',
        'demuxer-cache-time',
        'cache-buffering-state',
      ]) {
        values[property] = '${await native.getProperty(property)}'.trim();
      }
      _playerHostLog(
        'mpv 缓冲状态 phase=$phase '
        'cache-secs=${values['cache-secs']} '
        'demuxer-max-bytes=${values['demuxer-max-bytes']} '
        'demuxer-max-back-bytes=${values['demuxer-max-back-bytes']} '
        'demuxer-cache-time=${values['demuxer-cache-time']} '
        'cache-buffering-state=${values['cache-buffering-state']}',
      );
    } catch (error) {
      _playerHostLog('读取 mpv 缓冲状态失败: $error');
    }
  }

  // NativePlayer 的 Web stub 没有 setProperty；实际 Web 播放器不会进入
  // NativePlayer 分支，使用 dynamic 仅让原生专用 API 保持可编译。
  Future<void> _setNativeProperty(
    NativePlayer platform,
    String property,
    String value,
  ) async {
    final native = platform as dynamic;
    Object? commandError;
    try {
      // `setProperty` 在 media_kit 1.2.x 不等待 mpv 的 native 命令完成。
      // 使用可等待的 `set` 命令，确保属性在下一次播放器操作前已经生效。
      await native.command(<String>['set', property, value]);
      if (await _waitForNativeProperty(native, property, value)) return;
    } catch (error) {
      commandError = error;
    }

    // 兼容较旧 native backend，或 command 返回但 mpv 没有接受属性的情况。
    Object? fallbackError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await native.setProperty(property, value);
        if (await _waitForNativeProperty(native, property, value)) return;
      } catch (error) {
        fallbackError = error;
      }
    }
    String actual = '';
    try {
      actual = '${await native.getProperty(property)}'.trim();
    } catch (_) {}
    _playerHostLog(
      'mpv 属性未生效: '
      '$property requested=$value actual=$actual '
      'command=$commandError fallback=$fallbackError',
    );
  }

  Future<bool> _waitForNativeProperty(
    dynamic native,
    String property,
    String requested,
  ) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final actual = '${await native.getProperty(property)}'.trim();
        if (_nativePropertyMatches(property, requested, actual)) return true;
      } catch (_) {}
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    return false;
  }

  bool _nativePropertyMatches(
    String property,
    String requested,
    String actual,
  ) {
    if (property == 'cache-secs') {
      final expectedValue = double.tryParse(requested);
      final actualValue = double.tryParse(actual);
      if (expectedValue != null && actualValue != null) {
        return (expectedValue - actualValue).abs() < 0.01;
      }
    }
    if (property == 'demuxer-max-bytes' ||
        property == 'demuxer-max-back-bytes') {
      final expectedValue = int.tryParse(requested);
      final actualValue = int.tryParse(actual);
      if (expectedValue != null && actualValue != null) {
        return expectedValue == actualValue;
      }
    }
    if (actual == requested) return true;
    return false;
  }

  /// 把已下载的字幕内容写入本地临时文件后交给 mpv 加载。
  ///
  /// mpv 的 sub-add 网络请求无法携带完整鉴权，失败报错还会混入错误流被
  /// 上层当成播放失败；改为客户端自行下载内容后本地加载，字幕接口返回
  /// 404/超时等失败只会抛出 Dart 异常，不会影响正在进行的播放。
  @override
  Future<void> setSubtitleData(
    String content, {
    String? title,
    String? language,
  }) async {
    final previous = _subtitleTempFile;
    final file = await _writeSubtitleTempFile(content);
    try {
      await player.setSubtitleTrack(
        SubtitleTrack.uri(
          file.uri.toString(),
          title: title,
          language: language,
        ),
      );
      _subtitleTempFile = file;
      await _setNativeSubtitleVisibility(false);
    } catch (error) {
      await _deleteQuietly(file);
      rethrow;
    }
    if (previous != null && previous.path != file.path) {
      await _deleteQuietly(previous);
    }
  }

  Future<File> _writeSubtitleTempFile(String content) async {
    final directory = await getTemporaryDirectory();
    // 带上 .vtt 扩展名让 mpv 按扩展名直接选定字幕 demuxer，不依赖内容探测。
    final name =
        'mdc-subtitle-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${_subtitleFileSeq++}.vtt';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // mpv 可能仍持有句柄，留给系统临时目录清理。
    }
  }

  @override
  Future<void> clearSubtitle() async {
    await player.setSubtitleTrack(SubtitleTrack.no());
    await _setNativeSubtitleVisibility(false);
  }

  @override
  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
    bool nativeRendering = false,
  }) async {
    final track = await _findSubtitleTrack(id, fallbackIndex);
    if (track == null) {
      throw StateError('未找到内嵌字幕轨道: $id');
    }
    await player.setSubtitleTrack(track);
    await _setNativeSubtitleVisibility(nativeRendering);
    _updateState((state) => state.copyWith(selectedSubtitleTrackId: track.id));
  }

  Future<void> _setNativeSubtitleVisibility(bool visible) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      await (platform as dynamic).setProperty(
        'sub-visibility',
        visible ? 'yes' : 'no',
      );
    } catch (_) {
      // Web and older native backends may not expose mpv properties.
    }
  }

  Future<SubtitleTrack?> _findSubtitleTrack(
    String id,
    int? fallbackIndex,
  ) async {
    SubtitleTrack? find(Tracks tracks) =>
        resolveSubtitleTrack(tracks.subtitle, id, fallbackIndex: fallbackIndex);

    var track = find(player.state.tracks);
    if (track != null || fallbackIndex == null) return track;

    try {
      final tracks = await player.stream.tracks
          .firstWhere((value) => find(value) != null)
          .timeout(const Duration(seconds: 5));
      track = find(tracks);
    } on TimeoutException {
      track = null;
    }
    return track;
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    final track = player.state.tracks.audio.firstWhere(
      (item) => item.id == id,
      orElse: AudioTrack.auto,
    );
    await player.setAudioTrack(track);
    _updateState((state) => state.copyWith(selectedAudioTrackId: track.id));
  }

  /// 重建播放器以应用硬解或播放缓冲配置。
  Future<void> recreate({
    required bool enableHardwareAcceleration,
    int? bufferSize,
  }) async {
    final nextBufferSize = bufferSize ?? this.bufferSize;
    if (hardwareAcceleration == enableHardwareAcceleration &&
        this.bufferSize == nextBufferSize) {
      return;
    }
    final previous = player;
    hardwareAcceleration = enableHardwareAcceleration;
    this.bufferSize = nextBufferSize;
    _createPlayer();
    _bindState();
    await previous.dispose();
  }

  @override
  Future<void> configure({
    bool? hardwareAcceleration,
    int? preloadBytes,
  }) async {
    if (preloadBytes != null) this.preloadBytes = preloadBytes;
    if (hardwareAcceleration != null) {
      await recreate(enableHardwareAcceleration: hardwareAcceleration);
    }
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  /// 停止当前媒体但保留播放器实例, 用于退出播放页前的停播。
  @override
  Future<void> stop() async {
    ++_openGeneration;
    await player.stop();
    _updateState(
      (state) => state.copyWith(
        lifecycle: PlaybackLifecycle.stopped,
        playing: false,
        buffering: false,
      ),
    );
  }

  @override
  Future<void> setRate(double rate) => player.setRate(rate);

  @override
  Future<void> playOrPause() => player.playOrPause();

  /// 当前播放位置 / 总时长 (同步快照)
  Duration get position => player.state.position;
  Duration get duration => player.state.duration;

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get completedStream => player.stream.completed;
  Stream<String> get errorStream => player.stream.error;

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    final seconds = delay.inMilliseconds / Duration.millisecondsPerSecond;
    await _setNativeProperty(platform, 'sub-delay', '$seconds');
  }

  @override
  Future<Uint8List?> captureFrame(
    Duration position, {
    String? sourceUrl,
    Map<String, String>? headers,
  }) async {
    final fallbackRequest = _openRequest;
    final url = sourceUrl?.trim().isNotEmpty == true
        ? sourceUrl!.trim()
        : fallbackRequest?.url;
    if (url == null || url.isEmpty) return null;
    final sourceHeaders = sourceUrl?.trim().isNotEmpty == true
        ? headers
        : fallbackRequest?.headers;
    final previewPlayer = await _ensurePreviewPlayer(
      url,
      sourceHeaders,
      position,
    );
    if (previewPlayer == null) return null;
    try {
      await previewPlayer.seek(position).timeout(const Duration(seconds: 2));
      await previewPlayer.play();
      for (var attempt = 0; attempt < 15; attempt++) {
        final frame = await previewPlayer
            .screenshot(format: 'image/jpeg')
            .timeout(const Duration(milliseconds: 400), onTimeout: () => null);
        if (frame != null && frame.isNotEmpty) return frame;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return null;
    } finally {
      try {
        await previewPlayer.pause();
      } catch (_) {}
    }
  }

  Future<Player?> _ensurePreviewPlayer(
    String url,
    Map<String, String>? headers,
    Duration startAt,
  ) async {
    if (_previewPlayer != null &&
        _previewSourceUrl == url &&
        mapEquals(_previewHeaders, headers)) {
      return _previewPlayer;
    }
    await _disposePreviewPlayer();
    final previewPlayer = Player(
      configuration: const PlayerConfiguration(
        muted: true,
        bufferSize: 8 * 1024 * 1024,
      ),
    );
    final previewController = VideoController(
      previewPlayer,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _previewPlayer = previewPlayer;
    _previewSourceUrl = url;
    _previewHeaders = headers == null
        ? null
        : Map<String, String>.from(headers);
    try {
      await previewPlayer
          .open(Media(url, httpHeaders: headers, start: startAt), play: true)
          .timeout(const Duration(seconds: 3));
      try {
        await previewController.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {}
      return previewPlayer;
    } catch (_) {
      await _disposePreviewPlayer();
      return null;
    }
  }

  Future<void> _disposePreviewPlayer() async {
    final previewPlayer = _previewPlayer;
    _previewPlayer = null;
    _previewSourceUrl = null;
    _previewHeaders = null;
    try {
      await previewPlayer?.dispose();
    } catch (_) {}
  }

  @override
  Future<void> clearFramePreview() => _disposePreviewPlayer();

  @override
  Future<bool> enterPictureInPicture(
    PlaybackPictureInPictureRequest request,
  ) async => false;

  @override
  Future<void> stopPictureInPicture() async {}

  @override
  Widget buildSurface({BoxFit fit = BoxFit.contain}) {
    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: fit,
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        visible: false,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    ++_openGeneration;
    for (final subscription in _stateSubscriptions) {
      await subscription.cancel();
    }
    _stateSubscriptions.clear();
    await _disposePreviewPlayer();
    final subtitleFile = _subtitleTempFile;
    _subtitleTempFile = null;
    await player.dispose();
    if (subtitleFile != null) await _deleteQuietly(subtitleFile);
    _state.dispose();
  }
}

bool _isHlsPlaybackUrl(String url, String? formatHint) {
  final hint = formatHint?.trim().toLowerCase() ?? '';
  if (hint == 'm3u8' || hint == 'hls' || hint.contains('mpegurl')) {
    return true;
  }
  final uri = Uri.tryParse(url.trim());
  final path = uri?.path.toLowerCase() ?? url.trim().toLowerCase();
  return path.endsWith('.m3u8');
}
