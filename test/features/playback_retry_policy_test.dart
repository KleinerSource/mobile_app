import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/player/playback_retry_policy.dart';

void main() {
  test('连续三次播放失败后停止自动恢复', () {
    final policy = PlaybackRetryPolicy();

    expect(policy.recordFailure(), isTrue);
    expect(policy.recordFailure(), isTrue);
    expect(policy.recordFailure(), isFalse);
    expect(policy.failures, 3);
    expect(policy.recordFailure(), isFalse);
  });

  test('用户重新加载后失败预算清零', () {
    final policy = PlaybackRetryPolicy();

    policy.recordFailure();
    policy.recordFailure();
    policy.reset();

    expect(policy.failures, 0);
    expect(policy.recordFailure(), isTrue);
  });
}
