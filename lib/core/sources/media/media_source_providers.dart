import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../api/server_compatibility.dart';
import '../../auth/auth_session_provider.dart';
import '../common/source_id.dart';
import '../common/source_exception.dart';
import 'dbo_media_source_adapter.dart';
import 'dbo_media_source.dart';
import 'media_browser_media_source.dart';
import 'media_browser_media_source_adapter.dart';
import 'media_models.dart';
import 'media_source.dart';
import 'omm_media_source_adapter.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';

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
  ref.onDispose(() => unawaited(registry.dispose()));
  final client = ref.watch(requiredApiClientProvider);
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
      sessionRepository: ref.read(authSessionRepositoryProvider),
      serverId: client.config?.activeServerId,
      endpoint: client.config?.baseUrl,
    );
  } else if (project == ServerProject.ohMyMedia) {
    source = OmmMediaSourceAdapter(client);
  } else {
    throw const SourceException('当前服务器没有可用的媒体来源');
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

/// 当前服务器的 MediaBrowser（Emby/Jellyfin）媒体源。
///
/// Emby 与 Jellyfin 共用同一 adapter，按注册的 SourceId 区分。
MediaBrowserMediaSource? _mediaBrowserSource(Ref ref, SourceId id) {
  final source = ref.watch(mediaSourceRegistryProvider).find(id);
  return source is MediaBrowserMediaSource ? source : null;
}

final embyMediaSourceProvider = Provider<MediaBrowserMediaSource?>((ref) {
  return _mediaBrowserSource(ref, const SourceId('emby'));
});

final jellyfinMediaSourceProvider = Provider<MediaBrowserMediaSource?>((ref) {
  return _mediaBrowserSource(ref, const SourceId('jellyfin'));
});

class MediaCatalogRequest {
  const MediaCatalogRequest({
    required this.serverId,
    required this.sourceId,
    required this.query,
  });

  final String serverId;
  final SourceId sourceId;
  final MediaQuery query;

  @override
  bool operator ==(Object other) =>
      other is MediaCatalogRequest &&
      other.serverId == serverId &&
      other.sourceId == sourceId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(serverId, sourceId, query);
}

class MediaMovieDetailRequest {
  const MediaMovieDetailRequest({required this.serverId, required this.movie});

  final String serverId;
  final MediaRef movie;

  @override
  bool operator ==(Object other) =>
      other is MediaMovieDetailRequest &&
      other.serverId == serverId &&
      other.movie == movie;

  @override
  int get hashCode => Object.hash(serverId, movie);
}

class MediaPlaybackRequest {
  const MediaPlaybackRequest({
    required this.serverId,
    required this.movie,
    required this.request,
  });

  final String serverId;
  final MediaRef movie;
  final PlaybackRequest request;

  @override
  bool operator ==(Object other) =>
      other is MediaPlaybackRequest &&
      other.serverId == serverId &&
      other.movie == movie &&
      other.request == request;

  @override
  int get hashCode => Object.hash(serverId, movie, request);
}

class MediaResourceRequest {
  const MediaResourceRequest({
    required this.serverId,
    required this.movie,
    this.category,
  });

  final String serverId;
  final MediaRef movie;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is MediaResourceRequest &&
      other.serverId == serverId &&
      other.movie == movie &&
      other.category == category;

  @override
  int get hashCode => Object.hash(serverId, movie, category);
}

class MediaLibraryRequest {
  const MediaLibraryRequest({required this.serverId, this.library});

  final String serverId;
  final MediaRef? library;

  @override
  bool operator ==(Object other) =>
      other is MediaLibraryRequest &&
      other.serverId == serverId &&
      other.library == library;

  @override
  int get hashCode => Object.hash(serverId, library);
}

class MediaScanRequest {
  const MediaScanRequest({
    required this.serverId,
    required this.library,
    this.jobId,
  });

  final String serverId;
  final MediaRef library;
  final String? jobId;

  @override
  bool operator ==(Object other) =>
      other is MediaScanRequest &&
      other.serverId == serverId &&
      other.library == library &&
      other.jobId == jobId;

  @override
  int get hashCode => Object.hash(serverId, library, jobId);
}

final mediaCatalogPageProvider = FutureProvider.autoDispose
    .family<MediaPage<MediaSummary>, MediaCatalogRequest>((ref, request) async {
      final source = ref
          .watch(mediaSourceRegistryProvider)
          .find(request.sourceId);
      final activeServerId = ref
          .read(requiredApiClientProvider)
          .config
          ?.activeServerId;
      if (request.serverId != (activeServerId ?? '')) {
        throw const SourceException('媒体请求已过期，请重新加载当前服务器');
      }
      if (source is! CatalogSource) {
        throw const UnsupportedSourceCapabilityException('catalog');
      }
      return (source as CatalogSource).listMovies(request.query);
    });

final mediaMovieDetailProvider = FutureProvider.autoDispose
    .family<MediaDetails, MediaMovieDetailRequest>((ref, request) async {
      final source = ref
          .watch(mediaSourceRegistryProvider)
          .find(request.movie.sourceId);
      final activeServerId = ref
          .read(requiredApiClientProvider)
          .config
          ?.activeServerId;
      if (request.serverId != (activeServerId ?? '')) {
        throw const SourceException('媒体请求已过期，请重新加载当前服务器');
      }
      if (source is! MovieDetailSource) {
        throw const UnsupportedSourceCapabilityException('movieDetails');
      }
      return (source as MovieDetailSource).getMovie(request.movie);
    });

final mediaPlaybackProvider = FutureProvider.autoDispose
    .family<PlaybackDescriptor, MediaPlaybackRequest>((ref, request) async {
      final source = ref
          .watch(mediaSourceRegistryProvider)
          .find(request.movie.sourceId);
      _checkServerScope(ref, request.serverId);
      if (source is! PlaybackSource) {
        throw const UnsupportedSourceCapabilityException('playback');
      }
      return (source as PlaybackSource).resolvePlayback(
        request.movie,
        request.request,
      );
    });

final mediaResourceProvider = FutureProvider.autoDispose
    .family<List<MediaResource>, MediaResourceRequest>((ref, request) async {
      final source = ref
          .watch(mediaSourceRegistryProvider)
          .find(request.movie.sourceId);
      _checkServerScope(ref, request.serverId);
      if (source is! ResourceSource) {
        throw const UnsupportedSourceCapabilityException('resources');
      }
      return (source as ResourceSource).listResources(
        request.movie,
        category: request.category,
      );
    });

final mediaLibrariesProvider = FutureProvider.autoDispose
    .family<List<MediaLibrary>, String>((ref, serverId) async {
      final registry = ref.watch(mediaSourceRegistryProvider);
      _checkServerScope(ref, serverId);
      final source = registry.sources
          .whereType<LibraryManagementSource>()
          .firstOrNull;
      if (source == null) {
        throw const UnsupportedSourceCapabilityException('libraryManagement');
      }
      return source.listLibraries();
    });

final mediaLibraryFoldersProvider = FutureProvider.autoDispose
    .family<List<MediaLibraryFolder>, MediaLibraryRequest>((
      ref,
      request,
    ) async {
      final registry = ref.watch(mediaSourceRegistryProvider);
      _checkServerScope(ref, request.serverId);
      final library = request.library;
      final source = registry.sources
          .whereType<LibraryManagementSource>()
          .firstOrNull;
      if (source == null) {
        throw const UnsupportedSourceCapabilityException('libraryManagement');
      }
      if (library == null) {
        throw const SourceException('读取媒体库目录需要有效的媒体库 ID');
      }
      return source.listFolders(library);
    });

final activeMediaScansProvider = FutureProvider.autoDispose
    .family<List<ScanJob>, MediaScanRequest>((ref, request) async {
      final registry = ref.watch(mediaSourceRegistryProvider);
      _checkServerScope(ref, request.serverId);
      final source = registry.sources.whereType<ScanSource>().firstOrNull;
      if (source == null) {
        throw const UnsupportedSourceCapabilityException('scanning');
      }
      return source.activeScans(request.library);
    });

final mediaScanProgressProvider = FutureProvider.autoDispose
    .family<ScanJob, MediaScanRequest>((ref, request) async {
      final registry = ref.watch(mediaSourceRegistryProvider);
      _checkServerScope(ref, request.serverId);
      final jobId = request.jobId?.trim() ?? '';
      if (jobId.isEmpty) throw const SourceException('扫描任务 ID 不能为空');
      final source = registry.sources.whereType<ScanSource>().firstOrNull;
      if (source == null) {
        throw const UnsupportedSourceCapabilityException('scanning');
      }
      return source.scanProgress(request.library, jobId);
    });

void _checkServerScope(Ref ref, String requestServerId) {
  final activeServerId =
      ref.read(requiredApiClientProvider).config?.activeServerId ?? '';
  if (requestServerId != activeServerId) {
    throw const SourceException('媒体请求已过期，请重新加载当前服务器');
  }
}
