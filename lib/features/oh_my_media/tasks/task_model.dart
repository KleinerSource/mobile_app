import 'package:flutter/foundation.dart';

import 'package:omm/core/models/library.dart';
import 'package:omm/core/models/preview.dart';

/// 客户端生成的任务消息码。任务消息可能来自服务器原文，展示层仅对
/// 已知码做本地化翻译（见 task_name_labels.dart），其余原样显示。
const String kTaskMsgScanPreparing = '@task/msg/scan-preparing';
const String kTaskMsgScanQueued = '@task/msg/scan-queued';
const String kTaskMsgCanceled = '@task/msg/canceled';
const String kTaskMsgRequeued = '@task/msg/requeued';

/// '排队中（第 N 位）' 的参数化消息码，冒号后为十进制序号。
const String kTaskMsgScanQueuedAtPrefix = '@task/msg/scan-queued-at:';

/// 取消/重试失败时抛出的兜底错误码，由展示层翻译。
const String kTaskErrCancelTranscribe = '@task/err/cancel-transcribe';
const String kTaskErrCancelExtract = '@task/err/cancel-extract';
const String kTaskErrRetryTranscribe = '@task/err/retry-transcribe';

@immutable
class TaskProgress {
  const TaskProgress({this.total = 0, this.completed = 0, this.percent = 0});

  factory TaskProgress.fromJson(Object? raw) {
    if (raw is num) {
      final percent = raw.toDouble();
      return TaskProgress(
        total: 100,
        completed: percent.round(),
        percent: percent,
      );
    }
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
    this.recordId = '',
    this.phase = '',
    this.serverCanCancel,
    this.serverCanRetry,
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
    if (json['type'] == 'preview_task') {
      return TaskItem.fromPreviewMessage(json);
    }
    final rawPhase = _asString(json['phase'] ?? json['status']);
    final running = json['isRunning'] == true;
    final status = _normalizeStatus(
      json['status'],
      fallback: running ? 'running' : 'completed',
    );
    return TaskItem(
      id: _asString(json['taskId']),
      name: _asString(json['taskName'], fallback: '后台任务'),
      status: status,
      isRunning: status == 'running',
      progress: TaskProgress.fromJson(json['progress']),
      message: _asString(json['message']),
      recordId: _asString(json['recordId'] ?? json['record_id']),
      phase: rawPhase,
      serverCanCancel: _asBoolOrNull(json['canCancel'] ?? json['can_cancel']),
      serverCanRetry: _asBoolOrNull(json['canRetry'] ?? json['can_retry']),
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

  factory TaskItem.fromPreviewMessage(Map<String, dynamic> json) {
    final taskId = _asString(json['taskId'] ?? json['task_id']);
    final running = json['isRunning'] == true;
    final status = _normalizeStatus(
      json['status'],
      fallback: running ? 'running' : 'completed',
    );
    final rawProgress = json['progress'];
    final progress = rawProgress is Map
        ? TaskProgress.fromJson(rawProgress)
        : TaskProgress.fromJson(rawProgress);
    return TaskItem(
      id: taskId,
      name: '预览生成',
      status: status,
      isRunning: status == 'running',
      progress: progress,
      message: _asString(json['message']),
      recordId: _asString(json['recordId'] ?? json['record_id']),
      phase: _asString(json['phase'] ?? json['status']),
      serverCanCancel: _asBoolOrNull(json['canCancel'] ?? json['can_cancel']),
      serverCanRetry: _asBoolOrNull(json['canRetry'] ?? json['can_retry']),
      startTime: _asDateTime(json['startTime'] ?? json['start_time']),
      queuePosition: _asInt(json['queuePosition'] ?? json['queue_position']),
      movieId: _asInt(
        json['movieId'] ?? json['movie_id'] ?? json['current_movie_id'],
      ),
      movieTitle: _asString(
        json['movieTitle'] ??
            json['movie_title'] ??
            json['current_movie_title'],
      ),
      movieFileName: _asString(
        json['movieFileName'] ?? json['movie_file_name'],
      ),
      updatedAt: DateTime.now(),
    );
  }

  factory TaskItem.fromPreviewTask(
    PreviewTask task, {
    int? fallbackMovieId,
    String? fallbackMovieTitle,
  }) {
    final movieId = task.currentMovieId > 0
        ? task.currentMovieId
        : fallbackMovieId ??
              (task.movieIds.length == 1 ? task.movieIds.single : 0);
    final movieTitle = task.currentMovieTitle.isNotEmpty
        ? task.currentMovieTitle
        : fallbackMovieTitle ?? '';
    return TaskItem(
      id: task.taskId,
      name: '预览生成',
      status: _normalizeStatus(
        task.status,
        fallback: task.isActive ? 'running' : 'completed',
      ),
      isRunning: task.isActive,
      progress: TaskProgress(
        total: task.totalCount,
        completed: task.completedCount,
        percent: task.overallProgress,
      ),
      message: task.message,
      phase: task.status,
      startTime: task.startTime,
      movieId: movieId,
      movieTitle: movieTitle,
      updatedAt: DateTime.now(),
    );
  }

  /// 从 /audios/transcriptions 列表行解析转译任务。
  /// 转译信息内嵌在音频资产行上，`id` 即音频资产 ID，
  /// 与 WS scheduler_status 推送的 taskId 同源，可直接用于取消/重试。
  factory TaskItem.fromTranscription(Map<String, dynamic> json) {
    final phase = _asString(
      json['phase'] ?? json['status'],
      fallback: 'queued',
    );
    final status = _normalizeStatus(phase, fallback: 'running');
    final percent = _asDouble(json['percent']);
    return TaskItem(
      id: _asString(json['id']),
      name: '字幕转译',
      status: status,
      isRunning: status == 'running',
      progress: TaskProgress(
        total: 100,
        completed: percent.round(),
        percent: percent,
      ),
      message: _asString(
        json['message'],
        fallback: _asString(json['error_message']),
      ),
      phase: phase,
      serverCanCancel: _asBoolOrNull(json['can_cancel'] ?? json['canCancel']),
      serverCanRetry: _asBoolOrNull(json['can_retry'] ?? json['canRetry']),
      startTime: _asDateTime(json['started_at'] ?? json['created_at']),
      movieId: _asInt(json['movie_id']),
      movieTitle: _asString(json['movie_title']),
      movieFileName: _asString(json['movie_file_name']),
      fileName: _asString(json['audio_file_name']),
      updatedAt: _asDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  factory TaskItem.fromHistory(Map<String, dynamic> json) {
    final phase = _asString(json['phase'] ?? json['status']);
    final status = _normalizeStatus(
      json['status'] ?? phase,
      fallback: phase == 'queued' || phase == 'idle' || phase == 'paused'
          ? 'running'
          : 'completed',
    );
    return TaskItem(
      id: _asString(json['task_id'] ?? json['taskId']),
      name: _asString(json['task_name'] ?? json['taskName'], fallback: '后台任务'),
      status: status,
      isRunning: status == 'running',
      progress: TaskProgress(
        total: _asInt(json['progress_total'] ?? json['progressTotal']),
        completed: _asInt(
          json['progress_completed'] ?? json['progressCompleted'],
        ),
        percent: _asDouble(json['progress_percent'] ?? json['progressPercent']),
      ),
      message: _asString(json['message']),
      recordId: _asString(json['record_id'] ?? json['recordId']),
      phase: phase,
      startTime: _asDateTime(json['start_time'] ?? json['startTime']),
      queuePosition: _asInt(json['queue_position'] ?? json['queuePosition']),
      libraryIds: _asIntList(json['library_ids'] ?? json['libraryIds']),
      movieId: _asInt(json['movie_id'] ?? json['movieId']),
      movieTitle: _asString(json['movie_title'] ?? json['movieTitle']),
      movieFileName: _asString(
        json['movie_file_name'] ?? json['movieFileName'],
      ),
      fileName: _asString(json['file_name'] ?? json['fileName']),
      format: _asString(json['format']),
      bitrateKbps: _asInt(json['bitrate_kbps'] ?? json['bitrateKbps']),
      serverCanCancel: _asBoolOrNull(json['can_cancel'] ?? json['canCancel']),
      serverCanRetry: _asBoolOrNull(json['can_retry'] ?? json['canRetry']),
      updatedAt:
          _asDateTime(json['updated_at'] ?? json['updatedAt']) ??
          DateTime.now(),
    );
  }

  factory TaskItem.fromScan({
    required int libraryId,
    required String libraryName,
    required String taskId,
    ScanTask? task,
  }) {
    final phase = task?.status ?? 'queued';
    final status = _normalizeStatus(phase, fallback: 'running');
    final total = task?.totalFiles ?? 0;
    final completed = task?.processedFiles ?? 0;
    final percent = total > 0 ? completed / total * 100 : 0.0;
    return TaskItem(
      id: taskId.isEmpty ? 'scan-placeholder-$libraryId' : taskId,
      name: '目录扫描',
      status: status,
      isRunning: status == 'running',
      progress: TaskProgress(
        total: total,
        completed: completed,
        percent: percent,
      ),
      message: task?.currentFile ?? task?.message ?? kTaskMsgScanPreparing,
      phase: phase,
      queuePosition: status == 'queued' ? 1 : 0,
      libraryIds: [libraryId],
      libraryName: libraryName,
      updatedAt: DateTime.now(),
    );
  }

  final String id;
  final String recordId;
  final String phase;
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
  final bool? serverCanCancel;
  final bool? serverCanRetry;

  String get key => recordId.isNotEmpty ? 'record:$recordId' : '$name:$id';

  bool get isActive => isRunning || _isActiveStatus(status);

  bool get isTerminal => !_isActiveStatus(status) && !isRunning;

  bool get isCompleted => status == 'completed';

  bool get isFailed => status == 'failed';

  bool get isCanceled => status == 'canceled';

  bool get canCancel =>
      isActive &&
      (serverCanCancel ??
          (name != '资源扫描' &&
              name != '重复番号合并' &&
              (name == '音频提取' ||
                  name == '字幕转译' ||
                  name == '预览生成' ||
                  name == '预览图下载' ||
                  name == 'NFO 同步' ||
                  name == '演员关联同步' ||
                  name.contains('扫描'))));

  bool get canRetry =>
      (isFailed || isCanceled) && (serverCanRetry ?? (name == '字幕转译'));

  TaskItem copyWith({
    String? id,
    String? recordId,
    String? phase,
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
    bool? serverCanCancel,
    bool? serverCanRetry,
  }) {
    return TaskItem(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
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
      serverCanCancel: serverCanCancel ?? this.serverCanCancel,
      serverCanRetry: serverCanRetry ?? this.serverCanRetry,
    );
  }

  /// WebSocket 的轻量消息和列表接口的完整记录可以交错到达，保留已有元数据。
  TaskItem merge(TaskItem incoming) {
    return incoming.copyWith(
      recordId: incoming.recordId.isEmpty ? recordId : incoming.recordId,
      phase: incoming.phase.isEmpty ? phase : incoming.phase,
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

String _normalizeStatus(Object? raw, {String fallback = 'completed'}) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  switch (value) {
    case 'queued':
    case 'idle':
    case 'pending':
    case 'paused':
    case 'running':
    case 'processing':
      return 'running';
    case 'failed':
    case 'error':
      return 'failed';
    case 'canceled':
    case 'cancelled':
    case 'aborted':
      return 'canceled';
    case 'completed':
    case 'complete':
    case 'done':
    case 'success':
    case 'succeeded':
    case 'skipped':
      return 'completed';
    default:
      return fallback == 'running' ? 'running' : 'completed';
  }
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

bool? _asBoolOrNull(Object? value) {
  if (value is bool) return value;
  if (value == null) return null;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
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
