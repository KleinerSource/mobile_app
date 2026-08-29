import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/player/ks_player_seek_recovery.dart';
import 'package:omm/features/player/playback_engine.dart';

void main() {
  test('缓冲结束后停止观察', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 1),
        buffering: false,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.stop,
    );
  });

  test('缓冲窗口内每秒补发 play，窗口外只等待', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    for (final elapsed in [1, 3, 7]) {
      expect(
        policy.evaluate(
          elapsed: Duration(seconds: elapsed),
          buffering: true,
          lifecycle: PlaybackLifecycle.ready,
        ),
        KsPlayerSeekRecoveryAction.nudgePlay,
        reason: '第 $elapsed 秒仍缓冲应补发 play',
      );
    }
    for (final elapsed in [8, 15, 19]) {
      expect(
        policy.evaluate(
          elapsed: Duration(seconds: elapsed),
          buffering: true,
          lifecycle: PlaybackLifecycle.ready,
        ),
        KsPlayerSeekRecoveryAction.wait,
        reason: '第 $elapsed 秒已过补发窗口，只等待',
      );
    }
  });

  test('持续缓冲超过上限判定恢复失败', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 20),
        buffering: true,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.reportStalled,
    );
  });

  test('会话失效或已结束时停止观察，重新打开时等待', () {
    const policy = KsPlayerSeekRecoveryPolicy();
    for (final lifecycle in [
      PlaybackLifecycle.idle,
      PlaybackLifecycle.stopped,
      PlaybackLifecycle.failed,
      PlaybackLifecycle.completed,
    ]) {
      expect(
        policy.evaluate(
          elapsed: const Duration(seconds: 2),
          buffering: true,
          lifecycle: lifecycle,
        ),
        KsPlayerSeekRecoveryAction.stop,
        reason: '$lifecycle 会话已结束',
      );
    }
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 2),
        buffering: true,
        lifecycle: PlaybackLifecycle.opening,
      ),
      KsPlayerSeekRecoveryAction.wait,
    );
  });

  test('自定义窗口与上限参与判定', () {
    const policy = KsPlayerSeekRecoveryPolicy(
      nudgeWindow: Duration(seconds: 2),
      stallTimeout: Duration(seconds: 5),
    );
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 2),
        buffering: true,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.wait,
    );
    expect(
      policy.evaluate(
        elapsed: const Duration(seconds: 5),
        buffering: true,
        lifecycle: PlaybackLifecycle.ready,
      ),
      KsPlayerSeekRecoveryAction.reportStalled,
    );
  });
}
