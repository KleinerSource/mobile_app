import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../api/server_connection.dart';
import '../../api/server_compatibility.dart';
import '../../auth/auth_session_provider.dart';
import '../common/source_id.dart';
import '../common/source_exception.dart';
import 'dbo_media_source_adapter.dart';
import 'dbo_media_source.dart';
import 'feiniu_media_source_adapter.dart';
import 'media_browser_media_source_adapter.dart';
import 'stash_media_source_adapter.dart';
import 'media_source.dart';
import 'omm_media_source_adapter.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_config.dart';
import 'package:omm/core/api/error_codes.dart';

/// Provides the media sources for the currently selected server.
///
/// A server profile represents one backend project, so only its matching
/// adapter is registered.  Watching [requiredApiClientProvider] makes Riverpod
/// recreate the registry after a server or line switch.
final mediaSourceRegistryProvider = Provider<MediaSourceRegistry>((ref) {
  // onDispose 必须先于 ref.watch 注册：watch 到脏依赖（如刚切换服务器后的
  // apiClient 链）时，Riverpod 会在本次 build 内同步 flush 并立即 invalidate
  // 本元素，之后再注册 onDispose 会抛
  // "Cannot call onDispose after a provider was dispose"。
  final registry = MediaSourceRegistry(const []);
  void Function()? unregisterLease;
  ref.onDispose(() {
    unregisterLease?.call();
    unawaited(registry.dispose());
  });
  final client = ref.watch(requiredApiClientProvider);
  final lease = client.connectionLease;
  if (lease == null || !lease.isActive) {
    throw const ServerConnectionClosedException();
  }
  unregisterLease = lease.register(() => unawaited(registry.dispose()));
  final project = client.config?.activeServer?.project;
  final MediaSource source;
  if (project == ServerProject.dbOnline) {
    source = DboMediaSourceAdapter(
      client.dbOnline,
      serverId: client.config?.activeServerId,
      endpoint: client.config?.baseUrl,
    );
  } else if (project == ServerProject.emby ||
      project == ServerProject.jellyfin) {
    final mediaBrowserConfig = MediaBrowserConfig.byProject[project]!;
    source = MediaBrowserMediaSourceAdapter(
      client.mediaBrowserFor(mediaBrowserConfig),
      sessionRepository: ref
          .read(authSessionRepositoryProvider)
          .forServer(
            client.config?.activeServerId,
            allowLegacyMigration: false,
          ),
      serverId: client.config?.activeServerId,
      endpoint: client.config?.baseUrl,
    );
  } else if (project == ServerProject.feiniu) {
    source = FeiniuMediaSourceAdapter(
      client.feiniu,
      sessionRepository: ref
          .read(authSessionRepositoryProvider)
          .forServer(
            client.config?.activeServerId,
            allowLegacyMigration: false,
          ),
      serverId: client.config?.activeServerId,
      endpoint: client.config?.baseUrl,
    );
  } else if (project == ServerProject.stash) {
    source = StashMediaSourceAdapter(
      client.stash,
      serverId: client.config?.activeServerId,
      endpoint: client.config?.baseUrl,
    );
  } else if (project == ServerProject.ohMyMedia) {
    source = OmmMediaSourceAdapter(client);
  } else {
    throw const SourceException(
      AppErrorCode.operationFailed,
      code: AppErrorCode.operationFailed,
    );
  }
  registry.register(source);
  return registry;
});

final ommMediaSourceProvider = Provider<OmmMediaSourceAdapter?>((ref) {
  final source = ref
      .watch(mediaSourceRegistryProvider)
      .find(const SourceId('omm'));
  return source is OmmMediaSourceAdapter ? source : null;
});

final dboMediaSourceProvider = Provider<DboMediaSource?>((ref) {
  final source = ref
      .watch(mediaSourceRegistryProvider)
      .find(const SourceId('dbo'));
  return source is DboMediaSource ? source : null;
});
