import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/api/media_browser_server_urls.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';

// URL 构造器随 API 层维护（emby/jellyfin 与 feiniu 两套实现），
// 消费方仍可从本文件统一 import。
export 'package:omm/features/media_browser/api/media_browser_server_urls.dart';

/// 当前激活服务器的 MediaBrowser 配置；非 Emby/Jellyfin 服务器时为 null。
///
/// Emby 与 Jellyfin 页面共用同一套实现，项目差异（品牌标签、路径前缀
/// 等）都从这里取。
final mediaBrowserConfigProvider = Provider<MediaBrowserConfig?>((ref) {
  final project = ref.watch(serverConfigProvider)?.activeServer?.project;
  return MediaBrowserConfig.byProject[project];
});

SourceException _notMediaBrowserException() =>
    const SourceException('当前服务器不是可用的媒体服务器，无法访问媒体目录');

final mediaBrowserMediaRepositoryProvider =
    Provider<MediaBrowserMediaRepository>((ref) {
      final config = ref.watch(mediaBrowserConfigProvider);
      if (config == null) {
        throw _notMediaBrowserException();
      }
      final source = ref
          .watch(mediaSourceRegistryProvider)
          .find(SourceId(config.sourceId));
      if (source is! MediaBrowserMediaSource) {
        throw _notMediaBrowserException();
      }
      return MediaBrowserMediaRepository(source);
    });

final mediaBrowserServerUrlsProvider = FutureProvider<MediaBrowserServerUrls>((
  ref,
) async {
  final config = ref.watch(mediaBrowserConfigProvider);
  if (config == null) {
    throw _notMediaBrowserException();
  }
  // 依赖登录态：登录/登出会触发重建并刷新 token。
  ref.watch(authControllerProvider);
  final session = await ref.read(authSessionRepositoryProvider).current();
  final serverConfig = ref.watch(serverConfigProvider);
  final activeServerId = serverConfig?.activeServerId;
  final stashKey = config.project == ServerProject.stash
      ? activeServerId == null
            ? null
            : await ref.read(stashApiKeyRepositoryProvider).read(activeServerId)
      : null;
  return MediaBrowserServerUrls(
    config: config,
    baseUrl: serverConfig!.baseUrl,
    token: config.project == ServerProject.stash
        ? stashKey
        : session?.accessToken,
    cookie: session?.cookie,
  );
});

/// 媒体库（Views）。
final mediaBrowserViewsProvider =
    FutureProvider.autoDispose<List<MediaBrowserItem>>((ref) async {
      return ref.watch(mediaBrowserMediaRepositoryProvider).views();
    });

/// 当前 MediaBrowser 用户；媒体库管理页用它判断管理员权限。
final mediaBrowserCurrentUserProvider =
    FutureProvider.autoDispose<MediaBrowserUser>((ref) async {
      return ref.watch(mediaBrowserMediaRepositoryProvider).currentUser();
    });

/// 管理端虚拟媒体库列表。
final mediaBrowserVirtualFoldersProvider =
    FutureProvider.autoDispose<List<MediaBrowserLibrary>>((ref) async {
      final user = await ref.watch(mediaBrowserCurrentUserProvider.future);
      if (!user.isAdmin) {
        throw const SourceException('媒体库配置需要管理员账号');
      }
      return ref.watch(mediaBrowserMediaRepositoryProvider).virtualFolders();
    });

/// 首页媒体库统计。
final mediaBrowserLibraryStatsProvider =
    FutureProvider.autoDispose<MediaBrowserLibraryStats>((ref) async {
      return ref.watch(mediaBrowserMediaRepositoryProvider).libraryStats();
    });

/// 媒体库类型 → 条目类型过滤。
///
/// 返回 null 有两种含义，用 [isSkippableViewType] 区分：
/// - 跳过：图书/照片等无海报内容的库，首页不出影片行；
/// - 混合库（collectionType 为空）：不加类型过滤，展示全部条目。
String? includeItemTypesForView(String? collectionType) =>
    switch (collectionType?.trim().toLowerCase() ?? '') {
      '' => null,
      'movies' => 'Movie',
      'tvshows' => 'Series',
      'music' => 'MusicAlbum',
      _ => null,
    };

/// 该类型的库是否不在首页出影片行（卡片行仍显示入口）。
bool isSkippableViewType(String? collectionType) {
  final normalized = collectionType?.trim().toLowerCase() ?? '';
  return const {
    'audiobooks',
    'books',
    'photos',
    'games',
    'musicvideos',
    'playlists',
  }.contains(normalized);
}

/// 某个媒体库的「最近添加」横排。
final mediaBrowserViewLatestProvider = FutureProvider.autoDispose
    .family<List<MediaBrowserItem>, MediaBrowserViewLatestRequest>((
      ref,
      request,
    ) async {
      _checkServerScope(ref, request.serverId);
      final page = await ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .itemPage(
            parentId: request.viewId,
            includeItemTypes: request.includeItemTypes,
            recursive: true,
            sortBy: 'DateCreated',
            sortOrder: 'Descending',
            limit: 20,
          );
      return page.items;
    });

class MediaBrowserViewLatestRequest {
  const MediaBrowserViewLatestRequest({
    required this.serverId,
    required this.viewId,
    this.includeItemTypes,
  });

  final String serverId;
  final String viewId;
  final String? includeItemTypes;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserViewLatestRequest &&
      other.serverId == serverId &&
      other.viewId == viewId &&
      other.includeItemTypes == includeItemTypes;

  @override
  int get hashCode => Object.hash(serverId, viewId, includeItemTypes);
}

/// 首页「最新入库」。
final mediaBrowserLatestProvider =
    FutureProvider.autoDispose<List<MediaBrowserItem>>((ref) async {
      return ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .latestMedia(limit: 20);
    });

/// 首页「继续观看」。
final mediaBrowserResumeProvider =
    FutureProvider.autoDispose<List<MediaBrowserItem>>((ref) async {
      final page = await ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .resumeItems();
      return page.items;
    });

/// 首页剧集「接下来观看」。
final mediaBrowserNextUpProvider =
    FutureProvider.autoDispose<List<MediaBrowserItem>>((ref) async {
      final page = await ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .nextUp();
      return page.items;
    });

/// Jellyfin 剧集详情页的「接下来观看」。
///
/// 通过 NextUp 的 ParentId 只取当前剧集，Emby 详情页暂不主动请求该增强
/// 区块；首页的通用 nextUp 仍按原逻辑同时支持 Emby/Jellyfin。
final mediaBrowserSeriesNextUpProvider = FutureProvider.autoDispose
    .family<List<MediaBrowserItem>, MediaBrowserSeriesNextUpRequest>((
      ref,
      request,
    ) async {
      _checkServerScope(ref, request.serverId);
      final page = await ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .nextUp(parentId: request.seriesId, limit: request.limit);
      return page.items;
    });

/// 条目详情页的「更多类似」。
final mediaBrowserSimilarProvider = FutureProvider.autoDispose
    .family<List<MediaBrowserItem>, MediaBrowserSimilarRequest>((
      ref,
      request,
    ) async {
      _checkServerScope(ref, request.serverId);
      final page = await ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .similar(request.itemId, limit: request.limit);
      return page.items
          .where((item) => item.id != request.itemId)
          .toList(growable: false);
    });

/// 库浏览/搜索共用的分页查询。
final mediaBrowserItemPageProvider = FutureProvider.autoDispose
    .family<MediaBrowserItemPage, MediaBrowserItemPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .itemPage(
            parentId: request.parentId,
            includeItemTypes: request.includeItemTypes,
            recursive: request.recursive,
            searchTerm: request.searchTerm,
            sortBy: request.sortBy,
            sortOrder: request.sortOrder,
            startIndex: request.startIndex,
            limit: request.limit,
            isFavorite: request.isFavorite,
          );
    });

/// 命令式读取一页媒体条目（分页控件回调等 build 之外的场景）。
///
/// 不能用 `ref.read(mediaBrowserItemPageProvider(...).future)`：它是
/// autoDispose family，命令式读取不建立监听，element 会在帧末被销毁，
/// in-flight future 永不完成也不抛错，页面表现为无限加载。
Future<MediaBrowserItemPage> readMediaBrowserItemPage(
  WidgetRef ref,
  MediaBrowserItemPageRequest request,
) {
  final activeServerId = ref.read(serverConfigProvider)?.activeServerId ?? '';
  if (request.serverId != activeServerId) {
    throw const SourceException('媒体请求已过期，请重新加载当前服务器');
  }
  return ref
      .read(mediaBrowserMediaRepositoryProvider)
      .itemPage(
        parentId: request.parentId,
        includeItemTypes: request.includeItemTypes,
        recursive: request.recursive,
        searchTerm: request.searchTerm,
        sortBy: request.sortBy,
        sortOrder: request.sortOrder,
        startIndex: request.startIndex,
        limit: request.limit,
        isFavorite: request.isFavorite,
        personIds: request.personIds,
      );
}

/// 条目详情（电影/剧集通用）。
final mediaBrowserItemDetailProvider = FutureProvider.autoDispose
    .family<MediaBrowserItem, MediaBrowserItemDetailRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .getItem(request.itemId);
    });

/// 剧集的季列表。
final mediaBrowserSeasonsProvider = FutureProvider.autoDispose
    .family<List<MediaBrowserItem>, MediaBrowserSeasonsRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .seasons(request.seriesId);
    });

/// 某一季的集列表。
final mediaBrowserEpisodesProvider = FutureProvider.autoDispose
    .family<MediaBrowserItemPage, MediaBrowserEpisodesRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .episodes(request.seriesId, request.seasonId);
    });

/// 专辑的曲目列表（按光盘号 + 曲号排序）。
final mediaBrowserAlbumTracksProvider = FutureProvider.autoDispose
    .family<List<MediaBrowserItem>, MediaBrowserAlbumTracksRequest>((
      ref,
      request,
    ) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(mediaBrowserMediaRepositoryProvider)
          .albumTracks(request.albumId);
    });

class MediaBrowserAlbumTracksRequest {
  const MediaBrowserAlbumTracksRequest({
    required this.serverId,
    required this.albumId,
  });

  final String serverId;
  final String albumId;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserAlbumTracksRequest &&
      other.serverId == serverId &&
      other.albumId == albumId;

  @override
  int get hashCode => Object.hash(serverId, albumId);
}

class MediaBrowserItemPageRequest {
  const MediaBrowserItemPageRequest({
    required this.serverId,
    this.parentId,
    this.includeItemTypes,
    this.recursive,
    this.searchTerm,
    this.sortBy,
    this.sortOrder,
    this.startIndex = 0,
    this.limit = 24,
    this.isFavorite,
    this.personIds,
  });

  final String serverId;
  final String? parentId;
  final String? includeItemTypes;
  final bool? recursive;
  final String? searchTerm;
  final String? sortBy;
  final String? sortOrder;
  final int startIndex;
  final int limit;
  final bool? isFavorite;

  /// 按演员/人物过滤（PersonIds），演员作品页使用。
  final String? personIds;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserItemPageRequest &&
      other.serverId == serverId &&
      other.parentId == parentId &&
      other.includeItemTypes == includeItemTypes &&
      other.recursive == recursive &&
      other.searchTerm == searchTerm &&
      other.sortBy == sortBy &&
      other.sortOrder == sortOrder &&
      other.startIndex == startIndex &&
      other.limit == limit &&
      other.isFavorite == isFavorite &&
      other.personIds == personIds;

  @override
  int get hashCode => Object.hash(
    serverId,
    parentId,
    includeItemTypes,
    recursive,
    searchTerm,
    sortBy,
    sortOrder,
    startIndex,
    limit,
    isFavorite,
    personIds,
  );
}

class MediaBrowserItemDetailRequest {
  const MediaBrowserItemDetailRequest({
    required this.serverId,
    required this.itemId,
  });

  final String serverId;
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserItemDetailRequest &&
      other.serverId == serverId &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(serverId, itemId);
}

class MediaBrowserSeriesNextUpRequest {
  const MediaBrowserSeriesNextUpRequest({
    required this.serverId,
    required this.seriesId,
    this.limit = 12,
  });

  final String serverId;
  final String seriesId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserSeriesNextUpRequest &&
      other.serverId == serverId &&
      other.seriesId == seriesId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(serverId, seriesId, limit);
}

class MediaBrowserSimilarRequest {
  const MediaBrowserSimilarRequest({
    required this.serverId,
    required this.itemId,
    this.limit = 12,
  });

  final String serverId;
  final String itemId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserSimilarRequest &&
      other.serverId == serverId &&
      other.itemId == itemId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(serverId, itemId, limit);
}

class MediaBrowserSeasonsRequest {
  const MediaBrowserSeasonsRequest({
    required this.serverId,
    required this.seriesId,
  });

  final String serverId;
  final String seriesId;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserSeasonsRequest &&
      other.serverId == serverId &&
      other.seriesId == seriesId;

  @override
  int get hashCode => Object.hash(serverId, seriesId);
}

class MediaBrowserEpisodesRequest {
  const MediaBrowserEpisodesRequest({
    required this.serverId,
    required this.seriesId,
    required this.seasonId,
  });

  final String serverId;
  final String seriesId;
  final String seasonId;

  @override
  bool operator ==(Object other) =>
      other is MediaBrowserEpisodesRequest &&
      other.serverId == serverId &&
      other.seriesId == seriesId &&
      other.seasonId == seasonId;

  @override
  int get hashCode => Object.hash(serverId, seriesId, seasonId);
}

void _checkServerScope(Ref ref, String requestServerId) {
  final activeServerId = ref.read(serverConfigProvider)?.activeServerId ?? '';
  if (requestServerId != activeServerId) {
    throw const SourceException('媒体请求已过期，请重新加载当前服务器');
  }
}
