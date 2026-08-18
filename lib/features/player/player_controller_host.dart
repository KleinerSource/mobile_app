import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'player_prefetch_policy.dart';
import 'player_subtitle_track_resolver.dart';

/// media_kit 内核封装 · libmpv (内置 ffmpeg 软解 + VideoToolbox 硬解)
///
/// 把命令式播放 API + 状态流收拢到一个对象, 供 PlayerPage 编排。
/// PlayerPage 只通过本类的方法/getter 访问内核, 不直接接触 media_kit 类型。
class PlayerControllerHost {
  PlayerControllerHost({
    this.hardwareAcceleration = true,
    this.bufferSize = 32 * 1024 * 1024,
    this.diskCacheEnabled = true,
  }) {
    _createPlayer();
  }

  late Player player;
  late VideoController controller;
  bool hardwareAcceleration;
  int bufferSize;
  bool diskCacheEnabled;
  String? diskCacheDirectory;
  String? persistentCacheFile;
  int _openGeneration = 0;

  void _createPlayer() {
    player = Player(configuration: PlayerConfiguration(bufferSize: bufferSize));
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: hardwareAcceleration,
      ),
    );
  }

  /// 打开网络源并起播 · [startAt] 为起播定位 (续播 / 切源保位)
  Future<void> open(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
    double? prefetchSeconds,
    bool recordCache = true,
  }) {
    return _openWithBufferOptions(
      url,
      startAt: startAt,
      headers: headers,
      prefetchSeconds: prefetchSeconds,
      recordCache: recordCache,
    );
  }

  Future<void> _openWithBufferOptions(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
    double? prefetchSeconds,
    required bool recordCache,
  }) async {
    final openGeneration = ++_openGeneration;
    final targetPlayer = player;
    final requestedPrefetchSeconds =
        prefetchSeconds != null &&
            prefetchSeconds.isFinite &&
            prefetchSeconds > 0
        ? prefetchSeconds
        : playerInitialPrefetchSeconds;
    try {
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        // Player.open() 也会 stop,但它是在本方法设置 stream-record 之后才
        // 执行。先关闭旧媒体，避免新录制文件先按旧媒体的封装格式打开。
        if (persistentCacheFile != null) {
          await _setNativeProperty(platform, 'stream-record', '');
        }
        try {
          await targetPlayer.stop();
        } catch (error) {
          debugPrint('[PlayerControllerHost] 关闭旧媒体失败，继续应用缓存配置: $error');
        }
        // demuxer-cache-dir 必须在 cache-on-disk 创建文件前设置；否则 mpv
        // 会继续使用默认目录，缓存管理页统计不到实际文件。
        if (diskCacheEnabled && diskCacheDirectory != null) {
          await _setNativeProperty(
            platform,
            'demuxer-cache-dir',
            diskCacheDirectory!,
          );
        }
        // 网络 demuxer 缓冲与持久化磁盘缓存是两条独立能力。即使用户
        // 关闭磁盘缓存，也必须保留 cache=yes，否则 cache-secs 会完全失效。
        await _setNativeProperty(platform, 'cache', 'yes');
        await _setNativeProperty(
          platform,
          'cache-on-disk',
          diskCacheEnabled ? 'yes' : 'no',
        );
        // cache-secs 只是后台预载上限。显式进入初始 buffering，才能让
        // 起播前确实先读取一段数据；等待时间封顶，避免长视频打开数分钟。
        await _setNativeProperty(platform, 'cache-pause', 'yes');
        await _setNativeProperty(platform, 'cache-pause-initial', 'yes');
        await _setNativeProperty(
          platform,
          'cache-pause-wait',
          playerInitialCacheWaitSecondsFor(
            requestedPrefetchSeconds,
          ).toStringAsFixed(3),
        );
        // 先使用极小的安全预载值，等媒体时长就绪后再收敛到总时长的 15%，
        // 避免播放器在时长未知时按字节缓存过多内容。
        await _setNativeProperty(
          platform,
          'cache-secs',
          requestedPrefetchSeconds.toStringAsFixed(3),
        );
        // stream-record 必须在 loadfile 前设置，才能从网络源的第一段数据开始
        // 写入；输出扩展名由调用方按播放路线选择，避免 HLS 被当成 MP4 封装。
        await _setNativeProperty(
          platform,
          'stream-record',
          recordCache && diskCacheEnabled && persistentCacheFile != null
              ? persistentCacheFile!
              : '',
        );
      }
    } catch (_) {
      // 部分平台的 mpv 构建不允许运行时修改缓存选项，仍继续正常播放。
    }
    await targetPlayer.open(
      Media(url, start: startAt, httpHeaders: headers),
      play: true,
    );
    // Player.open() 内部会先 stop 再 loadlist。部分 iOS/libmpv 版本会在
    // 这个边界重新应用默认缓存选项，因此 open 完成后再次回读并补设。
    // cache-secs 在此处先用已知的决策值，时长未知时再由下方轮询收敛。
    await _ensureCacheOptionsAfterOpen(
      targetPlayer,
      openGeneration,
      prefetchSeconds: requestedPrefetchSeconds,
      recordCache: recordCache,
    );
    await _logNativeCacheState(targetPlayer, 'open');
    // NativePlayer.open() 通过异步 loadlist 加载媒体。部分 iOS/libmpv
    // 版本会在真正开始载入文件时重置 per-file 的 stream-record，因此在
    // loadlist 完成后再做一次延迟校验，确保录制目标仍然指向持久缓存文件。
    unawaited(
      _rearmPersistentRecording(
        targetPlayer,
        openGeneration,
        recordCache: recordCache,
      ),
    );
    unawaited(_applyPrefetchLimit(targetPlayer, openGeneration));
  }

  Future<void> _rearmPersistentRecording(
    Player targetPlayer,
    int generation, {
    required bool recordCache,
  }) async {
    final path = persistentCacheFile;
    if (!recordCache || !diskCacheEnabled || path == null || path.isEmpty) {
      return;
    }

    for (final delay in <Duration>[
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 750),
      const Duration(milliseconds: 1500),
    ]) {
      await Future<void>.delayed(delay);
      if (generation != _openGeneration) return;
      final platform = targetPlayer.platform;
      if (platform is! NativePlayer) return;
      try {
        final native = platform as dynamic;
        final actual = '${await native.getProperty('stream-record')}'.trim();
        if (_nativePropertyMatches('stream-record', path, actual)) continue;
        debugPrint(
          '[PlayerControllerHost] 媒体加载后重新启用持久缓存: '
          'requested=$path actual=$actual',
        );
        await _setNativeProperty(platform, 'stream-record', path);
        await _logNativeCacheState(targetPlayer, 'record-rearmed');
      } catch (error) {
        debugPrint('[PlayerControllerHost] 重启持久缓存失败: $error');
      }
    }
  }

  Future<void> _applyPrefetchLimit(Player targetPlayer, int generation) async {
    try {
      final duration = await _waitForDuration(targetPlayer, generation);
      if (duration == null || generation != _openGeneration) return;
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        final prefetchSeconds = playerPrefetchSecondsFor(duration);
        await _setNativeProperty(
          platform,
          'cache-secs',
          prefetchSeconds.toStringAsFixed(3),
        );
        await _setNativeProperty(
          platform,
          'cache-pause-wait',
          playerInitialCacheWaitSecondsFor(prefetchSeconds).toStringAsFixed(3),
        );
        await _logNativeCacheState(targetPlayer, 'duration-ready');
      }
    } catch (_) {
      // 部分流媒体无法及时提供总时长或不支持 cache-secs，继续使用安全初始值播放。
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
    required double prefetchSeconds,
    required bool recordCache,
  }) async {
    if (generation != _openGeneration) return;
    final platform = targetPlayer.platform;
    if (platform is! NativePlayer) return;

    final expected = <String, String>{
      'cache': 'yes',
      'cache-on-disk': diskCacheEnabled ? 'yes' : 'no',
      'cache-pause': 'yes',
      'cache-pause-initial': 'yes',
      'cache-pause-wait': playerInitialCacheWaitSecondsFor(
        prefetchSeconds,
      ).toStringAsFixed(3),
      if (diskCacheEnabled && diskCacheDirectory != null)
        'demuxer-cache-dir': diskCacheDirectory!,
      'cache-secs': prefetchSeconds.toStringAsFixed(3),
      'stream-record':
          recordCache && diskCacheEnabled && persistentCacheFile != null
          ? persistentCacheFile!
          : '',
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
      debugPrint(
        '[PlayerControllerHost] open 后重新应用 mpv 属性: '
        '$property requested=$requested actual=$actual',
      );
      await _setNativeProperty(platform, property, requested);
    } catch (error) {
      debugPrint('[PlayerControllerHost] 校验 mpv 属性失败: $property, $error');
    }
  }

  Future<void> _logNativeCacheState(Player targetPlayer, String phase) async {
    final platform = targetPlayer.platform;
    if (platform is! NativePlayer) return;
    final native = platform as dynamic;
    try {
      final values = <String, String>{};
      for (final property in <String>[
        'file-format',
        'cache-secs',
        'demuxer-cache-time',
        'cache-buffering-state',
        'cache-on-disk',
        'stream-record',
      ]) {
        values[property] = '${await native.getProperty(property)}'.trim();
      }
      debugPrint(
        '[PlayerControllerHost] mpv 缓存状态 phase=$phase '
        'file-format=${values['file-format']} '
        'cache-secs=${values['cache-secs']} '
        'demuxer-cache-time=${values['demuxer-cache-time']} '
        'cache-buffering-state=${values['cache-buffering-state']} '
        'cache-on-disk=${values['cache-on-disk']} '
        'stream-record=${values['stream-record']}',
      );
    } catch (error) {
      debugPrint('[PlayerControllerHost] 读取 mpv 缓存状态失败: $error');
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
      // 使用可等待的 `set` 命令，避免 stream-record 清空与 stop 竞态。
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
    debugPrint(
      '[PlayerControllerHost] mpv 属性未生效: '
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
    if (actual == requested) return true;
    if (property == 'stream-record' || property == 'demuxer-cache-dir') {
      return requested.isNotEmpty && actual.endsWith(requested);
    }
    return false;
  }

  Future<void> setSubtitleUrl(
    String url, {
    String? title,
    String? language,
  }) async {
    await player.setSubtitleTrack(
      SubtitleTrack.uri(url, title: title, language: language),
    );
    await _setNativeSubtitleVisibility(false);
  }

  Future<void> clearSubtitle() async {
    await player.setSubtitleTrack(SubtitleTrack.no());
    await _setNativeSubtitleVisibility(false);
  }

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

  Future<void> setAudioTrackById(String id) async {
    final track = player.state.tracks.audio.firstWhere(
      (item) => item.id == id,
      orElse: AudioTrack.auto,
    );
    await player.setAudioTrack(track);
  }

  /// 重建播放器以应用硬解或播放缓冲配置。
  Future<void> recreate({
    required bool enableHardwareAcceleration,
    int? bufferSize,
    bool? diskCacheEnabled,
    String? diskCacheDirectory,
    String? persistentCacheFile,
  }) async {
    final nextBufferSize = bufferSize ?? this.bufferSize;
    final nextDiskCacheEnabled = diskCacheEnabled ?? this.diskCacheEnabled;
    final nextDiskCacheDirectory =
        diskCacheDirectory ?? this.diskCacheDirectory;
    final nextPersistentCacheFile =
        persistentCacheFile ?? this.persistentCacheFile;
    if (hardwareAcceleration == enableHardwareAcceleration &&
        this.bufferSize == nextBufferSize &&
        this.diskCacheEnabled == nextDiskCacheEnabled &&
        this.diskCacheDirectory == nextDiskCacheDirectory &&
        this.persistentCacheFile == nextPersistentCacheFile) {
      return;
    }
    final previous = player;
    hardwareAcceleration = enableHardwareAcceleration;
    this.bufferSize = nextBufferSize;
    this.diskCacheEnabled = nextDiskCacheEnabled;
    this.diskCacheDirectory = nextDiskCacheDirectory;
    this.persistentCacheFile = nextPersistentCacheFile;
    _createPlayer();
    await previous.dispose();
  }

  Future<void> seek(Duration position) => player.seek(position);

  /// 停止当前媒体但保留播放器实例, 用于退出播放页前的同步停播。
  Future<void> stop() async {
    ++_openGeneration;
    final targetPlayer = player;
    final platform = targetPlayer.platform;
    if (platform is NativePlayer && persistentCacheFile != null) {
      // mpv 在修改 stream-record 时会先关闭旧文件。显式清空一次，确保
      // 文件在播放器 stop 完成前已经 flush，缓存统计不会读到 0 字节。
      await _setNativeProperty(platform, 'stream-record', '');
    }
    await targetPlayer.stop();
  }

  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> playOrPause() => player.playOrPause();

  /// 当前播放位置 / 总时长 (同步快照)
  Duration get position => player.state.position;
  Duration get duration => player.state.duration;

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get completedStream => player.stream.completed;
  Stream<String> get errorStream => player.stream.error;

  Future<void> dispose() async {
    ++_openGeneration;
    await player.dispose();
  }
}
