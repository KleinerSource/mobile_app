import 'dart:async';

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
    player = Player(
      configuration: PlayerConfiguration(bufferSize: bufferSize),
    );
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
    return _openWithBufferOptions(
      url,
      startAt: startAt,
      headers: headers,
    );
  }

  Future<void> _openWithBufferOptions(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    final openGeneration = ++_openGeneration;
    final targetPlayer = player;
    try {
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        // demuxer-cache-dir 必须在 cache-on-disk 创建文件前设置；否则 mpv
        // 会继续使用默认目录，缓存管理页统计不到实际文件。
        if (diskCacheEnabled && diskCacheDirectory != null) {
          await _setNativeProperty(
            platform,
            'demuxer-cache-dir',
            diskCacheDirectory!,
          );
        }
        // mpv 的磁盘缓存只有在显式启用网络缓存后才会生效。
        await _setNativeProperty(
          platform,
          'cache',
          diskCacheEnabled ? 'yes' : 'no',
        );
        await _setNativeProperty(
          platform,
          'cache-on-disk',
          diskCacheEnabled ? 'yes' : 'no',
        );
        // 先使用极小的安全预载值，等媒体时长就绪后再收敛到总时长的 15%，
        // 避免播放器在时长未知时按字节缓存过多内容。
        await _setNativeProperty(
          platform,
          'cache-secs',
          playerInitialPrefetchSeconds.toStringAsFixed(3),
        );
        // demuxer cache 本身是临时的；stream-record 才是由应用管理的
        // 持久化缓存，必须在打开媒体源前设置。
        await _setNativeProperty(
          platform,
          'stream-record',
          diskCacheEnabled && persistentCacheFile != null
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
    unawaited(_applyPrefetchLimit(targetPlayer, openGeneration));
  }

  Future<void> _applyPrefetchLimit(Player targetPlayer, int generation) async {
    try {
      var duration = targetPlayer.state.duration;
      if (duration <= Duration.zero) {
        duration = await targetPlayer.stream.duration
            .firstWhere((value) => value > Duration.zero)
            .timeout(const Duration(seconds: 5));
      }
      if (generation != _openGeneration) return;
      final platform = targetPlayer.platform;
      if (platform is NativePlayer) {
        await _setNativeProperty(
          platform,
          'cache-secs',
          playerPrefetchSecondsFor(duration).toStringAsFixed(3),
        );
      }
    } catch (_) {
      // 部分流媒体无法及时提供总时长或不支持 cache-secs，继续使用安全初始值播放。
    }
  }

  // NativePlayer 的 Web stub 没有 setProperty；实际 Web 播放器不会进入
  // NativePlayer 分支，使用 dynamic 仅让原生专用 API 保持可编译。
  Future<void> _setNativeProperty(
    NativePlayer platform,
    String property,
    String value,
  ) async {
    await (platform as dynamic).setProperty(property, value);
  }

  Future<void> setSubtitleUrl(
    String url, {
    String? title,
    String? language,
  }) {
    return player.setSubtitleTrack(
      SubtitleTrack.uri(url, title: title, language: language),
    );
  }

  Future<void> clearSubtitle() => player.setSubtitleTrack(SubtitleTrack.no());

  Future<void> setSubtitleTrackById(
    String id, {
    int? fallbackIndex,
  }) async {
    final track = await _findSubtitleTrack(id, fallbackIndex);
    if (track == null) {
      throw StateError('未找到内嵌字幕轨道: $id');
    }
    await player.setSubtitleTrack(track);
  }

  Future<SubtitleTrack?> _findSubtitleTrack(
    String id,
    int? fallbackIndex,
  ) async {
    SubtitleTrack? find(Tracks tracks) => resolveSubtitleTrack(
          tracks.subtitle,
          id,
          fallbackIndex: fallbackIndex,
        );

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
  Future<void> stop() => player.stop();

  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> playOrPause() => player.playOrPause();

  /// 当前播放位置 / 总时长 (同步快照)
  Duration get position => player.state.position;
  Duration get duration => player.state.duration;

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get completedStream => player.stream.completed;
  Stream<String> get errorStream => player.stream.error;

  Future<void> dispose() => player.dispose();
}
