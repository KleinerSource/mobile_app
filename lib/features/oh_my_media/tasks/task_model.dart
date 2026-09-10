import 'package:flutter/foundation.dart';

import 'package:omm/core/models/library.dart';

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
    this.taskType = '',
    this.recordId = '',
    this.attempt = 0,
    this.revision = 0,
    this.phase = '',
    this.serverCanCancel,
    this.serverCanPause,
    this.serverCanResume,
    this.serverCanRetry,
    this.recoveryDecision = '',
    this.recoveryReason = '',
    this.previousRecordId = '',
    this.nextRecordId = '',
    this.result,
    this.startTime,
    this.queuePosition = 0,
    this.libraryIds = const [],
    this.libraryName = '',
    this.displayName = '',
    this.movieId = 0,
    this.movieTitle = '',
    this.movieFileName = '',
    this.fileName = '',
    this.format = '',
    this.bitrateKbps = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? _epoch;

  factory TaskItem.fromSchedulerMessage(Map<String, dynamic> json) {
    final rawPhase = _asString(json['phase'] ?? json['status']);
    final running = json['isRunning'] == true;
    final status = _normalizeStatus(
      json['status'],
      fallback: running ? 'running' : 'completed',
    );
    return TaskItem(
      id: _asString(json['taskId'] ?? json['task_id']),
      taskType: _asString(json['taskType'] ?? json['task_type']),
      name: _asString(json['taskName'] ?? json['task_name'], fallback: '后台任务'),
      status: status,
      isRunning: _isActiveStatus(status),
      progress: TaskProgress.fromJson(json['progress']),
      message: _asString(json['message']),
      recordId: _asString(json['recordId'] ?? json['record_id']),
      attempt: _asInt(json['attempt']),
      revision: _asInt(json['revision']),
      phase: rawPhase,
      serverCanCancel: _asBoolOrNull(json['canCancel'] ?? json['can_cancel']),
      serverCanPause: _asBoolOrNull(json['canPause'] ?? json['can_pause']),
      serverCanResume: _asBoolOrNull(json['canResume'] ?? json['can_resume']),
      serverCanRetry: _asBoolOrNull(json['canRetry'] ?? json['can_retry']),
      recoveryDecision: _asString(
        json['recoveryDecision'] ?? json['recovery_decision'],
      ),
      recoveryReason: _asString(
        json['recoveryReason'] ?? json['recovery_reason'],
      ),
      previousRecordId: _asString(
        json['previousRecordId'] ?? json['previous_record_id'],
      ),
      nextRecordId: _asString(json['nextRecordId'] ?? json['next_record_id']),
      result: json['result'],
      startTime: _asDateTime(json['startTime'] ?? json['start_time']),
      queuePosition: _asInt(json['queuePosition'] ?? json['queue_position']),
      libraryIds: _asIntList(json['libraryIds'] ?? json['library_ids']),
      displayName: _asString(json['displayName'] ?? json['display_name']),
      movieId: _asInt(json['movieId'] ?? json['movie_id']),
      movieTitle: _asString(json['movieTitle'] ?? json['movie_title']),
      movieFileName: _asString(
        json['movieFileName'] ?? json['movie_file_name'],
      ),
      fileName: _asString(json['fileName'] ?? json['file_name']),
      format: _asString(json['format']),
      bitrateKbps: _asInt(json['bitrateKbps'] ?? json['bitrate_kbps']),
      updatedAt:
          _asDateTime(json['updatedAt'] ?? json['updated_at']) ??
          DateTime.now(),
    );
  }

  /// 从 `/audios/transcriptions` 业务投影列表行解析转译任务。
  /// 转译信息内嵌在音频资产行上；统一控制使用独立的逻辑 `task_id`。
  factory TaskItem.fromTranscription(Map<String, dynamic> json) {
    final phase = _asString(
      json['phase'] ?? json['status'],
      fallback: 'queued',
    );
    final status = _normalizeStatus(phase, fallback: 'running');
    final percent = _asDouble(json['percent']);
    return TaskItem(
      id: _asString(json['task_id'] ?? json['taskId']),
      taskType: 'subtitle_transcription',
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
      taskType: _asString(json['task_type'] ?? json['taskType']),
      name: _asString(json['task_name'] ?? json['taskName'], fallback: '后台任务'),
      status: status,
      isRunning: _isActiveStatus(status),
      progress: TaskProgress(
        total: _asInt(json['progress_total'] ?? json['progressTotal']),
        completed: _asInt(
          json['progress_completed'] ?? json['progressCompleted'],
        ),
        percent: _asDouble(json['progress_percent'] ?? json['progressPercent']),
      ),
      message: _asString(json['message']),
      recordId: _asString(json['record_id'] ?? json['recordId']),
      attempt: _asInt(json['attempt']),
      revision: _asInt(json['revision']),
      phase: phase,
      startTime: _asDateTime(json['start_time'] ?? json['startTime']),
      queuePosition: _asInt(json['queue_position'] ?? json['queuePosition']),
      libraryIds: _asIntList(json['library_ids'] ?? json['libraryIds']),
      displayName: _asString(json['display_name'] ?? json['displayName']),
      movieId: _asInt(json['movie_id'] ?? json['movieId']),
      movieTitle: _asString(json['movie_title'] ?? json['movieTitle']),
      movieFileName: _asString(
        json['movie_file_name'] ?? json['movieFileName'],
      ),
      fileName: _asString(json['file_name'] ?? json['fileName']),
      format: _asString(json['format']),
      bitrateKbps: _asInt(json['bitrate_kbps'] ?? json['bitrateKbps']),
      serverCanCancel: _asBoolOrNull(json['can_cancel'] ?? json['canCancel']),
      serverCanPause: _asBoolOrNull(json['can_pause'] ?? json['canPause']),
      serverCanResume: _asBoolOrNull(json['can_resume'] ?? json['canResume']),
      serverCanRetry: _asBoolOrNull(json['can_retry'] ?? json['canRetry']),
      recoveryDecision: _asString(
        json['recovery_decision'] ?? json['recoveryDecision'],
      ),
      recoveryReason: _asString(
        json['recovery_reason'] ?? json['recoveryReason'],
      ),
      previousRecordId: _asString(
        json['previous_record_id'] ?? json['previousRecordId'],
      ),
      nextRecordId: _asString(json['next_record_id'] ?? json['nextRecordId']),
      result: json['result'] ?? json['result_json'],
      updatedAt:
          _asDateTime(json['updated_at'] ?? json['updatedAt']) ??
          _asDateTime(json['end_time'] ?? json['endTime']) ??
          _asDateTime(json['created_at'] ?? json['createdAt']) ??
          _asDateTime(json['start_time'] ?? json['startTime']) ??
          _epoch,
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
      taskType: 'library_scan',
      name: '目录扫描',
      status: status,
      isRunning: _isActiveStatus(status),
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
      displayName: libraryName,
      updatedAt: DateTime.now(),
    );
  }

  final String id;
  final String taskType;
  final String recordId;
  final int attempt;
  final int revision;
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
  final String displayName;
  final int movieId;
  final String movieTitle;
  final String movieFileName;
  final String fileName;
  final String format;
  final int bitrateKbps;
  final DateTime updatedAt;
  final bool? serverCanCancel;
  final bool? serverCanPause;
  final bool? serverCanResume;
  final bool? serverCanRetry;
  final String recoveryDecision;
  final String recoveryReason;
  final String previousRecordId;
  final String nextRecordId;
  final Object? result;

  String get key => attempt > 0 ? 'task:$id:$attempt' : '$taskType:$id';

  bool get isActive => isRunning || _isActiveStatus(status);

  bool get isTerminal => !_isActiveStatus(status) && !isRunning;

  bool get isCompleted => status == 'completed';

  bool get isFailed => status == 'failed';

  bool get isCanceled => status == 'canceled';

  /// 用于任务中心排序的服务端时间。
  ///
  /// 活跃任务只使用开始时间，避免每次进度广播刷新 updatedAt 后任务跳动；
  /// 终态任务优先使用更新时间，历史记录缺失时间时回退到开始时间和 epoch。
  DateTime get sortTime {
    if (isActive) return startTime ?? _epoch;
    if (updatedAt != _epoch) return updatedAt;
    return startTime ?? _epoch;
  }

  bool get canCancel => isActive && serverCanCancel == true;

  bool get canPause => status == 'running' && serverCanPause == true;

  bool get canResume => status == 'paused' && serverCanResume == true;

  bool get canRetry => (isFailed || isCanceled) && serverCanRetry == true;

  TaskItem copyWith({
    String? id,
    String? taskType,
    String? recordId,
    int? attempt,
    int? revision,
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
    String? displayName,
    int? movieId,
    String? movieTitle,
    String? movieFileName,
    String? fileName,
    String? format,
    int? bitrateKbps,
    DateTime? updatedAt,
    bool? serverCanCancel,
    bool? serverCanPause,
    bool? serverCanResume,
    bool? serverCanRetry,
    String? recoveryDecision,
    String? recoveryReason,
    String? previousRecordId,
    String? nextRecordId,
    Object? result,
  }) {
    return TaskItem(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      recordId: recordId ?? this.recordId,
      attempt: attempt ?? this.attempt,
      revision: revision ?? this.revision,
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
      displayName: displayName ?? this.displayName,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      movieFileName: movieFileName ?? this.movieFileName,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      updatedAt: updatedAt ?? DateTime.now(),
      serverCanCancel: serverCanCancel ?? this.serverCanCancel,
      serverCanPause: serverCanPause ?? this.serverCanPause,
      serverCanResume: serverCanResume ?? this.serverCanResume,
      serverCanRetry: serverCanRetry ?? this.serverCanRetry,
      recoveryDecision: recoveryDecision ?? this.recoveryDecision,
      recoveryReason: recoveryReason ?? this.recoveryReason,
      previousRecordId: previousRecordId ?? this.previousRecordId,
      nextRecordId: nextRecordId ?? this.nextRecordId,
      result: result ?? this.result,
    );
  }

  /// WebSocket 的轻量消息和列表接口的完整记录可以交错到达，保留已有元数据。
  TaskItem merge(TaskItem incoming) {
    return incoming.copyWith(
      taskType: incoming.taskType.isEmpty ? taskType : incoming.taskType,
      recordId: incoming.recordId.isEmpty ? recordId : incoming.recordId,
      attempt: incoming.attempt == 0 ? attempt : incoming.attempt,
      revision: incoming.revision == 0 ? revision : incoming.revision,
      phase: incoming.phase.isEmpty ? phase : incoming.phase,
      message: incoming.message.isEmpty ? message : incoming.message,
      startTime: incoming.startTime ?? startTime,
      libraryIds: incoming.libraryIds.isEmpty
          ? libraryIds
          : incoming.libraryIds,
      libraryName: incoming.libraryName.isEmpty
          ? libraryName
          : incoming.libraryName,
      displayName: incoming.displayName.isEmpty
          ? displayName
          : incoming.displayName,
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
      recoveryDecision: incoming.recoveryDecision.isEmpty
          ? recoveryDecision
          : incoming.recoveryDecision,
      recoveryReason: incoming.recoveryReason.isEmpty
          ? recoveryReason
          : incoming.recoveryReason,
      previousRecordId: incoming.previousRecordId.isEmpty
          ? previousRecordId
          : incoming.previousRecordId,
      nextRecordId: incoming.nextRecordId.isEmpty
          ? nextRecordId
          : incoming.nextRecordId,
      updatedAt: incoming.updatedAt == _epoch ? updatedAt : incoming.updatedAt,
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
    'canceling',
  }.contains(status);
}

String _normalizeStatus(Object? raw, {String fallback = 'completed'}) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  switch (value) {
    case 'queued':
      return 'queued';
    case 'idle':
    case 'pending':
      return 'queued';
    case 'paused':
      return 'paused';
    case 'canceling':
    case 'cancelling':
      return 'canceling';
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
      return fallback;
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
