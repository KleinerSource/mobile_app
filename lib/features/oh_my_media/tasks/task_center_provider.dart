import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/error_codes.dart';
import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/api/server_connection.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/library.dart';
import 'task_model.dart';

/// 所有后台任务的统一状态源。
///
/// 后端 `/ws/scheduler/status` 会在连接建立时推送当前活跃任务，之后继续
/// 推送实时进度；历史记录由服务端统一保存并在首次加载时恢复。
@immutable
class TaskCenterMeta {
  const TaskCenterMeta({
    this.total = 0,
    this.hasMore = false,
    this.loading = false,
    this.stats = const <String, int>{},
  });

  final int total;
  final bool hasMore;
  final bool loading;
  final Map<String, int> stats;
}

class TaskCenterMetaNotifier extends Notifier<TaskCenterMeta> {
  @override
  TaskCenterMeta build() => const TaskCenterMeta();
}

final taskCenterMetaProvider =
    NotifierProvider<TaskCenterMetaNotifier, TaskCenterMeta>(
      TaskCenterMetaNotifier.new,
    );

class TaskCenterNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() {
    final resourceGeneration = ++_resourceGeneration;
    _disposed = false;
    // onDispose 需先于 ref.watch 注册，避免 watch 到脏依赖时元素在本 build
    // 内被立即 invalidate，随后注册 onDispose 会抛
    // "Cannot call onDispose after a provider was dispose"。
    VoidCallback? unregisterLease;
    ref.onDispose(() {
      unregisterLease?.call();
      _disposeResources(resourceGeneration);
    });
    final connection = ref.watch(serverConnectionProvider);
    _connectionLease = connection.lease;
    unregisterLease = _connectionLease?.register(
      () => _disposeResources(resourceGeneration),
    );
    // 服务器切换时重建连接，避免任务状态串到旧线路。
    ref.watch(serverConfigProvider);
    if (_connectionLease?.isActive == true) {
      final lease = _connectionLease!;
      _connectWs();
      // 延后到 provider 完成初始化后再更新独立的摘要 provider，避免
      // Riverpod 3 在 build 期间禁止修改其他 provider。
      unawaited(
        Future<void>.microtask(() async {
          if (!_ownsLease(lease)) return;
          final meta = ref.read(taskCenterMetaProvider);
          if (meta.loading) {
            ref.read(taskCenterMetaProvider.notifier).state = TaskCenterMeta(
              total: meta.total,
              hasMore: meta.hasMore,
              loading: false,
              stats: meta.stats,
            );
          }
          await loadHistory(reset: true);
        }),
      );
    }
    return const [];
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  ServerConnectionLease? _connectionLease;
  int _resourceGeneration = 0;

  /// 任务首次进入列表时分配的稳定序号，用于服务端时间相同或缺失时
  /// 保持稳定顺序。进度广播不会改变这个序号。
  final Map<String, int> _orderByKey = {};
  int _orderSeq = 0;

  int _historyOffset = 0;
  static const _historyPageSize = 50;

  void registerScan({
    required int libraryId,
    required String libraryName,
    required String taskId,
    ScanTask? task,
  }) {
    _upsert(
      TaskItem.fromScan(
        libraryId: libraryId,
        libraryName: libraryName,
        taskId: taskId,
        task: task,
      ),
    );
  }

  void updateFromSchedulerMessage(Map<String, dynamic> message) {
    if (message['type'] != 'scheduler_status') return;
    final task = TaskItem.fromSchedulerMessage(message);
    if (task.id.isEmpty || !_acceptCurrentSnapshot(task)) return;
    _upsert(task);
  }

  Future<void> refresh() async {
    await loadHistory(reset: true);
  }

  Future<void> loadMore() async {
    final meta = ref.read(taskCenterMetaProvider);
    if (meta.loading || !meta.hasMore) return;
    await loadHistory(reset: false);
  }

  /// 通过 HTTP 校准单个任务快照，补上提交响应与 WebSocket 订阅之间的竞态。
  Future<void> syncTaskSnapshot(String taskId) async {
    final id = taskId.trim();
    if (_disposed || !ref.mounted || id.isEmpty) return;
    final lease = _connectionLease;
    try {
      final raw = await ref.read(requiredApiClientProvider).tasks.get(id);
      if (!_requestStillCurrent(lease) ||
          !ref.mounted ||
          raw is! Map ||
          raw['success'] != true) {
        return;
      }
      final data = raw['data'];
      final value = data is Map && data['task'] is Map ? data['task'] : data;
      if (value is! Map) return;
      final snapshot = Map<String, dynamic>.from(value);
      snapshot.putIfAbsent('type', () => 'scheduler_status');
      updateFromSchedulerMessage(snapshot);
    } catch (_) {
      // WebSocket 仍会继续推送；单次 HTTP 校准失败不改变任务状态。
    }
  }

  Future<void> loadHistory({required bool reset}) async {
    if (_disposed || !ref.mounted) return;
    final lease = _connectionLease;
    if (ref.read(taskCenterMetaProvider).loading) return;
    final currentMeta = ref.read(taskCenterMetaProvider);
    ref.read(taskCenterMetaProvider.notifier).state = TaskCenterMeta(
      total: currentMeta.total,
      hasMore: currentMeta.hasMore,
      loading: true,
      stats: currentMeta.stats,
    );
    try {
      if (reset) await _loadCurrentSnapshots(lease);
      if (!_requestStillCurrent(lease) || !ref.mounted) return;
      final raw = await ref
          .read(requiredApiClientProvider)
          .tasks
          .listRecords(
            limit: _historyPageSize,
            offset: reset ? 0 : _historyOffset,
          );
      if (!_requestStillCurrent(lease) || !ref.mounted) return;
      if (raw is! Map || raw['success'] != true) return;
      final data = raw['data'];
      final items = data is Map && data['items'] is List
          ? data['items'] as List
          : data is List
          ? data
          : const <dynamic>[];
      final activeTasks = reset
          ? state.where((task) => task.isActive).toList(growable: false)
          : const <TaskItem>[];
      if (reset) {
        state = const [];
        _orderByKey.clear();
        _orderSeq = 0;
        _historyOffset = 0;
        // 历史请求与 WebSocket 并行；保留请求开始前的活跃任务，避免
        // 响应返回时把实时任务短暂清空。后续历史项会按 recordId 合并。
        for (final task in activeTasks) {
          _upsert(task, updateMeta: false);
        }
      }
      for (final rawItem in items.whereType<Map>()) {
        final task = TaskItem.fromHistory(Map<String, dynamic>.from(rawItem));
        if (task.id.isNotEmpty) _upsert(task, updateMeta: false);
      }
      final total = _asInt(data is Map ? data['total'] : null);
      final stats = <String, int>{};
      if (data is Map && data['stats'] is Map) {
        for (final entry in (data['stats'] as Map).entries) {
          stats[entry.key.toString()] = _asInt(entry.value);
        }
      }
      _historyOffset = (reset ? 0 : _historyOffset) + items.length;
      ref.read(taskCenterMetaProvider.notifier).state = TaskCenterMeta(
        total: total,
        hasMore: _historyOffset < total,
        loading: false,
        stats: stats,
      );
    } catch (_) {
      // WebSocket 仍可独立工作；旧服务端未提供统一接口时不打断任务页。
    } finally {
      if (_requestStillCurrent(lease) && ref.mounted) {
        final meta = ref.read(taskCenterMetaProvider);
        if (meta.loading) {
          ref.read(taskCenterMetaProvider.notifier).state = TaskCenterMeta(
            total: meta.total,
            hasMore: meta.hasMore,
            loading: false,
            stats: meta.stats,
          );
        }
      }
    }
  }

  Future<String?> cancel(TaskItem task) async {
    if (!task.canCancel) return null;
    return _control(task, 'cancel', kTaskErrCancelExtract);
  }

  Future<String?> retry(TaskItem task) async {
    if (!task.canRetry) return null;
    return _control(task, 'retry', kTaskErrRetryTranscribe);
  }

  Future<String?> pause(TaskItem task) async {
    if (!task.canPause) return null;
    return _control(task, 'pause', kTaskErrPause);
  }

  Future<String?> resume(TaskItem task) async {
    if (!task.canResume) return null;
    return _control(task, 'resume', kTaskErrResume);
  }

  /// 删除服务端终态任务记录。运行中的任务由服务端拒绝删除。
  Future<String?> remove(TaskItem task) async {
    if (!task.isTerminal || task.recordId.isEmpty) return null;
    final lease = _connectionLease;
    final raw = await ref
        .read(requiredApiClientProvider)
        .tasks
        .deleteRecord(task.recordId);
    if (!_requestStillCurrent(lease)) return envelopeMessageOrNull(raw);
    _ensureSuccess(raw, AppErrorCode.operationFailed);
    final index = state.indexWhere((item) => item.key == task.key);
    if (index >= 0) {
      final removed = state[index];
      final next = [...state]..removeAt(index);
      state = next;
      _syncMetaForTaskChange(removed, null);
    }
    return envelopeMessageOrNull(raw);
  }

  void restore(TaskItem task) => _upsert(task);

  void _connectWs() {
    unawaited(_connectWsAsync());
  }

  Future<void> _connectWsAsync() async {
    if (_disposed) return;
    final cfg = ref.read(serverConfigProvider);
    final serverId = cfg?.activeServerId;
    final lease = _connectionLease;
    if (cfg == null ||
        cfg.baseUrl.trim().isEmpty ||
        serverId == null ||
        lease == null ||
        !lease.isActive ||
        lease.serverId != serverId) {
      _scheduleReconnect();
      return;
    }
    final token = await ref
        .read(authSessionRepositoryProvider)
        .forServer(serverId, allowLegacyMigration: false)
        .accessToken();
    if (!_ownsLease(lease)) return;
    final resolved = resolveServerUrl(cfg, '/ws/scheduler/status');
    final uri = Uri.parse(
      resolved,
    ).replace(scheme: Uri.parse(resolved).scheme == 'https' ? 'wss' : 'ws');
    final wsUrl = appendQueryToken(uri.toString(), token);
    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      _subscription = channel.stream.listen(
        (raw) {
          if (_ownsLease(lease)) _onMessage(raw);
        },
        onError: (_, __) => _onDisconnect(lease),
        onDone: () => _onDisconnect(lease),
        cancelOnError: false,
      );
      _reconnectAttempts = 0;
      unawaited(_loadCurrentSnapshots(lease));
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!_ownsLease(lease)) return;
        try {
          _channel?.sink.add('{"type":"ping"}');
        } catch (_) {}
      });
    } catch (_) {
      if (_ownsLease(lease)) _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : raw.toString();
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        updateFromSchedulerMessage(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 单条异常消息不能中断任务流。
    }
  }

  void _upsert(TaskItem incoming, {bool updateMeta = true}) {
    final next = [...state];
    if (incoming.attempt > 0) {
      next.removeWhere(
        (item) =>
            item.id == incoming.id &&
            item.attempt > 0 &&
            item.attempt < incoming.attempt &&
            item.isActive,
      );
    }
    var index = incoming.attempt > 0
        ? next.indexWhere(
            (item) =>
                item.id == incoming.id && item.attempt == incoming.attempt,
          )
        : incoming.recordId.isNotEmpty
        ? next.indexWhere((item) => item.recordId == incoming.recordId)
        : -1;
    if (index < 0 && incoming.recordId.isEmpty && incoming.id.isNotEmpty) {
      index = next.indexWhere(
        (item) =>
            item.id == incoming.id &&
            item.name == incoming.name &&
            item.isActive,
      );
      if (index < 0 && !incoming.isActive) {
        index = next.indexWhere(
          (item) => item.id == incoming.id && item.name == incoming.name,
        );
      }
    }
    if (index < 0 && _isScanTask(incoming)) {
      index = next.indexWhere(
        (item) => item.id == incoming.id && _isScanTask(item),
      );
    }
    if (index < 0 && _isScanTask(incoming)) {
      index = next.indexWhere(
        (item) =>
            item.id.startsWith('scan-placeholder-') &&
            item.libraryIds.any(incoming.libraryIds.contains),
      );
    }
    TaskItem? previousTask;
    late final TaskItem currentTask;
    if (index >= 0) {
      final previous = next[index];
      if (incoming.revision > 0 && previous.revision > incoming.revision) {
        return;
      }
      previousTask = previous;
      final merged = previous.merge(incoming);
      // 占位扫描任务拿到真实 id 后 key 会变化，沿用原序号避免卡片跳动。
      if (merged.key != previous.key) {
        final staleOrder = _orderByKey.remove(previous.key);
        if (staleOrder != null) {
          _orderByKey[merged.key] = staleOrder;
        }
      }
      next[index] = merged;
      currentTask = merged;
    } else {
      next.insert(0, incoming);
      currentTask = incoming;
    }
    _sortTasks(next);
    if (next.length > 200) {
      next.removeRange(200, next.length);
    }
    state = next;
    if (updateMeta) {
      _syncMetaForTaskChange(previousTask, currentTask);
    }
  }

  /// 活跃任务置顶；同一状态按服务端任务时间倒序，时间缺失时按首次
  /// 进入列表的稳定序号倒序。
  void _sortTasks(List<TaskItem> items) {
    for (final item in items) {
      _orderByKey.putIfAbsent(item.key, () => _orderSeq++);
    }
    items.sort((left, right) {
      if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
      final timeOrder = right.sortTime.compareTo(left.sortTime);
      if (timeOrder != 0) return timeOrder;
      return _orderByKey[right.key]!.compareTo(_orderByKey[left.key]!);
    });
  }

  void _syncMetaForTaskChange(TaskItem? previous, TaskItem? current) {
    final previousStatus = _taskStatKey(previous);
    final currentStatus = _taskStatKey(current);
    final totalDelta = previous == null && current != null
        ? 1
        : previous != null && current == null
        ? -1
        : 0;
    if (totalDelta == 0 && previousStatus == currentStatus) return;

    final currentMeta = ref.read(taskCenterMetaProvider);
    final stats = currentMeta.stats.isEmpty
        ? _statsFromTasks()
        : Map<String, int>.from(currentMeta.stats);
    if (currentMeta.stats.isNotEmpty) {
      if (previousStatus != null) {
        final value = (stats[previousStatus] ?? 0) - 1;
        stats[previousStatus] = value < 0 ? 0 : value;
      }
      if (currentStatus != null) {
        stats[currentStatus] = (stats[currentStatus] ?? 0) + 1;
      }
    }

    final total = currentMeta.total + totalDelta;
    ref.read(taskCenterMetaProvider.notifier).state = TaskCenterMeta(
      total: total < 0 ? 0 : total,
      hasMore: _historyOffset < (total < 0 ? 0 : total),
      loading: currentMeta.loading,
      stats: stats,
    );
  }

  Map<String, int> _statsFromTasks() {
    final stats = <String, int>{};
    for (final task in state) {
      final key = _taskStatKey(task);
      if (key != null) stats[key] = (stats[key] ?? 0) + 1;
    }
    return stats;
  }

  void _onDisconnect(ServerConnectionLease lease) {
    if (!_ownsLease(lease)) return;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final lease = _connectionLease;
    if (!_ownsLease(lease) || _reconnectTimer != null) {
      return;
    }
    final exponent = _reconnectAttempts.clamp(0, 4);
    final seconds = (3 * (1 << exponent)).clamp(3, 30);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      if (_ownsLease(lease)) _connectWs();
    });
  }

  void _disposeResources(int resourceGeneration) {
    if (resourceGeneration != _resourceGeneration) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  bool _acceptCurrentSnapshot(TaskItem incoming) {
    if (incoming.attempt <= 0) return true;
    var latestAttempt = 0;
    TaskItem? currentAttempt;
    for (final item in state) {
      if (item.id != incoming.id) continue;
      if (item.attempt > latestAttempt) latestAttempt = item.attempt;
      if (item.attempt == incoming.attempt) currentAttempt = item;
    }
    if (incoming.attempt < latestAttempt) return false;
    if (currentAttempt != null &&
        incoming.revision > 0 &&
        currentAttempt.revision >= incoming.revision) {
      return false;
    }
    return true;
  }

  Future<void> _loadCurrentSnapshots([ServerConnectionLease? lease]) async {
    try {
      if (_disposed || !ref.mounted) return;
      final raw = await ref.read(requiredApiClientProvider).tasks.list();
      if (!_requestStillCurrent(lease) || !ref.mounted) return;
      if (raw is! Map || raw['success'] != true) return;
      final data = raw['data'];
      final items = data is Map && data['items'] is List
          ? data['items'] as List
          : const <dynamic>[];
      for (final rawItem in items.whereType<Map>()) {
        final snapshot = Map<String, dynamic>.from(rawItem);
        snapshot.putIfAbsent('type', () => 'scheduler_status');
        updateFromSchedulerMessage(snapshot);
      }
    } catch (_) {
      // WS 与 HTTP 校准互为补充；单次校准失败交给后续重连或刷新。
    }
  }

  Future<String?> _control(
    TaskItem task,
    String action,
    String fallback,
  ) async {
    if (_disposed || !ref.mounted) return null;
    final lease = _connectionLease;
    final raw = await ref
        .read(requiredApiClientProvider)
        .tasks
        .control(task.id, action);
    if (!_requestStillCurrent(lease) || !ref.mounted) return null;
    final message = _ensureSuccess(raw, fallback);
    final data = raw is Map ? raw['data'] : null;
    if (data is Map) {
      final snapshot = Map<String, dynamic>.from(data);
      snapshot.putIfAbsent('type', () => 'scheduler_status');
      updateFromSchedulerMessage(snapshot);
    }
    return message;
  }

  bool _ownsLease(ServerConnectionLease? lease) =>
      !_disposed &&
      lease != null &&
      lease.isActive &&
      identical(_connectionLease, lease);

  bool _requestStillCurrent(ServerConnectionLease? lease) =>
      lease == null ? !_disposed : _ownsLease(lease);
}

bool _isScanTask(TaskItem task) {
  return task.taskType == 'library_scan';
}

String? _taskStatKey(TaskItem? task) {
  if (task == null) return null;
  if (task.isActive) return 'running';
  if (task.isCompleted) return 'completed';
  if (task.isFailed) return 'failed';
  if (task.isCanceled) return 'canceled';
  return null;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _ensureSuccess(Object? raw, String fallback) {
  if (raw is! Map || raw['success'] != true) {
    throw StateError(envelopeMessage(raw, fallback: fallback));
  }
  return envelopeMessageOrNull(raw);
}

final taskCenterProvider = NotifierProvider<TaskCenterNotifier, List<TaskItem>>(
  TaskCenterNotifier.new,
);
