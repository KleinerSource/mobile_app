import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api/url_resolver.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/models/library.dart';
import 'libraries_providers.dart';

/// 一个正在跟踪的扫描任务 · 跨页面共享
@immutable
class TrackedScan {
  const TrackedScan({
    required this.libraryId,
    required this.libraryName,
    required this.taskId,
    this.task,
  });

  final String taskId;
  final int libraryId;
  final String libraryName;
  final ScanTask? task;

  TrackedScan copyWith({String? taskId, ScanTask? task}) => TrackedScan(
        libraryId: libraryId,
        libraryName: libraryName,
        taskId: taskId ?? this.taskId,
        task: task ?? this.task,
      );

  bool get isActive => task?.isActive ?? true;
}

/// 后端 ws 推送的实时状态: 用 progress 数据补完 ScanTask
class _WsState {
  _WsState({
    required this.isRunning,
    required this.total,
    required this.completed,
    required this.percent,
    required this.message,
  });
  final bool isRunning;
  final int total;
  final int completed;
  final double percent;
  final String message;
}

/// 全局扫描任务管理 · 实时通过 /ws/scheduler/status 监听任务进度
class ScanTasksNotifier extends StateNotifier<List<TrackedScan>> {
  ScanTasksNotifier(this._ref) : super(const []) {
    _connectWs();
  }

  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  /// 启动扫描后注册 · taskId 可能为空, 之后 ws 推送会自动补充
  void register({
    required int libraryId,
    required String libraryName,
    required String taskId,
  }) {
    final filtered = state.where((s) => s.libraryId != libraryId).toList();
    state = [
      ...filtered,
      TrackedScan(
        libraryId: libraryId,
        libraryName: libraryName,
        taskId: taskId,
      ),
    ];
    // 主动拉一次, 让 dock 立即出现 (即使 ws 还没消息)
    _refreshOnceFallback(libraryId);
  }

  void remove(int libraryId) {
    state = state.where((s) => s.libraryId != libraryId).toList();
  }

  /// 启动后只拉一次, 让 dock 在 ws 还没收到推送前就有数据
  Future<void> _refreshOnceFallback(int libraryId) async {
    try {
      final repo = _ref.read(librariesRepositoryProvider);
      final active = await repo.activeScans(libraryId);
      if (active.isEmpty || !mounted) return;
      final t = active.first;
      state = [
        for (final s in state)
          if (s.libraryId == libraryId)
            s.copyWith(
                taskId: s.taskId.isEmpty ? t.taskId : s.taskId, task: t)
          else
            s,
      ];
    } catch (_) {}
  }

  void _connectWs() {
    _connectWsAsync();
  }

  Future<void> _connectWsAsync() async {
    if (_disposed) return;
    final cfg = _ref.read(serverConfigProvider);
    if (cfg == null) {
      _scheduleReconnect();
      return;
    }
    final base = cfg.baseUrl.trim();
    if (base.isEmpty) {
      _scheduleReconnect();
      return;
    }
    final token = await _ref.read(authSessionRepositoryProvider).accessToken();
    if (_disposed) return;
    final wsUrl = _toWsUrl(cfg, token);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
        cancelOnError: false,
      );
      _reconnectAttempts = 0;
      // 心跳
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

  String _toWsUrl(ServerConfig cfg, String? token) {
    final resolved = resolveServerUrl(cfg, '/ws/scheduler/status');
    final uri = Uri.parse(resolved);
    final wsUri = uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
    );
    return appendQueryToken(wsUri.toString(), token);
  }

  void _onMessage(dynamic raw) {
    try {
      final s = raw is String ? raw : raw.toString();
      final m = jsonDecode(s);
      if (m is! Map) return;
      if (m['type'] == 'pong') return;
      if (m['type'] != 'scheduler_status') return;
      // 仅处理扫描类: taskName 不是 NFO/演员
      final taskName = (m['taskName'] ?? '').toString();
      if (taskName == 'NFO 同步' || taskName == '演员关联同步') return;

      final taskId = (m['taskId'] ?? '').toString();
      if (taskId.isEmpty) return;
      final isRunning = m['isRunning'] == true;
      final prog = m['progress'];
      final total = prog is Map && prog['total'] is num
          ? (prog['total'] as num).toInt()
          : 0;
      final completed = prog is Map && prog['completed'] is num
          ? (prog['completed'] as num).toInt()
          : 0;
      final percent = prog is Map && prog['percent'] is num
          ? (prog['percent'] as num).toDouble()
          : 0.0;
      final message = (m['message'] ?? '').toString();

      _applyWsUpdate(
        taskId: taskId,
        ws: _WsState(
          isRunning: isRunning,
          total: total,
          completed: completed,
          percent: percent,
          message: message,
        ),
      );
    } catch (_) {}
  }

  void _applyWsUpdate({required String taskId, required _WsState ws}) {
    // 找到对应的 TrackedScan: 用 taskId 或者占位的 (taskId 为空) 第一个
    final list = [...state];
    var idx = list.indexWhere((s) => s.taskId == taskId);
    if (idx < 0) {
      idx = list.indexWhere((s) => s.taskId.isEmpty);
    }
    if (idx < 0) return; // 这是别人触发的扫描, 我们没注册

    final cur = list[idx];
    if (!ws.isRunning) {
      // 任务完成 / 取消, 直接移除
      list.removeAt(idx);
      state = list;
      return;
    }

    // 合并到 ScanTask · 字段映射保持与 ScanTask 一致
    final existing = cur.task;
    final updated = ScanTask(
      taskId: taskId,
      libraryId: cur.libraryId,
      status: 'running',
      totalFiles: ws.total,
      processedFiles: ws.completed,
      currentFile: ws.message,
      addedFiles: existing?.addedFiles ?? 0,
      updatedFiles: existing?.updatedFiles ?? 0,
      removedFiles: existing?.removedFiles ?? 0,
    );
    list[idx] = cur.copyWith(taskId: taskId, task: updated);
    state = list;
  }

  void _onDisconnect() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay =
        Duration(seconds: (3 * (1 << _reconnectAttempts.clamp(0, 4))).clamp(3, 30));
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _connectWs);
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }
}

final scanTasksProvider =
    StateNotifierProvider<ScanTasksNotifier, List<TrackedScan>>(
  (ref) => ScanTasksNotifier(ref),
);
