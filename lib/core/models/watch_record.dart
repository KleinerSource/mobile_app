import 'package:flutter/foundation.dart';

@immutable
class WatchRecord {
  const WatchRecord({
    required this.lastPositionSec,
    required this.durationSec,
    required this.completed,
  });

  final double lastPositionSec;
  final double durationSec;
  final bool completed;

  factory WatchRecord.fromJson(Map<String, dynamic> json) {
    return WatchRecord(
      lastPositionSec: _asDouble(json['last_position_sec']),
      durationSec: _asDouble(json['duration_sec']),
      completed: json['completed'] == true || json['ended'] == true,
    );
  }

  /// 已完成影片从头播放；其余情况恢复到服务端最后保存的位置。
  int get resumePositionSec {
    if (completed || lastPositionSec <= 0) return 0;
    final position = durationSec > 0
        ? lastPositionSec.clamp(0, durationSec).toDouble()
        : lastPositionSec;
    return position.round();
  }
}

double _asDouble(Object? value) {
  return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
