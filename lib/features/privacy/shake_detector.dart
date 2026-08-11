/// 根据连续的横向线性加速度峰值识别一次摇动。
///
/// 只使用设备 X 轴判定横向摇晃,Y/Z 轴的纵向和前后移动不会参与。
/// 横向加速度回落后再次出现、且方向与上一次峰值相反时才计入序列。
/// 连续完成多个反向峰值后才触发回调,轻微移动、走路或单次晃动不会
/// 切换隐私模式。
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 9,
    this.requiredPeaks = 3,
    this.sequenceWindow = const Duration(seconds: 1),
    this.cooldown = const Duration(seconds: 1),
    double? releaseThreshold,
  }) : releaseThreshold = releaseThreshold ?? threshold * 0.45;

  final void Function() onShake;
  final double threshold;
  final int requiredPeaks;
  final Duration sequenceWindow;
  final Duration cooldown;
  final double releaseThreshold;

  DateTime? _lastTriggeredAt;
  DateTime? _sequenceStartedAt;
  int _peakCount = 0;
  bool _peakActive = false;
  double? _lastPeakX;

  bool handle({
    required double x,
    required double y,
    required double z,
    DateTime? now,
  }) {
    final lateralAcceleration = x.abs();
    final timestamp = now ?? DateTime.now();

    // 必须先回落到释放阈值以下,下一次升高才算新的摇动峰值。
    if (lateralAcceleration <= releaseThreshold) {
      _peakActive = false;
      return false;
    }
    if (lateralAcceleration < threshold || _peakActive) return false;
    _peakActive = true;

    final previous = _lastTriggeredAt;
    if (previous != null && timestamp.difference(previous) < cooldown) {
      return false;
    }

    final sequenceStart = _sequenceStartedAt;
    if (sequenceStart == null ||
        timestamp.difference(sequenceStart) > sequenceWindow) {
      _startSequence(timestamp, x);
      return false;
    }

    if (!_isOppositeDirection(x)) {
      _startSequence(timestamp, x);
      return false;
    }

    _peakCount++;
    _lastPeakX = x;
    if (_peakCount < requiredPeaks) return false;

    _lastTriggeredAt = timestamp;
    _clearSequence();
    onShake();
    return true;
  }

  bool _isOppositeDirection(double x) {
    final lastX = _lastPeakX;
    return lastX != null && x * lastX < 0;
  }

  void _startSequence(DateTime timestamp, double x) {
    _sequenceStartedAt = timestamp;
    _peakCount = 1;
    _lastPeakX = x;
  }

  void _clearSequence() {
    _sequenceStartedAt = null;
    _peakCount = 0;
    _lastPeakX = null;
  }

  void reset() {
    _lastTriggeredAt = null;
    _clearSequence();
    _peakActive = false;
  }
}
