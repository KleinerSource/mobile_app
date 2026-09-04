import 'package:flutter/foundation.dart';

@immutable
class PreviewAssetStatus {
  const PreviewAssetStatus({
    this.ready = false,
    this.url = '',
    this.size = 0,
    this.updatedAt,
  });

  final bool ready;
  final String url;
  final int size;
  final DateTime? updatedAt;

  factory PreviewAssetStatus.fromJson(Object? raw) {
    if (raw is! Map) return const PreviewAssetStatus();
    return PreviewAssetStatus(
      ready: raw['ready'] == true,
      url: raw['url']?.toString() ?? '',
      size: _intValue(raw['size']),
      updatedAt: _dateTimeValue(raw['updated_at']),
    );
  }
}

@immutable
class PreviewTask {
  const PreviewTask({
    this.taskId = '',
    this.status = 'queued',
    this.movieIds = const [],
    this.targets = const [],
    this.overwrite = false,
    this.totalCount = 0,
    this.completedCount = 0,
    this.currentMovieId = 0,
    this.currentMovieTitle = '',
    this.successCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.errors = const [],
    this.startTime,
    this.endTime,
    this.cancelRequested = false,
    this.stage = '',
    this.message = '',
    this.progress = 0,
  });

  final String taskId;
  final String status;
  final List<int> movieIds;
  final List<String> targets;
  final bool overwrite;
  final int totalCount;
  final int completedCount;
  final int currentMovieId;
  final String currentMovieTitle;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final List<String> errors;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool cancelRequested;
  final String stage;
  final String message;
  final double progress;

  factory PreviewTask.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final progress = rawProgress is Map
        ? _doubleValue(rawProgress['percent'])
        : _doubleValue(rawProgress);
    return PreviewTask(
      taskId: _stringValue(json['task_id'] ?? json['taskId']),
      status: _stringValue(json['status'], fallback: 'queued'),
      movieIds: _intList(json['movie_ids']),
      targets: _stringList(json['targets']),
      overwrite: json['overwrite'] == true,
      totalCount: _intValue(json['total_count']),
      completedCount: _intValue(json['completed_count']),
      currentMovieId: _intValue(json['current_movie_id'] ?? json['movieId']),
      currentMovieTitle: _stringValue(
        json['current_movie_title'] ?? json['movieTitle'],
      ),
      successCount: _intValue(json['success_count']),
      failedCount: _intValue(json['failed_count']),
      skippedCount: _intValue(json['skipped_count']),
      errors: _stringList(json['errors']),
      startTime: _dateTimeValue(json['start_time'] ?? json['startTime']),
      endTime: _dateTimeValue(json['end_time'] ?? json['endTime']),
      cancelRequested: json['cancel_requested'] == true,
      stage: _stringValue(json['stage']),
      message: _stringValue(json['message']),
      progress: progress.clamp(0, 100).toDouble(),
    );
  }

  bool get isActive => status == 'queued' || status == 'running';

  /// REST 任务的 progress 是当前影片进度；结合已完成影片数后转换成
  /// 任务中心使用的整体百分比。WebSocket 消息已经携带整体百分比，
  /// 但同一解析函数也接受它。
  double get overallProgress {
    if (totalCount <= 0) return progress.clamp(0, 100).toDouble();
    if (completedCount >= totalCount) return 100;
    final value =
        (completedCount + progress.clamp(0, 100).toDouble() / 100) /
        totalCount *
        100;
    return value.clamp(0, 100).toDouble();
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed' || status == 'error';
  bool get isCanceled => status == 'cancelled' || status == 'canceled';
}

@immutable
class PreviewStatus {
  const PreviewStatus({
    this.movieId = 0,
    this.sourceState = 'not_generated',
    this.sourceSha256 = '',
    this.assets = const {},
    this.task,
  });

  final int movieId;
  final String sourceState;
  final String sourceSha256;
  final Map<String, PreviewAssetStatus> assets;
  final PreviewTask? task;

  factory PreviewStatus.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    final assets = <String, PreviewAssetStatus>{};
    if (rawAssets is Map) {
      for (final entry in rawAssets.entries) {
        assets[entry.key.toString()] = PreviewAssetStatus.fromJson(entry.value);
      }
    }
    final rawTask = json['task'];
    return PreviewStatus(
      movieId: _intValue(json['movie_id'] ?? json['movieId']),
      sourceState: _stringValue(
        json['source_state'] ?? json['sourceState'],
        fallback: 'not_generated',
      ),
      sourceSha256: _stringValue(json['source_sha256'] ?? json['sourceSha256']),
      assets: Map.unmodifiable(assets),
      task: rawTask is Map
          ? PreviewTask.fromJson(Map<String, dynamic>.from(rawTask))
          : null,
    );
  }

  bool get hasReadyAsset => assets.values.any((asset) => asset.ready);
}

@immutable
class PreviewStartResult {
  const PreviewStartResult({
    required this.taskId,
    required this.reused,
    required this.task,
  });

  final String taskId;
  final bool reused;
  final PreviewTask task;

  factory PreviewStartResult.fromJson(Map<String, dynamic> json) {
    final rawTask = json['task'];
    final task = rawTask is Map
        ? PreviewTask.fromJson(Map<String, dynamic>.from(rawTask))
        : PreviewTask(taskId: _stringValue(json['task_id'] ?? json['taskId']));
    final taskId = _stringValue(
      json['task_id'] ?? json['taskId'],
      fallback: task.taskId,
    );
    return PreviewStartResult(
      taskId: taskId,
      reused: json['reused'] == true,
      task: task.taskId == taskId ? task : _copyTaskId(task, taskId),
    );
  }
}

PreviewTask _copyTaskId(PreviewTask task, String taskId) => PreviewTask(
  taskId: taskId,
  status: task.status,
  movieIds: task.movieIds,
  targets: task.targets,
  overwrite: task.overwrite,
  totalCount: task.totalCount,
  completedCount: task.completedCount,
  currentMovieId: task.currentMovieId,
  currentMovieTitle: task.currentMovieTitle,
  successCount: task.successCount,
  failedCount: task.failedCount,
  skippedCount: task.skippedCount,
  errors: task.errors,
  startTime: task.startTime,
  endTime: task.endTime,
  cancelRequested: task.cancelRequested,
  stage: task.stage,
  message: task.message,
  progress: task.progress,
);

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<int> _intList(Object? value) {
  if (value is! List) return const [];
  return value.map(_intValue).where((item) => item > 0).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

DateTime? _dateTimeValue(Object? value) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? null : DateTime.tryParse(raw);
}
