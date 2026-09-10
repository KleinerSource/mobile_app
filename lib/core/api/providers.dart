import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session_provider.dart';
import '../config/server_config_provider.dart';
import 'api_client.dart';
import 'server_connection.dart';

/// 仅在已配置服务器地址时返回 ApiClient；未配置时返回 null。
final apiClientProvider = Provider<ApiClient?>((ref) {
  final cfg = ref.watch(serverConfigProvider);
  if (cfg == null) return null;
  final connection = ref.watch(serverConnectionProvider);
  final lease = connection.lease;
  if (!connection.accepts(cfg.activeServerId) || lease == null) return null;
  final sessionRepository = ref.read(authSessionRepositoryProvider);
  final client = ApiClient.fromConfig(
    cfg,
    sessionRepository: sessionRepository,
    stashApiKeyRepository: ref.read(stashApiKeyRepositoryProvider),
    connectionLease: lease,
    onSessionExpired: () =>
        markAuthExpired(ref, cfg.activeServerId, generation: lease.generation),
    onStashApiKeyInvalid: () =>
        markAuthExpired(ref, cfg.activeServerId, generation: lease.generation),
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
