import 'package:flutter/foundation.dart';

@immutable
class ResourceScanStartResult {
  const ResourceScanStartResult({
    required this.taskId,
    required this.acceptedCount,
    required this.skippedCount,
    required this.skippedIds,
  });

  final String taskId;
  final int acceptedCount;
  final int skippedCount;
  final List<int> skippedIds;

  factory ResourceScanStartResult.fromJson(Map<String, dynamic> json) {
    return ResourceScanStartResult(
      taskId: (json['task_id'] ?? '').toString(),
      acceptedCount: _intValue(json['accepted_count']),
      skippedCount: _intValue(json['skipped_count']),
      skippedIds: _intList(json['skipped_ids']),
    );
  }
}

@immutable
class ResourceScanTask {
  const ResourceScanTask({
    required this.taskId,
    required this.status,
    required this.movieIds,
    required this.totalCount,
    required this.currentIndex,
    required this.currentMovie,
    required this.successCount,
    required this.failedCount,
    required this.newMovieCount,
    required this.errors,
    this.startTime,
    this.endTime,
  });

  final String taskId;
  final String status;
  final List<int> movieIds;
  final int totalCount;
  final int currentIndex;
  final String currentMovie;
  final int successCount;
  final int failedCount;
  final int newMovieCount;
  final List<String> errors;
  final DateTime? startTime;
  final DateTime? endTime;

  factory ResourceScanTask.fromJson(Map<String, dynamic> json) {
    return ResourceScanTask(
      taskId: (json['task_id'] ?? '').toString(),
      status: (json['status'] ?? 'idle').toString(),
      movieIds: _intList(json['movie_ids']),
      totalCount: _intValue(json['total_count']),
      currentIndex: _intValue(json['current_index']),
      currentMovie: (json['current_movie'] ?? '').toString(),
      successCount: _intValue(json['success_count']),
      failedCount: _intValue(json['failed_count']),
      newMovieCount: _intValue(json['new_movie_count']),
      errors: (json['errors'] is List)
          ? (json['errors'] as List).map((value) => value.toString()).toList()
          : const <String>[],
      startTime: _dateTimeValue(json['start_time']),
      endTime: _dateTimeValue(json['end_time']),
    );
  }

  bool get isActive => status == 'idle' || status == 'running';

  bool get isCompleted => status == 'completed';

  double get progressRatio {
    if (totalCount <= 0) return isActive ? 0 : 1;
    return (currentIndex / totalCount).clamp(0.0, 1.0);
  }
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<int> _intList(dynamic value) {
  if (value is! List) return const <int>[];
  return value
      .map(_intValue)
      .where((item) => item > 0)
      .toList(growable: false);
}

DateTime? _dateTimeValue(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
