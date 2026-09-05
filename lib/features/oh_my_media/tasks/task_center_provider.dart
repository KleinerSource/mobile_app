import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/library.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/features/oh_my_media/audio/audio_providers.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
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
    // onDispose 需先于 ref.watch 注册，避免 watch 到脏依赖时元素在本 build
    // 内被立即 invalidate，随后注册 onDispose 会抛
    // "Cannot call onDispose after a provider was dispose"。
    ref.onDispose(_disposeResources);
    // 服务器切换时重建连接，避免任务状态串到旧线路。
    ref.watch(serverConfigProvider);
    _connectWs();
    // 延后到 provider 完成初始化后再更新独立的摘要 provider，避免
    // Riverpod 3 在 build 期间禁止修改其他 provider。
    unawaited(Future<void>.microtask(() => loadHistory(reset: true)));
    return const [];
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  /// 任务首次进入列表时分配的稳定序号。进度广播会高频到达并刷新
  /// updatedAt，排序若依赖它会导致任务卡片不停换位，因此只按插入顺序排。
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
    if (message['type'] == 'preview_task' &&
        ref.read(serverConfigProvider)?.isOmm != true) {
      return;
    }
    if (message['type'] != 'scheduler_status' &&
        message['type'] != 'preview_task') {
      return;
    }
    final task = TaskItem.fromSchedulerMessage(message);
    if (task.id.isEmpty) return;
    _upsert(task);
  }

  /// 生成接口返回任务后立即登记，避免 WebSocket 首条消息晚于页面反馈。
  void registerPreview(PreviewTask task, {int? movieId, String? movieTitle}) {
    if (task.taskId.isEmpty || ref.read(serverConfigProvider)?.isOmm != true) {
      return;
    }
    _upsert(
      TaskItem.fromPreviewTask(
        task,
        fallbackMovieId: movieId,
        fallbackMovieTitle: movieTitle,
      ),
    );
  }

  Future<void> refresh() async {
    await loadHistory(reset: true);
  }

  Future<void> loadMore() async {
    final meta = ref.read(taskCenterMetaProvider);
    if (meta.loading || !meta.hasMore) return;
    await loadHistory(reset: false);
  }

  Future<void> loadHistory({required bool reset}) async {
    if (ref.read(taskCenterMetaProvider).loading) return;
    final currentMeta = ref.read(taskCenterMetaProvider);
    ref.read(taskCenterMetaProvider.notifier).state = TaskCenterMeta(
      total: currentMeta.total,
      hasMore: currentMeta.hasMore,
      loading: true,
      stats: currentMeta.stats,
    );
    try {
      final raw = await ref
          .read(requiredApiClientProvider)
          .tasks
          .list(limit: _historyPageSize, offset: reset ? 0 : _historyOffset);
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
          _upsert(task);
        }
      }
      for (final rawItem in items.whereType<Map>()) {
        final task = TaskItem.fromHistory(Map<String, dynamic>.from(rawItem));
        if (task.id.isNotEmpty) _upsert(task);
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

  Future<void> cancel(TaskItem task) async {
    if (!task.canCancel) return;
    if (task.name == '预览生成') {
      if (ref.read(serverConfigProvider)?.isOmm != true) return;
      await ref.read(mediaRepositoryProvider).cancelPreviewTask(task.id);
      _updateByKey(
        task.key,
        (current) => current.copyWith(
          status: 'canceled',
          isRunning: false,
          message: kTaskMsgCanceled,
        ),
      );
      return;
    }
    final client = ref.read(requiredApiClientProvider);
    Object? raw;
    switch (task.name) {
      case '字幕转译':
        raw = await ref
            .read(audioRepositoryProvider)
            .cancelTranscriptionRaw(task.id);
        break;
      case '音频提取':
        raw = await ref
            .read(audioRepositoryProvider)
            .cancelExtractionRaw(task.id);
        break;
      case 'NFO 同步':
        await client.moviesExtended.cancelNfoSync(task.id);
        break;
      case '演员关联同步':
        raw = await client.mappings.actorExternalSyncBatchCancel(task.id);
        break;
      case '预览图下载':
        await client.moviesExtended.cancelExtraFanart(task.id);
        break;
      default:
        if (task.name.contains('扫描') && task.libraryIds.isNotEmpty) {
          raw = await client.libraries.cancelScan(
            task.libraryIds.first,
            task.id,
          );
        } else {
          raw = await client.moviesExtended.cancelPreviewTask(task.id);
        }
        break;
    }
    _ensureSuccess(
      raw,
      task.name == '字幕转译' ? kTaskErrCancelTranscribe : kTaskErrCancelExtract,
    );
    _updateByKey(
      task.key,
      (current) => current.copyWith(
        status: 'canceled',
        isRunning: false,
        message: kTaskMsgCanceled,
      ),
    );
  }

  Future<void> retry(TaskItem task) async {
    if (!task.canRetry) return;
    final raw = await ref
        .read(audioRepositoryProvider)
        .retryTranscriptionRaw(task.id);
    _ensureSuccess(raw, kTaskErrRetryTranscribe);
    final data = raw is Map ? raw['data'] : null;
    if (data is Map) {
      final retried = TaskItem.fromTranscription(
        Map<String, dynamic>.from(data),
      );
      if (retried.id.isNotEmpty) {
        _upsert(retried);
        return;
      }
    }
    _updateByKey(
      task.key,
      (current) => current.copyWith(
        status: 'queued',
        isRunning: true,
        progress: const TaskProgress(total: 100),
        message: kTaskMsgRequeued,
      ),
    );
  }

  /// 删除服务端终态任务记录。运行中的任务由服务端拒绝删除。
  Future<void> remove(TaskItem task) async {
    if (!task.isTerminal || task.recordId.isEmpty) return;
    await ref.read(requiredApiClientProvider).tasks.delete(task.recordId);
    final next = state.where((item) => item.key != task.key).toList();
    if (next.length != state.length) state = next;
  }

  void restore(TaskItem task) => _upsert(task);

  void _connectWs() {
    unawaited(_connectWsAsync());
  }

  Future<void> _connectWsAsync() async {
    if (_disposed) return;
    final cfg = ref.read(serverConfigProvider);
    if (cfg == null || cfg.baseUrl.trim().isEmpty) {
      _scheduleReconnect();
      return;
    }
    final token = await ref.read(authSessionRepositoryProvider).accessToken();
    if (_disposed) return;
    final resolved = resolveServerUrl(cfg, '/ws/scheduler/status');
    final uri = Uri.parse(
      resolved,
    ).replace(scheme: Uri.parse(resolved).scheme == 'https' ? 'wss' : 'ws');
    final wsUrl = appendQueryToken(uri.toString(), token);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (_, __) => _onDisconnect(),
        onDone: _onDisconnect,
        cancelOnError: false,
      );
      _reconnectAttempts = 0;
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _channel?.sink.add('{"type":"ping"}');
        } catch (_) {}
      });
    } catch (_) {
      _scheduleReconnect();
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

  void _upsert(TaskItem incoming) {
    var index = incoming.recordId.isNotEmpty
        ? state.indexWhere((item) => item.recordId == incoming.recordId)
        : state.indexWhere((item) => item.key == incoming.key);
    if (index < 0 && incoming.recordId.isEmpty && incoming.id.isNotEmpty) {
      index = state.indexWhere(
        (item) =>
            item.id == incoming.id &&
            item.name == incoming.name &&
            item.isActive,
      );
      if (index < 0 && !incoming.isActive) {
        index = state.indexWhere(
          (item) => item.id == incoming.id && item.name == incoming.name,
        );
      }
    }
    if (index < 0 && _isScanTask(incoming)) {
      index = state.indexWhere(
        (item) => item.id == incoming.id && _isScanTask(item),
      );
    }
    if (index < 0 && _isScanTask(incoming)) {
      index = state.indexWhere(
        (item) =>
            item.id.startsWith('scan-placeholder-') &&
            item.libraryIds.any(incoming.libraryIds.contains),
      );
    }

    final next = [...state];
    if (index >= 0) {
      final previous = next[index];
      final merged = previous.merge(incoming);
      // 占位扫描任务拿到真实 id 后 key 会变化，沿用原序号避免卡片跳动。
      if (merged.key != previous.key) {
        final staleOrder = _orderByKey.remove(previous.key);
        if (staleOrder != null) {
          _orderByKey[merged.key] = staleOrder;
        }
      }
      next[index] = merged;
    } else {
      next.insert(0, incoming);
    }
    _sortTasks(next);
    if (next.length > 200) {
      next.removeRange(200, next.length);
    }
    state = next;
  }

  /// 活跃任务置顶，其余保持稳定插入顺序（新的在前）。
  void _sortTasks(List<TaskItem> items) {
    for (final item in items) {
      _orderByKey.putIfAbsent(item.key, () => _orderSeq++);
    }
    items.sort((left, right) {
      if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
      return _orderByKey[right.key]!.compareTo(_orderByKey[left.key]!);
    });
  }

  void _updateByKey(String key, TaskItem Function(TaskItem) update) {
    final index = state.indexWhere((item) => item.key == key);
    if (index < 0) return;
    final next = [...state];
    next[index] = update(next[index]);
    _sortTasks(next);
    state = next;
  }

  void _onDisconnect() {
    if (_disposed) return;
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
    if (_disposed || _reconnectTimer != null) return;
    final exponent = _reconnectAttempts.clamp(0, 4);
    final seconds = (3 * (1 << exponent)).clamp(3, 30);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      _connectWs();
    });
  }

  void _disposeResources() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
  }
}

bool _isScanTask(TaskItem task) {
  return task.name.contains('扫描') && task.name != '资源扫描';
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

void _ensureSuccess(Object? raw, String fallback) {
  if (raw is Map && raw['success'] == false) {
    final message = raw['message']?.toString().trim();
    throw StateError(message == null || message.isEmpty ? fallback : message);
  }
}

final taskCenterProvider = NotifierProvider<TaskCenterNotifier, List<TaskItem>>(
  TaskCenterNotifier.new,
);
