import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/models/db_online_search.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'package:omm/features/db_online/repositories/dbo_media_repository.dart';

final dboMediaRepositoryProvider = Provider<DboMediaRepository>((ref) {
  final source = ref.watch(dboMediaSourceProvider);
  if (source == null) {
    throw const SourceException('当前服务器不是 DBO，无法访问在线媒体目录');
  }
  return DboMediaRepository(source);
});

final dbOnlineRecommendProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref.watch(dboMediaRepositoryProvider).recommend();
    });

final dbOnlineLatestUpdatedProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref.watch(dboMediaRepositoryProvider).latest(sortBy: 'update');
    });

final dbOnlineLatestReleasedProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref.watch(dboMediaRepositoryProvider).latest(sortBy: 'release');
    });

/// 全部列表页按排序方式读取单页数据；页面本身负责在滚动到底部时请求下一页。
final dbOnlineLatestPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineLatestPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .latestPage(
            page: request.page,
            limit: request.limit,
            sortBy: request.sortBy,
            sort: request.sort,
          );
    });

/// DBO 影片库按分类、排序方式和顺序读取一页数据。
final dbOnlineLibraryPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineLibraryPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .taggedMoviesPage(
            filterBy: request.filterBy,
            page: request.page,
            limit: request.limit,
            sortBy: request.sortBy,
            orderBy: request.orderBy,
          );
    });

final dbOnlineSearchPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineSearchPageRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .searchPage(
            query: request.query,
            page: request.page,
            limit: request.limit,
          );
    });

final dbOnlineActorSearchProvider = FutureProvider.autoDispose
    .family<DbOnlineActorSearchResult, String>((ref, query) {
      return ref.watch(dboMediaRepositoryProvider).searchActors(query: query);
    });

final dbOnlineSeriesSearchPageProvider = FutureProvider.autoDispose
    .family<DbOnlineSearchEntityPage, DbOnlineSeriesSearchPageRequest>((
      ref,
      request,
    ) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .searchSeriesPage(
            query: request.query,
            page: request.page,
            limit: request.limit,
          );
    });

class DbOnlineLatestPageRequest {
  const DbOnlineLatestPageRequest({
    required this.serverId,
    required this.page,
    required this.limit,
    required this.sortBy,
    this.sort,
  });

  final String serverId;
  final int page;
  final int limit;
  final String sortBy;
  final String? sort;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineLatestPageRequest &&
      other.serverId == serverId &&
      other.page == page &&
      other.limit == limit &&
      other.sortBy == sortBy &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(serverId, page, limit, sortBy, sort);
}

class DbOnlineLibraryPageRequest {
  const DbOnlineLibraryPageRequest({
    required this.serverId,
    required this.page,
    required this.limit,
    this.filterBy = '0:t:p::::',
    this.sortBy = 'update',
    this.orderBy = 'desc',
  });

  final String serverId;
  final int page;
  final int limit;
  final String filterBy;
  final String sortBy;
  final String orderBy;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineLibraryPageRequest &&
      other.serverId == serverId &&
      other.page == page &&
      other.limit == limit &&
      other.filterBy == filterBy &&
      other.sortBy == sortBy &&
      other.orderBy == orderBy;

  @override
  int get hashCode =>
      Object.hash(serverId, page, limit, filterBy, sortBy, orderBy);
}

class DbOnlineSearchPageRequest {
  const DbOnlineSearchPageRequest({
    required this.serverId,
    required this.query,
    required this.page,
    required this.limit,
  });

  final String serverId;
  final String query;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineSearchPageRequest &&
      other.serverId == serverId &&
      other.query == query &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(serverId, query, page, limit);
}

class DbOnlineSeriesSearchPageRequest {
  const DbOnlineSeriesSearchPageRequest({
    required this.serverId,
    required this.query,
    required this.page,
    required this.limit,
  });

  final String serverId;
  final String query;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineSeriesSearchPageRequest &&
      other.serverId == serverId &&
      other.query == query &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(serverId, query, page, limit);
}

class DbOnlineMovieDetailRequest {
  const DbOnlineMovieDetailRequest({
    required this.serverId,
    required this.value,
  });

  final String serverId;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineMovieDetailRequest &&
      other.serverId == serverId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(serverId, value);
}

final dbOnlineMovieDetailProvider = FutureProvider.autoDispose
    .family<DbOnlineMovieDetail, DbOnlineMovieDetailRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .getMovieByCode(request.value);
    });

final dbOnlineMovieDetailByVideoIdProvider = FutureProvider.autoDispose
    .family<DbOnlineMovieDetail, DbOnlineMovieDetailRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .getMovieByVideoId(request.value);
    });

final dbOnlinePlayEpisodesProvider = FutureProvider.autoDispose
    .family<DbOnlinePlayEpisodes, DbOnlinePlayRequest>((ref, request) {
      _checkServerScope(ref, request.serverId);
      return ref
          .watch(dboMediaRepositoryProvider)
          .getPlayEpisodes(
            code: request.code,
            sourceId: request.sourceId,
            videoId: request.videoId,
          );
    });

class DbOnlinePlayRequest {
  const DbOnlinePlayRequest({
    required this.serverId,
    required this.code,
    required this.sourceId,
    this.videoId,
  });

  final String serverId;
  final String code;
  final int sourceId;
  final String? videoId;

  @override
  bool operator ==(Object other) =>
      other is DbOnlinePlayRequest &&
      other.serverId == serverId &&
      other.code == code &&
      other.sourceId == sourceId &&
      other.videoId == videoId;

  @override
  int get hashCode => Object.hash(serverId, code, sourceId, videoId);
}

void _checkServerScope(Ref ref, String requestServerId) {
  final activeServerId = ref.watch(serverConfigProvider)?.activeServerId ?? '';
  if (requestServerId != activeServerId) {
    throw const SourceException('DBO 请求已过期，请重新加载当前服务器');
  }
}
