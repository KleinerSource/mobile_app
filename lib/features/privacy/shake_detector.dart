import 'dart:math' as math;

/// 根据连续的加速度峰值识别一次摇动。
///
/// 传感器会在同一次摇动期间连续发出多个采样,因此只把高于阈值且
/// 已经回落后再次出现的峰值计入序列。连续完成多个峰值后才触发回调,
/// 轻微移动或单次晃动不会切换隐私模式。
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 15,
    this.requiredPeaks = 2,
    this.sequenceWindow = const Duration(milliseconds: 1800),
    this.cooldown = const Duration(seconds: 1),
    double? releaseThreshold,
  }) : releaseThreshold = releaseThreshold ?? threshold * 0.75;

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
      _sequenceStartedAt = timestamp;
      _peakCount = 1;
      return false;
    }

    _peakCount++;
    if (_peakCount < requiredPeaks) return false;

    _lastTriggeredAt = timestamp;
    _sequenceStartedAt = null;
    _peakCount = 0;
    onShake();
    return true;
  }

  void reset() {
    _lastTriggeredAt = null;
    _sequenceStartedAt = null;
    _peakCount = 0;
    _peakActive = false;
  }
}
