import 'dart:math' as math;

/// 根据连续的线性加速度峰值识别一次摇动。
///
/// 传感器会在同一次摇动期间连续发出多个采样,因此只把高于阈值且
/// 已经回落后再次出现、且方向与上一次峰值相反的采样计入序列。
/// 连续完成多个反向峰值后才触发回调,轻微移动、走路或单次晃动不会
/// 切换隐私模式。
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 9,
    this.requiredPeaks = 3,
    this.sequenceWindow = const Duration(seconds: 1),
    this.cooldown = const Duration(seconds: 1),
    this.directionChangeCosine = -0.25,
    double? releaseThreshold,
  }) : releaseThreshold = releaseThreshold ?? threshold * 0.45;

  final void Function() onShake;
  final double threshold;
  final int requiredPeaks;
  final Duration sequenceWindow;
  final Duration cooldown;
  final double releaseThreshold;
  final double directionChangeCosine;

  DateTime? _lastTriggeredAt;
  DateTime? _sequenceStartedAt;
  int _peakCount = 0;
  bool _peakActive = false;
  double? _lastPeakX;
  double? _lastPeakY;
  double? _lastPeakZ;
  double? _lastPeakMagnitude;

  bool handle({
    required double x,
    required double y,
    required double z,
    DateTime? now,
  }) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    final timestamp = now ?? DateTime.now();

    // 必须先回落到释放阈值以下,下一次升高才算新的摇动峰值。
    if (magnitude <= releaseThreshold) {
      _peakActive = false;
      return false;
    }
    if (magnitude < threshold || _peakActive) return false;
    _peakActive = true;

    final previous = _lastTriggeredAt;
    if (previous != null && timestamp.difference(previous) < cooldown) {
      return false;
    }

    final sequenceStart = _sequenceStartedAt;
    if (sequenceStart == null ||
        timestamp.difference(sequenceStart) > sequenceWindow) {
      _startSequence(timestamp, x, y, z, magnitude);
      return false;
    }

    if (!_isOppositeDirection(x, y, z, magnitude)) {
      _startSequence(timestamp, x, y, z, magnitude);
      return false;
    }

    _peakCount++;
    _rememberPeak(x, y, z, magnitude);
    if (_peakCount < requiredPeaks) return false;

    _lastTriggeredAt = timestamp;
    _clearSequence();
    onShake();
    return true;
  }

  bool _isOppositeDirection(
    double x,
    double y,
    double z,
    double magnitude,
  ) {
    final lastX = _lastPeakX;
    final lastY = _lastPeakY;
    final lastZ = _lastPeakZ;
    final lastMagnitude = _lastPeakMagnitude;
    if (lastX == null ||
        lastY == null ||
        lastZ == null ||
        lastMagnitude == null) {
      return false;
    }

    final cosine =
        (x * lastX + y * lastY + z * lastZ) / (magnitude * lastMagnitude);
    return cosine <= directionChangeCosine;
  }

  void _startSequence(
    DateTime timestamp,
    double x,
    double y,
    double z,
    double magnitude,
  ) {
    _sequenceStartedAt = timestamp;
    _peakCount = 1;
    _rememberPeak(x, y, z, magnitude);
  }

  void _rememberPeak(double x, double y, double z, double magnitude) {
    _lastPeakX = x;
    _lastPeakY = y;
    _lastPeakZ = z;
    _lastPeakMagnitude = magnitude;
  }

  void _clearSequence() {
    _sequenceStartedAt = null;
    _peakCount = 0;
    _lastPeakX = null;
    _lastPeakY = null;
    _lastPeakZ = null;
    _lastPeakMagnitude = null;
  }

  void reset() {
    _lastTriggeredAt = null;
    _clearSequence();
    _peakActive = false;
  }
}
