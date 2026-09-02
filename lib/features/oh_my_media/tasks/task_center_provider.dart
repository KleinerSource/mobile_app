import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/library.dart';
import 'package:omm/features/oh_my_media/audio/audio_providers.dart';
import 'task_model.dart';

/// 所有后台任务的统一状态源。
///
/// 后端 `/ws/scheduler/status` 会在连接建立时推送当前活跃任务，之后继续
/// 推送实时进度。任务中心保留本次会话中收到的终态记录，方便用户查看结果。
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
    unawaited(refresh());
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
    if (task.id.isEmpty) return;
    _upsert(task);
  }

  Future<void> refresh() async {
    try {
      final raw = await ref
          .read(audioRepositoryProvider)
          .listTranscriptions(limit: 100, offset: 0);
      if (raw is! Map || raw['success'] != true) return;
      final data = raw['data'];
      final items = data is Map && data['items'] is List
          ? data['items'] as List
          : data is List
          ? data
          : const <dynamic>[];
      for (final rawItem in items.whereType<Map>()) {
        final task = TaskItem.fromTranscription(
          Map<String, dynamic>.from(rawItem),
        );
        if (task.id.isNotEmpty) _upsert(task);
      }
    } catch (_) {
      // WebSocket 仍可独立工作；服务器未配置或接口不可用时不打断任务页。
    }
  }

  Future<void> cancel(TaskItem task) async {
    if (!task.canCancel) return;
    final raw = task.name == '字幕转译'
        ? await ref
              .read(audioRepositoryProvider)
              .cancelTranscriptionRaw(task.id)
        : await ref.read(audioRepositoryProvider).cancelExtractionRaw(task.id);
    _ensureSuccess(
      raw,
      task.name == '字幕转译'
          ? kTaskErrCancelTranscribe
          : kTaskErrCancelExtract,
    );
    _updateByKey(
      task.key,
      (current) => current.copyWith(
        status: task.name == '字幕转译' ? 'canceled' : 'canceled',
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

  /// 删除当前客户端会话中的任务记录。
  ///
  /// 后端没有提供通用的历史任务删除接口，因此不影响服务端任务，只移除
  /// 任务中心当前展示的记录。刷新或再次收到该任务广播时，记录可能重新出现。
  void remove(TaskItem task) {
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
    var index = state.indexWhere((item) => item.key == incoming.key);
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

void _ensureSuccess(Object? raw, String fallback) {
  if (raw is Map && raw['success'] == false) {
    final message = raw['message']?.toString().trim();
    throw StateError(message == null || message.isEmpty ? fallback : message);
  }
}

final taskCenterProvider = NotifierProvider<TaskCenterNotifier, List<TaskItem>>(
  TaskCenterNotifier.new,
);
