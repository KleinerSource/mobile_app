import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_session_repository.dart';
import 'server_credentials_repository.dart';
import '../api/server_connection.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return AuthSessionRepository();
});

final serverCredentialsRepositoryProvider =
    Provider<ServerCredentialsRepository>((ref) {
      return ServerCredentialsRepository();
    });

final stashApiKeyRepositoryProvider = Provider<StashApiKeyRepository>((ref) {
  return StashApiKeyRepository(
    repository: ref.read(serverCredentialsRepositoryProvider),
  );
});

@immutable
class AuthExpiryEvent {
  const AuthExpiryEvent({
    required this.id,
    required this.serverId,
    this.generation = 0,
  });

  final int id;
  final String? serverId;
  final int generation;
}

/// 最近一次由受保护请求发现的鉴权失效事件。事件只用于触发一次自动
/// 凭据恢复，不保存任何 token、Cookie 或长期凭据。
final authExpiryEventProvider = StateProvider<AuthExpiryEvent?>((ref) => null);

class AuthExpiryTracker {
  int? _handledId;

  bool claim(AuthExpiryEvent event) {
    if (_handledId == event.id) return false;
    _handledId = event.id;
    return true;
  }
}

final authExpiryTrackerProvider = Provider<AuthExpiryTracker>((ref) {
  return AuthExpiryTracker();
});

/// 由 API 客户端回调标记当前服务器的会话失效。
void markAuthExpired(Ref ref, String? serverId, {int? generation}) {
  final connection = ref.read(serverConnectionProvider);
  final effectiveGeneration = generation ?? connection.generation;
  final normalizedServerId = serverId?.trim();
  if (!connection.accepts(normalizedServerId) ||
      connection.generation != effectiveGeneration) {
    return;
  }
  final next = ref.read(authExpiryProvider) + 1;
  ref.read(authExpiryEventProvider.notifier).state = AuthExpiryEvent(
    id: next,
    serverId: normalizedServerId?.isEmpty == true ? null : normalizedServerId,
    generation: effectiveGeneration,
  );
  ref.read(authExpiryProvider.notifier).state = next;
}

/// HTTP 请求发现会话失效时递增，启动状态控制器据此重新检查服务器。
final authExpiryProvider = StateProvider<int>((ref) => 0);
