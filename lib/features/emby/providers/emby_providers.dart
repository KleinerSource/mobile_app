import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/auth/auth_provider.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/emby/api/emby_api.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/emby/repositories/emby_media_repository.dart';

final embyMediaRepositoryProvider = Provider<EmbyMediaRepository>((ref) {
  final source = ref.watch(embyMediaSourceProvider);
  if (source == null) {
    throw const SourceException('当前服务器不是 Emby，无法访问媒体目录');
  }
  return EmbyMediaRepository(source);
});

/// Emby 服务器 URL 构造器。
///
/// 海报/背景/直链地址是 baseUrl + api_key 的纯字符串拼接，页面在
/// build 中同步使用；token 在登录态变化时随本 Provider 重建刷新。
class EmbyServerUrls {
  EmbyServerUrls({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  bool get isReady => baseUrl.trim().isNotEmpty;

  String poster(String itemId, {int maxWidth = 440}) => EmbyApi.imageUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    imageType: 'Primary',
    maxWidth: maxWidth,
    token: token,
  );

  String backdrop(String itemId, {int maxWidth = 1280}) => EmbyApi.imageUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    imageType: 'Backdrop',
    maxWidth: maxWidth,
    token: token,
  );

  String thumb(String itemId, {int maxWidth = 440}) => EmbyApi.imageUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    imageType: 'Thumb',
    maxWidth: maxWidth,
    token: token,
  );

  String stream(String itemId, {String? mediaSourceId}) => EmbyApi.streamUrl(
    baseUrl: baseUrl,
    itemId: itemId,
    mediaSourceId: mediaSourceId,
    token: token,
  );
}

final embyServerUrlsProvider = FutureProvider<EmbyServerUrls>((ref) async {
  final config = ref.watch(serverConfigProvider);
  if (config?.activeServer?.project != ServerProject.emby) {
    throw const SourceException('当前服务器不是 Emby，无法访问媒体目录');
  }
  // 依赖登录态：登录/登出会触发重建并刷新 api_key。
  ref.watch(authControllerProvider);
  final token = await ref.read(authSessionRepositoryProvider).accessToken();
  return EmbyServerUrls(baseUrl: config!.baseUrl, token: token);
});

/// 媒体库（Views）。
final embyViewsProvider = FutureProvider.autoDispose<List<EmbyItem>>((
  ref,
) async {
  return ref.watch(embyMediaRepositoryProvider).views();
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
final embyViewLatestProvider = FutureProvider.autoDispose
    .family<List<EmbyItem>, EmbyViewLatestRequest>((ref, request) async {
      _checkServerScope(ref, request.serverId);
      final page = await ref
          .watch(embyMediaRepositoryProvider)
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

class EmbyViewLatestRequest {
  const EmbyViewLatestRequest({
    required this.serverId,
    required this.viewId,
    this.includeItemTypes,
  });

  final String serverId;
  final String viewId;
  final String? includeItemTypes;

  @override
  bool operator ==(Object other) =>
      other is EmbyViewLatestRequest &&
      other.serverId == serverId &&
      other.viewId == viewId &&
      other.includeItemTypes == includeItemTypes;

  @override
  int get hashCode => Object.hash(serverId, viewId, includeItemTypes);
}

/// 首页「最新入库」。
final embyLatestProvider = FutureProvider.autoDispose<List<EmbyItem>>((
  ref,
) async {
  return ref.watch(embyMediaRepositoryProvider).latestMedia(limit: 20);
});

/// 首页「继续观看」。
final embyResumeProvider = FutureProvider.autoDispose<List<EmbyItem>>((
  ref,
) async {
  final page = await ref.watch(embyMediaRepositoryProvider).resumeItems();
  return page.items;
});

/// 首页剧集「接下来观看」。
final embyNextUpProvider = FutureProvider.autoDispose<List<EmbyItem>>((
  ref,
) async {
  final page = await ref.watch(embyMediaRepositoryProvider).nextUp();
  return page.items;
});

/// 库浏览/搜索共用的分页查询。
final embyItemPageProvider = FutureProvider.autoDispose
    .family<EmbyItemPage, EmbyItemPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(embyMediaRepositoryProvider)
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
final embyItemDetailProvider = FutureProvider.autoDispose
    .family<EmbyItem, EmbyItemDetailRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(embyMediaRepositoryProvider).getItem(request.itemId);
    });

/// 剧集的季列表。
final embySeasonsProvider = FutureProvider.autoDispose
    .family<List<EmbyItem>, EmbySeasonsRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(embyMediaRepositoryProvider).seasons(request.seriesId);
    });

/// 某一季的集列表。
final embyEpisodesProvider = FutureProvider.autoDispose
    .family<EmbyItemPage, EmbyEpisodesRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref.watch(embyMediaRepositoryProvider).episodes(request.seasonId);
    });

class EmbyItemPageRequest {
  const EmbyItemPageRequest({
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
      other is EmbyItemPageRequest &&
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

class EmbyItemDetailRequest {
  const EmbyItemDetailRequest({required this.serverId, required this.itemId});

  final String serverId;
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is EmbyItemDetailRequest &&
      other.serverId == serverId &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(serverId, itemId);
}

class EmbySeasonsRequest {
  const EmbySeasonsRequest({required this.serverId, required this.seriesId});

  final String serverId;
  final String seriesId;

  @override
  bool operator ==(Object other) =>
      other is EmbySeasonsRequest &&
      other.serverId == serverId &&
      other.seriesId == seriesId;

  @override
  int get hashCode => Object.hash(serverId, seriesId);
}

class EmbyEpisodesRequest {
  const EmbyEpisodesRequest({required this.serverId, required this.seasonId});

  final String serverId;
  final String seasonId;

  @override
  bool operator ==(Object other) =>
      other is EmbyEpisodesRequest &&
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
