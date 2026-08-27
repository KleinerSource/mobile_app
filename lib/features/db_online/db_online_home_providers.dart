import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/db_online_movie.dart';

final dbOnlineRecommendProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref.watch(requiredApiClientProvider).dbOnline.recommend();
    });

final dbOnlineLatestUpdatedProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .latest(sortBy: 'update');
    });

final dbOnlineLatestReleasedProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .latest(sortBy: 'release');
    });

/// 全部列表页按排序方式读取单页数据；页面本身负责在滚动到底部时请求下一页。
final dbOnlineLatestPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineLatestPageRequest>((ref, request) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .latestPage(
            page: request.page,
            limit: request.limit,
            sortBy: request.sortBy,
            sort: request.sort,
          );
    });

final dbOnlineSearchPageProvider = FutureProvider.autoDispose
    .family<DbOnlineMoviePage, DbOnlineSearchPageRequest>((ref, request) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .searchPage(
            query: request.query,
            page: request.page,
            limit: request.limit,
          );
    });

class DbOnlineLatestPageRequest {
  const DbOnlineLatestPageRequest({
    required this.page,
    required this.limit,
    required this.sortBy,
    this.sort,
  });

  final int page;
  final int limit;
  final String sortBy;
  final String? sort;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineLatestPageRequest &&
      other.page == page &&
      other.limit == limit &&
      other.sortBy == sortBy &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(page, limit, sortBy, sort);
}

class DbOnlineSearchPageRequest {
  const DbOnlineSearchPageRequest({
    required this.query,
    required this.page,
    required this.limit,
  });

  final String query;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineSearchPageRequest &&
      other.query == query &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(query, page, limit);
}

final dbOnlineMovieDetailProvider = FutureProvider.autoDispose
    .family<DbOnlineMovieDetail, String>((ref, code) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .detail(code, refresh: true);
    });

final dbOnlineMovieDetailByVideoIdProvider = FutureProvider.autoDispose
    .family<DbOnlineMovieDetail, String>((ref, videoId) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .detailByVideoId(videoId, refresh: true);
    });

final dbOnlinePlayEpisodesProvider = FutureProvider.autoDispose
    .family<DbOnlinePlayEpisodes, DbOnlinePlayRequest>((ref, request) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .onlinePlayEpisodes(
            request.code,
            sourceId: request.sourceId,
            videoId: request.videoId,
          );
    });

class DbOnlinePlayRequest {
  const DbOnlinePlayRequest({
    required this.code,
    required this.sourceId,
    this.videoId,
  });

  final String code;
  final int sourceId;
  final String? videoId;

  @override
  bool operator ==(Object other) =>
      other is DbOnlinePlayRequest &&
      other.code == code &&
      other.sourceId == sourceId &&
      other.videoId == videoId;

  @override
  int get hashCode => Object.hash(code, sourceId, videoId);
}
