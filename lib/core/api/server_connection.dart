import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_runtime.dart';
import 'error_codes.dart';

typedef ServerConnectionCancelCallback = void Function();

/// 一次服务器连接代际。切换服务器时先取消旧 lease，所有已注册资源会在
/// 同一个同步调用栈内收到关闭通知，迟到的异步结果也可据此判定为过期。
class ServerConnectionLease {
  ServerConnectionLease({required this.serverId, required this.generation});

  final String serverId;
  final int generation;
  final Set<ServerConnectionCancelCallback> _callbacks = {};
  bool _cancelled = false;

  bool get isActive => !_cancelled;

  VoidCallback register(ServerConnectionCancelCallback callback) {
    if (_cancelled) {
      _invoke(callback);
      return () {};
    }
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final callbacks = _callbacks.toList(growable: false);
    _callbacks.clear();
    for (final callback in callbacks) {
      _invoke(callback);
    }
  }

  static void _invoke(ServerConnectionCancelCallback callback) {
    try {
      callback();
    } catch (_) {
      // 单个资源关闭失败不能阻止其它连接立即断开。
    }
  }
}

@immutable
class ServerConnectionState {
  const ServerConnectionState({
    required this.serverId,
    required this.generation,
    required this.suspended,
    required this.lease,
  });

  final String? serverId;
  final int generation;
  final bool suspended;
  final ServerConnectionLease? lease;

  bool accepts(String? candidateServerId) {
    final normalized = candidateServerId?.trim() ?? '';
    return !suspended &&
        normalized.isNotEmpty &&
        normalized == serverId &&
        lease?.isActive == true;
  }

  bool owns(ServerConnectionLease candidate) =>
      accepts(candidate.serverId) &&
      generation == candidate.generation &&
      identical(lease, candidate);
}

class ServerConnectionClosedException implements Exception {
  const ServerConnectionClosedException([
    this.message = AppErrorCode.connectionClosed,
  ]);

  final String message;

  @override
  String toString() => message;
}

final mediaServerConnectionProvider =
    NotifierProvider<ServerConnectionController, ServerConnectionState>(
      () => ServerConnectionController(ServerRuntimeLane.media),
    );

final fileServerConnectionProvider =
    NotifierProvider<ServerConnectionController, ServerConnectionState>(
      () => ServerConnectionController(ServerRuntimeLane.files),
    );

/// 兼容仍未迁移的媒体调用点；文件调用必须使用 [fileServerConnectionProvider]。
final serverConnectionProvider = mediaServerConnectionProvider;

final visibleServerConnectionProvider = Provider<ServerConnectionState>((ref) {
  final lane = ref.watch(
    serverRuntimeProvider.select((runtime) => runtime.visibleLane),
  );
  return switch (lane) {
    ServerRuntimeLane.media => ref.watch(mediaServerConnectionProvider),
    ServerRuntimeLane.files => ref.watch(fileServerConnectionProvider),
    null => const ServerConnectionState(
      serverId: null,
      generation: 0,
      suspended: true,
      lease: null,
    ),
  };
});

class ServerConnectionController extends Notifier<ServerConnectionState> {
  ServerConnectionController(this.lane);

  final ServerRuntimeLane lane;
  int _nextGeneration = 0;

  @override
  ServerConnectionState build() {
    ref.listen<String?>(
      serverRuntimeProvider.select((runtime) => runtime.serverIdFor(lane)),
      (_, serverId) {
        if (serverId == null ||
            (!state.suspended && state.serverId != serverId)) {
          suspend();
        }
      },
    );
    return _activeState(null);
  }

  void suspend({String? expectedServerId}) {
    final current = state;
    final expected = expectedServerId?.trim() ?? '';
    if (expected.isNotEmpty &&
        current.serverId != null &&
        current.serverId != expected) {
      return;
    }
    current.lease?.cancel();
    state = ServerConnectionState(
      serverId: current.serverId ?? (expected.isEmpty ? null : expected),
      generation: ++_nextGeneration,
      suspended: true,
      lease: null,
    );
  }

  ServerConnectionLease activate(String? serverId) {
    final normalized = serverId?.trim() ?? '';
    if (normalized.isEmpty) {
      suspend();
      throw const ServerConnectionClosedException();
    }
    state.lease?.cancel();
    final lease = ServerConnectionLease(
      serverId: normalized,
      generation: ++_nextGeneration,
    );
    state = ServerConnectionState(
      serverId: normalized,
      generation: lease.generation,
      suspended: false,
      lease: lease,
    );
    return lease;
  }

  ServerConnectionState _activeState(String? serverId) {
    final normalized = serverId?.trim() ?? '';
    if (normalized.isEmpty) {
      return ServerConnectionState(
        serverId: null,
        generation: ++_nextGeneration,
        suspended: true,
        lease: null,
      );
    }
    final lease = ServerConnectionLease(
      serverId: normalized,
      generation: ++_nextGeneration,
    );
    return ServerConnectionState(
      serverId: normalized,
      generation: lease.generation,
      suspended: false,
      lease: lease,
    );
  }
}
