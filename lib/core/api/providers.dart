import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session_provider.dart';
import '../config/server_config.dart';
import '../config/server_runtime.dart';
import 'api_client.dart';
import 'server_connection.dart';

typedef _ApiConnectionIdentity = ({
  String serverId,
  String? projectName,
  String? activeLineId,
  String lineId,
  String baseUrl,
  bool enabled,
});

_ApiConnectionIdentity? _apiConnectionIdentity(ServerConfig? config) {
  final server = config?.activeServer;
  final line = server?.activeLine;
  if (server == null || line == null) return null;
  return (
    serverId: server.id,
    projectName: server.projectName,
    activeLineId: server.activeLineId,
    lineId: line.id,
    baseUrl: line.baseUrl,
    enabled: line.enabled,
  );
}

/// 仅在已配置服务器地址时返回 ApiClient；未配置时返回 null。
final apiClientProvider = Provider<ApiClient?>((ref) {
  final identity = ref.watch(
    mediaRuntimeConfigProvider.select(_apiConnectionIdentity),
  );
  if (identity == null) return null;
  final cfg = ref.read(mediaRuntimeConfigProvider);
  if (cfg == null) return null;
  final connection = ref.watch(mediaServerConnectionProvider);
  final lease = connection.lease;
  if (!connection.accepts(identity.serverId) || lease == null) return null;
  final sessionRepository = ref.read(authSessionRepositoryProvider);
  final client = ApiClient.fromConfig(
    cfg,
    sessionRepository: sessionRepository,
    stashApiKeyRepository: ref.read(stashApiKeyRepositoryProvider),
    connectionLease: lease,
    onSessionExpired: () =>
        markAuthExpired(ref, identity.serverId, generation: lease.generation),
    onStashApiKeyInvalid: () =>
        markAuthExpired(ref, identity.serverId, generation: lease.generation),
  );
  final unregister = lease.register(client.close);
  ref.onDispose(() {
    unregister();
    client.close();
  });
  return client;
});

/// 强制要求已配置；未配置时抛错。
final requiredApiClientProvider = Provider<ApiClient>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw const ServerConnectionClosedException();
  }
  return client;
});
