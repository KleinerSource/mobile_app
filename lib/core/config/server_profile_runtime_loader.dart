import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../api/api_client.dart';
import '../api/server_compatibility.dart';
import '../auth/auth_session_provider.dart';
import '../models/system.dart';
import '../../features/media_browser/api/media_browser_api.dart';
import '../../features/media_browser/api/media_browser_config.dart';
import 'server_config.dart';
import 'server_config_provider.dart';

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// 加载 Emby/Jellyfin 当前用户资料并写入进程内缓存。
///
/// 用户头像 URL 可能包含访问令牌，只通过运行时资料传递，不写入磁盘。
Future<ServerProfileData?> loadMediaBrowserUserProfile(
  ProviderReader read,
  ServerProfile server,
) async {
  final project = server.project;
  if (project != ServerProject.emby && project != ServerProject.jellyfin) {
    return null;
  }

  final repository = read(serverProfileCacheRepoProvider);
  final cached = repository.load(server.id);
  final fallback = ServerProfileData(
    name: server.name,
    avatarUrl: server.avatarUrl ?? cached?.avatarUrl,
  );

  void cacheFallback() => repository.saveRuntime(server.id, fallback);

  final line = server.activeLine;
  if (line == null) {
    cacheFallback();
    return fallback;
  }

  final mediaBrowserConfig = MediaBrowserConfig.byProject[project];
  if (mediaBrowserConfig == null) {
    cacheFallback();
    return fallback;
  }

  final sessionRepository = read(
    authSessionRepositoryProvider,
  ).forServer(server.id, allowLegacyMigration: false);

  try {
    final session = await sessionRepository.load();
    if (session == null || !session.hasAccessToken) {
      cacheFallback();
      return fallback;
    }

    final user = await ApiClient.fromConfig(
      ServerConfig(
        baseUrl: line.baseUrl,
        lines: [line],
        servers: [server],
        activeServerId: server.id,
      ),
      sessionRepository: sessionRepository,
      stashApiKeyRepository: read(stashApiKeyRepositoryProvider),
    ).mediaBrowserFor(mediaBrowserConfig).validateSession(session.userId);

    final userId = user.id.trim();
    final profile = ServerProfileData(
      name: user.name.trim().isEmpty ? fallback.name : user.name.trim(),
      avatarUrl: fallback.avatarUrl,
      userAvatarUrl: userId.isEmpty
          ? null
          : MediaBrowserApi.userImageUrl(
              config: mediaBrowserConfig,
              baseUrl: line.baseUrl,
              userId: userId,
              token: session.accessToken,
            ),
    );
    repository.saveRuntime(server.id, profile);
    await repository.save(server.id, profile);
    return profile;
  } catch (_) {
    cacheFallback();
    return fallback;
  }
}
