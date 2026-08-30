import '../common/playback_engine.dart';

/// KSPlayer 定位后恢复观察的动作。
enum KsPlayerSeekRecoveryAction {
  /// 播放已恢复或会话已失效，停止观察。
  stop,

  /// 仍在缓冲且处于补发窗口内，再推一次 play 恢复解码。
  nudgePlay,

  /// 缓冲持续超过定位恢复上限，应向页面报告播放失败。
  reportStalled,

  /// 会话状态尚在变化（例如重新打开），继续等待但不补发。
  wait,
}

/// KSPlayer 定位后的恢复决策（纯逻辑，便于单测）。
///
/// KSAVPlayer 在长距离 HLS 定位后可能停在“持续下载但不再驱动解码”的
/// 状态：目标分片拉取受阻时 seek completion 可能不回调，缓冲 KVO 也不
/// 再把 loadState 推回 playable，画面便永远停在转圈。此策略按定位后经过
/// 的时间与统一状态决定补发 play 或上报失败，与 libmpv 引擎的
/// paused-for-cache 恢复逻辑保持同一套语义。
class KsPlayerSeekRecoveryPolicy {
  const KsPlayerSeekRecoveryPolicy({
    this.nudgeWindow = const Duration(seconds: 8),
    this.stallTimeout = const Duration(seconds: 20),
  });

  /// 定位后在此窗口内每秒补发一次 play。
  final Duration nudgeWindow;

  /// 仍处于缓冲则判定定位恢复失败的上限时长。
  final Duration stallTimeout;

  KsPlayerSeekRecoveryAction evaluate({
    required Duration elapsed,
    required bool buffering,
    required PlaybackLifecycle lifecycle,
  }) {
    switch (lifecycle) {
      case PlaybackLifecycle.opening:
        return KsPlayerSeekRecoveryAction.wait;
      case PlaybackLifecycle.idle:
      case PlaybackLifecycle.stopped:
      case PlaybackLifecycle.failed:
      case PlaybackLifecycle.completed:
        return KsPlayerSeekRecoveryAction.stop;
      case PlaybackLifecycle.ready:
        if (!buffering) {
          return KsPlayerSeekRecoveryAction.stop;
        }
        if (elapsed >= stallTimeout) {
          return KsPlayerSeekRecoveryAction.reportStalled;
        }
        return elapsed < nudgeWindow
            ? KsPlayerSeekRecoveryAction.nudgePlay
            : KsPlayerSeekRecoveryAction.wait;
    }
  }
}
