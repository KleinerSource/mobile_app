import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config.dart';
import '../config/server_config_provider.dart';
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

final serverConnectionProvider =
    NotifierProvider<ServerConnectionController, ServerConnectionState>(
      ServerConnectionController.new,
    );

class ServerConnectionController extends Notifier<ServerConnectionState> {
  int _nextGeneration = 0;

  @override
  ServerConnectionState build() {
    final initialServerId = ref.read(serverConfigProvider)?.activeServerId;
    ref.listen<ServerConfig?>(serverConfigProvider, (previous, next) {
      final nextServerId = next?.activeServerId;
      if (nextServerId == null || nextServerId.trim().isEmpty) {
        suspend();
        return;
      }
      // 显式切换期间配置可能短暂提交目标服务器；只有切换控制器完成
      // 事务后才能重新开放请求入口。
      if (!state.suspended && state.serverId != nextServerId) {
        activate(nextServerId);
      }
    });
    return _activeState(initialServerId);
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
