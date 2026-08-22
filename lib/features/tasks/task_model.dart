import 'package:flutter/foundation.dart';

import '../../core/models/library.dart';

@immutable
class TaskProgress {
  const TaskProgress({this.total = 0, this.completed = 0, this.percent = 0});

  factory TaskProgress.fromJson(Object? raw) {
    if (raw is! Map) return const TaskProgress();
    return TaskProgress(
      total: _asInt(raw['total']),
      completed: _asInt(raw['completed']),
      percent: _asDouble(raw['percent']),
    );
  }

  final int total;
  final int completed;
  final double percent;

  double get clampedPercent => percent.clamp(0, 100).toDouble();

  TaskProgress copyWith({int? total, int? completed, double? percent}) {
    return TaskProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      percent: percent ?? this.percent,
    );
  }
}

@immutable
class TaskItem {
  TaskItem({
    required this.id,
    required this.name,
    required this.status,
    required this.isRunning,
    required this.progress,
    required this.message,
    this.startTime,
    this.queuePosition = 0,
    this.libraryIds = const [],
    this.libraryName = '',
    this.movieId = 0,
    this.movieTitle = '',
    this.movieFileName = '',
    this.fileName = '',
    this.format = '',
    this.bitrateKbps = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? _epoch;

  factory TaskItem.fromSchedulerMessage(Map<String, dynamic> json) {
    final running = json['isRunning'] == true;
    final status = _asString(
      json['status'],
      fallback: running ? 'running' : 'completed',
    );
    return TaskItem(
      id: _asString(json['taskId']),
      name: _asString(json['taskName'], fallback: '后台任务'),
      status: status,
      isRunning: running || _isActiveStatus(status),
      progress: TaskProgress.fromJson(json['progress']),
      message: _asString(json['message']),
      startTime: _asDateTime(json['startTime']),
      queuePosition: _asInt(json['queuePosition']),
      libraryIds: _asIntList(json['libraryIds']),
      movieId: _asInt(json['movieId']),
      movieTitle: _asString(json['movieTitle']),
      movieFileName: _asString(json['movieFileName']),
      fileName: _asString(json['fileName']),
      format: _asString(json['format']),
      bitrateKbps: _asInt(json['bitrateKbps']),
      updatedAt: DateTime.now(),
    );
  }

  /// 从 /audios/transcriptions 列表行解析转译任务。
  /// 转译信息内嵌在音频资产行上，`id` 即音频资产 ID，
  /// 与 WS scheduler_status 推送的 taskId 同源，可直接用于取消/重试。
  factory TaskItem.fromTranscription(Map<String, dynamic> json) {
    final status = _asString(json['status'], fallback: 'queued');
    final percent = _asDouble(json['percent']);
    return TaskItem(
      id: _asString(json['id']),
      name: '字幕转译',
      status: status,
      isRunning: _isActiveStatus(status),
      progress: TaskProgress(
        total: 100,
        completed: percent.round(),
        percent: percent,
      ),
      message: _asString(
        json['message'],
        fallback: _asString(json['error_message']),
      ),
      startTime: _asDateTime(json['started_at'] ?? json['created_at']),
      movieId: _asInt(json['movie_id']),
      movieTitle: _asString(json['movie_title']),
      movieFileName: _asString(json['movie_file_name']),
      fileName: _asString(json['audio_file_name']),
      updatedAt: _asDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  factory TaskItem.fromScan({
    required int libraryId,
    required String libraryName,
    required String taskId,
    ScanTask? task,
  }) {
    final status = task?.status ?? 'queued';
    final total = task?.totalFiles ?? 0;
    final completed = task?.processedFiles ?? 0;
    final percent = total > 0 ? completed / total * 100 : 0.0;
    return TaskItem(
      id: taskId.isEmpty ? 'scan-placeholder-$libraryId' : taskId,
      name: '目录扫描',
      status: status,
      isRunning: _isActiveStatus(status),
      progress: TaskProgress(
        total: total,
        completed: completed,
        percent: percent,
      ),
      message: task?.currentFile ?? task?.message ?? '准备扫描',
      queuePosition: status == 'queued' ? 1 : 0,
      libraryIds: [libraryId],
      libraryName: libraryName,
      updatedAt: DateTime.now(),
    );
  }

  final String id;
  final String name;
  final String status;
  final bool isRunning;
  final TaskProgress progress;
  final String message;
  final DateTime? startTime;
  final int queuePosition;
  final List<int> libraryIds;
  final String libraryName;
  final int movieId;
  final String movieTitle;
  final String movieFileName;
  final String fileName;
  final String format;
  final int bitrateKbps;
  final DateTime updatedAt;

  String get key => '$name:$id';

  bool get isActive => isRunning || _isActiveStatus(status);

  bool get isTerminal => !_isActiveStatus(status) && !isRunning;

  bool get isCompleted => const {
    'completed',
    'done',
    'success',
    'succeeded',
    'skipped',
  }.contains(status);

  bool get isFailed => const {'failed', 'error'}.contains(status);

  bool get isCanceled => const {'canceled', 'cancelled'}.contains(status);

  bool get canCancel =>
      (name == '音频提取' && (status == 'idle' || status == 'running')) ||
      (name == '字幕转译' && (status == 'queued' || status == 'running'));

  bool get canRetry => name == '字幕转译' && (isFailed || isCanceled);

  TaskItem copyWith({
    String? id,
    String? name,
    String? status,
    bool? isRunning,
    TaskProgress? progress,
    String? message,
    DateTime? startTime,
    int? queuePosition,
    List<int>? libraryIds,
    String? libraryName,
    int? movieId,
    String? movieTitle,
    String? movieFileName,
    String? fileName,
    String? format,
    int? bitrateKbps,
    DateTime? updatedAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      isRunning: isRunning ?? this.isRunning,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      startTime: startTime ?? this.startTime,
      queuePosition: queuePosition ?? this.queuePosition,
      libraryIds: libraryIds ?? this.libraryIds,
      libraryName: libraryName ?? this.libraryName,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      movieFileName: movieFileName ?? this.movieFileName,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// WebSocket 的轻量消息和列表接口的完整记录可以交错到达，保留已有元数据。
  TaskItem merge(TaskItem incoming) {
    return incoming.copyWith(
      message: incoming.message.isEmpty ? message : incoming.message,
      startTime: incoming.startTime ?? startTime,
      libraryIds: incoming.libraryIds.isEmpty
          ? libraryIds
          : incoming.libraryIds,
      libraryName: incoming.libraryName.isEmpty
          ? libraryName
          : incoming.libraryName,
      movieId: incoming.movieId == 0 ? movieId : incoming.movieId,
      movieTitle: incoming.movieTitle.isEmpty
          ? movieTitle
          : incoming.movieTitle,
      movieFileName: incoming.movieFileName.isEmpty
          ? movieFileName
          : incoming.movieFileName,
      fileName: incoming.fileName.isEmpty ? fileName : incoming.fileName,
      format: incoming.format.isEmpty ? format : incoming.format,
      bitrateKbps: incoming.bitrateKbps == 0
          ? bitrateKbps
          : incoming.bitrateKbps,
    );
  }
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

bool _isActiveStatus(String status) {
  return const {
    'idle',
    'pending',
    'queued',
    'running',
    'paused',
  }.contains(status);
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<int> _asIntList(Object? value) {
  if (value is! List) return const [];
  return value.map(_asInt).where((item) => item > 0).toList(growable: false);
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
