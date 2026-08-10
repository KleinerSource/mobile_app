/// 播放器自动恢复失败预算。
///
/// [recordFailure] 返回 true 表示还允许自动恢复，返回 false 表示已经达到
/// 失败上限，应停止播放器并把错误交给用户处理。
class PlaybackRetryPolicy {
  PlaybackRetryPolicy({this.maxFailures = 3})
      : assert(maxFailures > 0, 'maxFailures must be greater than zero');

  final int maxFailures;
  int _failures = 0;

  int get failures => _failures;

  bool recordFailure() {
    if (_failures >= maxFailures) return false;
    _failures++;
    return _failures < maxFailures;
  }

  void reset() {
    _failures = 0;
  }
}
