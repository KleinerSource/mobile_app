import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import 'player_subtitle_track_resolver.dart';

/// 后向（已播放）demuxer 缓冲上限，固定值：既服务回看拖动，也把最坏
/// native 内存约束为 预载档位 + 64 MiB，远离 iOS Jetsam 限额。
const playerPreloadBackBufferBytes = 64 * 1024 * 1024;

/// 媒体时长未知时的预读时间窗兜底；实际预载深度由字节档位约束。
const playerPreloadWindowFallbackSeconds = 3600;

/// media_kit 内核封装 · libmpv (内置 ffmpeg 软解 + VideoToolbox 硬解)
///
/// 把命令式播放 API + 状态流收拢到一个对象, 供 PlayerPage 编排。
/// PlayerPage 只通过本类的方法/getter 访问内核, 不直接接触 media_kit 类型。
class PlayerControllerHost {
  PlayerControllerHost({
    this.hardwareAcceleration = true,
    this.bufferSize = 32 * 1024 * 1024,
  }) {
    _createPlayer();
  }

  late Player player;
  late VideoController controller;
  bool hardwareAcceleration;
  int bufferSize;

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

  /// 打开网络源并起播 · [startAt] 为起播定位 (续播 / 切源保位)
  Future<void> open(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) {
    return _openWithBufferOptions(url, startAt: startAt, headers: headers);
  }

  Future<void> _openWithBufferOptions(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    final openGeneration = ++_openGeneration;
    final targetPlayer = player;
    final targetPreloadBytes = preloadBytes;
    try {
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        try {
          await targetPlayer.stop();
        } catch (error) {
          debugPrint('[PlayerControllerHost] 关闭旧媒体失败，继续应用缓冲配置: $error');
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
          '$playerPreloadWindowFallbackSeconds',
        );
        await _setNativeProperty(
          platform,
          'demuxer-max-bytes',
          '$targetPreloadBytes',
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
      play: true,
    );
    // Player.open() 内部会先 stop 再 loadlist，open 完成后回读确认缓冲
    // 属性仍然生效，避免媒体加载边界覆盖运行时配置。
    await _ensureCacheOptionsAfterOpen(
      targetPlayer,
      openGeneration,
      preloadBytes: targetPreloadBytes,
    );
    await _logNativeCacheState(targetPlayer, 'open');
    unawaited(
      _applyPreloadWindow(
        targetPlayer,
        openGeneration,
        preloadBytes: targetPreloadBytes,
      ),
    );
  }

  Future<void> _applyPreloadWindow(
    Player targetPlayer,
    int generation, {
    required int preloadBytes,
  }) async {
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
  }) async {
    if (generation != _openGeneration) return;
    final platform = targetPlayer.platform;
    if (platform is! NativePlayer) return;

    final expected = <String, String>{
      'cache': 'yes',
      'cache-on-disk': 'no',
      'cache-secs': '$playerPreloadWindowFallbackSeconds',
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
        'cache-secs',
        'demuxer-max-bytes',
        'demuxer-max-back-bytes',
        'demuxer-cache-time',
        'cache-buffering-state',
      ]) {
        values[property] = '${await native.getProperty(property)}'.trim();
      }
      debugPrint(
        '[PlayerControllerHost] mpv 缓冲状态 phase=$phase '
        'cache-secs=${values['cache-secs']} '
        'demuxer-max-bytes=${values['demuxer-max-bytes']} '
        'demuxer-max-back-bytes=${values['demuxer-max-back-bytes']} '
        'demuxer-cache-time=${values['demuxer-cache-time']} '
        'cache-buffering-state=${values['cache-buffering-state']}',
      );
    } catch (error) {
      debugPrint('[PlayerControllerHost] 读取 mpv 缓冲状态失败: $error');
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
    await previous.dispose();
  }

  Future<void> seek(Duration position) => player.seek(position);

  /// 停止当前媒体但保留播放器实例, 用于退出播放页前的停播。
  Future<void> stop() async {
    ++_openGeneration;
    await player.stop();
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
    final subtitleFile = _subtitleTempFile;
    _subtitleTempFile = null;
    await player.dispose();
    if (subtitleFile != null) await _deleteQuietly(subtitleFile);
  }
}
