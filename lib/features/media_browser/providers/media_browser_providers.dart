import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_browser_media_source.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/media_browser/api/media_browser_api.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/repositories/media_browser_media_repository.dart';

/// 当前激活服务器的 MediaBrowser 配置；非 Emby/Jellyfin 服务器时为 null。
///
/// Emby 与 Jellyfin 页面共用同一套实现，项目差异（品牌标签、路径前缀
/// 等）都从这里取。
final mediaBrowserConfigProvider = Provider<MediaBrowserConfig?>((ref) {
  final project = ref.watch(serverConfigProvider)?.activeServer?.project;
  return MediaBrowserConfig.byProject[project];
});

SourceException _notMediaBrowserException() =>
    const SourceException('当前服务器不是 Emby/Jellyfin，无法访问媒体目录');

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

/// Emby/Jellyfin 服务器 URL 构造器。
///
/// 海报/背景地址在 build 中同步拼接，不拼 token（图片端点默认免鉴权，
/// 且磁盘缓存按整条 URL 为 key，token 轮换会打穿缓存），改拼图片 tag
/// 保证换图后缓存失效；直链与鉴权封面仍带 token，登录态变化时随本
/// Provider 重建刷新。
class MediaBrowserServerUrls {
  MediaBrowserServerUrls({
    required this.config,
    required this.baseUrl,
    this.token,
  });

  final MediaBrowserConfig config;
  final String baseUrl;
  final String? token;

  bool get isReady => baseUrl.trim().isNotEmpty;

  String poster(String itemId, {int maxWidth = 440, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        imageType: 'Primary',
        maxWidth: maxWidth,
        tag: tag,
      );

  String backdrop(String itemId, {int maxWidth = 1280, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        imageType: 'Backdrop',
        maxWidth: maxWidth,
        tag: tag,
      );

  String thumb(String itemId, {int maxWidth = 440, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        imageType: 'Thumb',
        maxWidth: maxWidth,
        tag: tag,
      );

  /// 带 token 的封面直连地址，供绕过图片缓存、用无鉴权裸 Dio 下载的
  /// 场景（通知栏封面）；产物是按 itemId 命名的临时文件，不存在缓存
  /// key 失稳问题。
  String authedPoster(String itemId, {int maxWidth = 600, String? tag}) =>
      MediaBrowserApi.imageUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        maxWidth: maxWidth,
        tag: tag,
        token: token,
      );

  /// 条目首选展示图（首页/详情 Hero、继续观看宽卡共用）：有背景图取
  /// Backdrop，否则有海报取 Primary，两者皆无返回 null。带 image tag，
  /// 服务器换图后 URL 变化，旧缓存自然失效。
  String? heroImage(MediaBrowserItem item) {
    if (item.backdropImageTags.isNotEmpty) {
      return backdrop(item.id, tag: item.backdropImageTags.first);
    }
    if (item.primaryImageTag != null) {
      return poster(item.id, tag: item.primaryImageTag);
    }
    return null;
  }

  String stream(String itemId, {String? mediaSourceId}) =>
      MediaBrowserApi.streamUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        token: token,
      );

  String audioStream(String itemId, {String? mediaSourceId}) =>
      MediaBrowserApi.audioStreamUrl(
        config: config,
        baseUrl: baseUrl,
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        token: token,
      );
}

final mediaBrowserServerUrlsProvider = FutureProvider<MediaBrowserServerUrls>((
  ref,
) async {
  final config = ref.watch(mediaBrowserConfigProvider);
  if (config == null) {
    throw _notMediaBrowserException();
  }
  // 依赖登录态：登录/登出会触发重建并刷新 token。
  ref.watch(authControllerProvider);
  final token = await ref.read(authSessionRepositoryProvider).accessToken();
  return MediaBrowserServerUrls(
    config: config,
    baseUrl: ref.watch(serverConfigProvider)!.baseUrl,
    token: token,
  );
});

/// 媒体库（Views）。
final mediaBrowserViewsProvider =
    FutureProvider.autoDispose<List<MediaBrowserItem>>((ref) async {
      return ref.watch(mediaBrowserMediaRepositoryProvider).views();
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
      other.isFavorite == isFavorite;

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
