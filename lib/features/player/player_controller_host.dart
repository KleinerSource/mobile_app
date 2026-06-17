import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// media_kit 内核封装 · libmpv (内置 ffmpeg 软解 + VideoToolbox 硬解)
///
/// 把命令式播放 API + 状态流收拢到一个对象, 供 PlayerPage 编排。
/// PlayerPage 只通过本类的方法/getter 访问内核, 不直接接触 media_kit 类型。
class PlayerControllerHost {
  final Player player = Player();
  late final VideoController controller = VideoController(
    player,
    // enableHardwareAcceleration 默认 true → iOS 走 VideoToolbox 硬解
    configuration: const VideoControllerConfiguration(),
  );

  /// 打开网络源并起播 · [startAt] 为起播定位 (续播 / 切源保位)
  Future<void> open(String url, {Duration? startAt}) {
    return player.open(
      Media(url, start: startAt),
      play: true,
    );
  }

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> playOrPause() => player.playOrPause();

  /// 当前播放位置 / 总时长 (同步快照)
  Duration get position => player.state.position;
  Duration get duration => player.state.duration;

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get completedStream => player.stream.completed;

  Future<void> dispose() => player.dispose();
}
