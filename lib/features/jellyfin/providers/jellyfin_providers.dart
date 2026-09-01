import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/jellyfin/api/jellyfin_api.dart';
import 'package:omm/features/jellyfin/models/jellyfin_models.dart';
import 'package:omm/features/jellyfin/repositories/jellyfin_media_repository.dart';

final jellyfinMediaRepositoryProvider = Provider<JellyfinMediaRepository>((ref) {
  final source = ref.watch(jellyfinMediaSourceProvider);
  if (source == null) {
    throw const SourceException('当前服务器不是 Jellyfin，无法访问媒体目录');
  }
  return JellyfinMediaRepository(source);
});

/// Jellyfin 服务器 URL 构造器。
///
/// 海报/背景/直链地址是 baseUrl + ApiKey 的纯字符串拼接，页面在
/// build 中同步使用；token 在登录态变化时随本 Provider 重建刷新。
class JellyfinServerUrls {
  JellyfinServerUrls({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  bool get isReady => baseUrl.trim().isNotEmpty;

  String poster(String itemId, {int maxWidth = 440}) => JellyfinApi.imageUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    imageType: 'Primary',
    maxWidth: maxWidth,
    token: token,
  );

  String backdrop(String itemId, {int maxWidth = 1280}) => JellyfinApi.imageUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    imageType: 'Backdrop',
    maxWidth: maxWidth,
    token: token,
  );

  String thumb(String itemId, {int maxWidth = 440}) => JellyfinApi.imageUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    imageType: 'Thumb',
    maxWidth: maxWidth,
    token: token,
  );

  String stream(String itemId, {String? mediaSourceId}) => JellyfinApi.streamUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    mediaSourceId: mediaSourceId,
    token: token,
  );
}

final jellyfinServerUrlsProvider = FutureProvider<JellyfinServerUrls>((ref) async {
  final config = ref.watch(serverConfigProvider);
  if (config?.activeServer?.project != ServerProject.jellyfin) {
    throw const SourceException('当前服务器不是 Jellyfin，无法访问媒体目录');
  }
  // 依赖登录态：登录/登出会触发重建并刷新 ApiKey。
  ref.watch(authControllerProvider);
  final token = await ref.read(authSessionRepositoryProvider).accessToken();
  return JellyfinServerUrls(baseUrl: config!.baseUrl, token: token);
});

/// 媒体库（Views）。
final jellyfinViewsProvider = FutureProvider.autoDispose<List<JellyfinItem>>((
  ref,
) async {
  return ref.watch(jellyfinMediaRepositoryProvider).views();
});

/// 媒体库类型 → 条目类型过滤。
///
/// 返回 null 有两种含义，用 [isSkippableViewType] 区分：
/// - 跳过：音乐/图书等无海报内容的库，首页不出影片行；
/// - 混合库（collectionType 为空）：不加类型过滤，展示全部条目。
String? includeItemTypesForView(String? collectionType) => switch (
      collectionType?.trim().toLowerCase() ?? ''
    ) {
      '' => null,
      'movies' => 'Movie',
      'tvshows' => 'Series',
      _ => null,
    };

/// 该类型的库是否不在首页出影片行（卡片行仍显示入口）。
bool isSkippableViewType(String? collectionType) {
  final normalized = collectionType?.trim().toLowerCase() ?? '';
  return const {
    'music',
    'audiobooks',
    'books',
    'photos',
    'games',
    'musicvideos',
    'playlists',
  }.contains(normalized);
}

/// 某个媒体库的「最近添加」横排。
final jellyfinViewLatestProvider = FutureProvider.autoDispose
    .family<List<JellyfinItem>, JellyfinViewLatestRequest>((ref, request) async {
      _checkServerScope(ref, request.serverId);
      final page = await ref
          .watch(jellyfinMediaRepositoryProvider)
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

class JellyfinViewLatestRequest {
  const JellyfinViewLatestRequest({
    required this.serverId,
    required this.viewId,
    this.includeItemTypes,
  });

  final String serverId;
  final String viewId;
  final String? includeItemTypes;

  @override
  bool operator ==(Object other) =>
      other is JellyfinViewLatestRequest &&
      other.serverId == serverId &&
      other.viewId == viewId &&
      other.includeItemTypes == includeItemTypes;

  @override
  int get hashCode => Object.hash(serverId, viewId, includeItemTypes);
}

/// 首页「最新入库」。
final jellyfinLatestProvider = FutureProvider.autoDispose<List<JellyfinItem>>((
  ref,
) async {
  return ref.watch(jellyfinMediaRepositoryProvider).latestMedia(limit: 20);
});

/// 首页「继续观看」。
final jellyfinResumeProvider = FutureProvider.autoDispose<List<JellyfinItem>>((
  ref,
) async {
  final page = await ref.watch(jellyfinMediaRepositoryProvider).resumeItems();
  return page.items;
});

/// 首页剧集「接下来观看」。
final jellyfinNextUpProvider = FutureProvider.autoDispose<List<JellyfinItem>>((
  ref,
) async {
  final page = await ref.watch(jellyfinMediaRepositoryProvider).nextUp();
  return page.items;
});

/// 库浏览/搜索共用的分页查询。
final jellyfinItemPageProvider = FutureProvider.autoDispose
    .family<JellyfinItemPage, JellyfinItemPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(jellyfinMediaRepositoryProvider)
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
final jellyfinItemDetailProvider = FutureProvider.autoDispose
    .family<JellyfinItem, JellyfinItemDetailRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(jellyfinMediaRepositoryProvider).getItem(request.itemId);
    });

/// 剧集的季列表。
final jellyfinSeasonsProvider = FutureProvider.autoDispose
    .family<List<JellyfinItem>, JellyfinSeasonsRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(jellyfinMediaRepositoryProvider).seasons(request.seriesId);
    });

/// 某一季的集列表。
final jellyfinEpisodesProvider = FutureProvider.autoDispose
    .family<JellyfinItemPage, JellyfinEpisodesRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(jellyfinMediaRepositoryProvider).episodes(request.seasonId);
    });

class JellyfinItemPageRequest {
  const JellyfinItemPageRequest({
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
      other is JellyfinItemPageRequest &&
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

class JellyfinItemDetailRequest {
  const JellyfinItemDetailRequest({required this.serverId, required this.itemId});

  final String serverId;
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is JellyfinItemDetailRequest &&
      other.serverId == serverId &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(serverId, itemId);
}

class JellyfinSeasonsRequest {
  const JellyfinSeasonsRequest({required this.serverId, required this.seriesId});

  final String serverId;
  final String seriesId;

  @override
  bool operator ==(Object other) =>
      other is JellyfinSeasonsRequest &&
      other.serverId == serverId &&
      other.seriesId == seriesId;

  @override
  int get hashCode => Object.hash(serverId, seriesId);
}

class JellyfinEpisodesRequest {
  const JellyfinEpisodesRequest({required this.serverId, required this.seasonId});

  final String serverId;
  final String seasonId;

  @override
  bool operator ==(Object other) =>
      other is JellyfinEpisodesRequest &&
      other.serverId == serverId &&
      other.seasonId == seasonId;

  @override
  int get hashCode => Object.hash(serverId, seasonId);
}

void _checkServerScope(Ref ref, String requestServerId) {
  final activeServerId =
      ref.read(serverConfigProvider)?.activeServerId ?? '';
  if (requestServerId != activeServerId) {
    throw const SourceException('媒体请求已过期，请重新加载当前服务器');
  }
}
