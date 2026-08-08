import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// media_kit 内核封装 · libmpv (内置 ffmpeg 软解 + VideoToolbox 硬解)
///
/// 把命令式播放 API + 状态流收拢到一个对象, 供 PlayerPage 编排。
/// PlayerPage 只通过本类的方法/getter 访问内核, 不直接接触 media_kit 类型。
class PlayerControllerHost {
  PlayerControllerHost({this.hardwareAcceleration = true}) {
    _createPlayer();
  }

  late Player player;
  late VideoController controller;
  bool hardwareAcceleration;

  void _createPlayer() {
    player = Player();
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
    return player.open(
      Media(url, start: startAt, httpHeaders: headers),
      play: true,
    );
  }

  Future<void> setSubtitleUrl(String url) =>
      player.setSubtitleTrack(SubtitleTrack.uri(url));

  Future<void> clearSubtitle() => player.setSubtitleTrack(SubtitleTrack.no());

  Future<void> setSubtitleTrackById(String id) async {
    final track = player.state.tracks.subtitle.firstWhere(
      (item) => item.id == id,
      orElse: SubtitleTrack.auto,
    );
    await player.setSubtitleTrack(track);
  }

  Future<void> setAudioTrackById(String id) async {
    final track = player.state.tracks.audio.firstWhere(
      (item) => item.id == id,
      orElse: AudioTrack.auto,
    );
    await player.setAudioTrack(track);
  }

  /// 硬解失败时重建视频输出，保留播放器外的页面状态。
  Future<void> recreate({required bool enableHardwareAcceleration}) async {
    if (hardwareAcceleration == enableHardwareAcceleration) return;
    final previous = player;
    hardwareAcceleration = enableHardwareAcceleration;
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
