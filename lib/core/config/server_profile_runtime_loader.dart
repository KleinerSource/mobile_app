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

/// 返回服务器的用户界面显示名称。
///
/// OMM 服务端已移除自定义服务器名称，名称来源固定为用户的本地配置；
/// 其它支持服务端身份名称的项目仍可按调用方要求使用资料缓存中的名称。
String serverDisplayName(
  ServerProfile server,
  ServerProfileData? profile, {
  bool useRemoteName = true,
}) {
  if (server.project == ServerProject.ohMyMedia || !useRemoteName) {
    return server.name;
  }
  final remoteName = profile?.name.trim() ?? '';
  return remoteName.isNotEmpty ? remoteName : server.name;
}

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
