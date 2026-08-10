import 'dart:math' as math;

/// 根据加速度峰值识别一次摇动。
///
/// 传感器会在同一次摇动期间连续发出多个高值采样,因此使用冷却时间
/// 将一次物理操作限制为一次回调。
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 17,
    this.cooldown = const Duration(seconds: 1),
  });

  final void Function() onShake;
  final double threshold;
  final Duration cooldown;

  DateTime? _lastTriggeredAt;

  bool handle({
    required double x,
    required double y,
    required double z,
    DateTime? now,
  }) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;

    final timestamp = now ?? DateTime.now();
    final previous = _lastTriggeredAt;
    if (previous != null && timestamp.difference(previous) < cooldown) {
      return false;
    }

    _lastTriggeredAt = timestamp;
    onShake();
    return true;
  }

  void reset() {
    _lastTriggeredAt = null;
  }
}
