import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/models/db_online_search.dart';

/// DBO 保留给 Feature 的在线目录扩展能力。
///
/// 这些方法返回 DBO 自有 DTO，供 DBO 专属页面使用；请求仍由 Source
/// Adapter 负责，页面和 Provider 不直接接触 `DbOnlineApi`。
abstract interface class DboMediaOperationsSource {
  Future<DbOnlineMovieDetail> getMovieByCode(String code, {String? videoId});

  Future<DbOnlineMovieDetail> getMovieByVideoId(String videoId);

  Future<DbOnlinePlayEpisodes> getPlayEpisodes({
    required String code,
    required int sourceId,
    String? videoId,
  });

  Future<DbOnlineActorSearchResult> searchActors({required String query});

  Future<DbOnlineSearchEntityPage> searchSeriesPage({
    required String query,
    int page = 1,
    int limit = 24,
  });
}
