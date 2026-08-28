import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/models/db_online_search.dart';
import 'package:omm/core/sources/media/dbo_media_source.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;

/// DBO Feature 的 Source 门面。
///
/// 页面仍使用既有 `DbOnline*` 模型，Source 负责网络协议和通用模型；
/// 这里仅做兼容映射，避免把 DBO DTO 扩散到通用媒体能力接口之外。
class DboMediaRepository {
  DboMediaRepository(this._source);

  final DboMediaSource _source;

  Future<List<DbOnlineMovie>> recommend({int page = 1, int limit = 9}) async {
    final result = await _source.listMovies(
      source_models.MediaQuery(
        mode: source_models.MediaCatalogMode.recommended,
        page: page,
        limit: limit,
      ),
    );
    return _movies(result);
  }

  Future<List<DbOnlineMovie>> latest({
    int page = 1,
    int limit = 9,
    String? sortBy,
    String? sort,
  }) async {
    final result = await latestPage(
      page: page,
      limit: limit,
      sortBy: sortBy,
      sort: sort,
    );
    return result.movies;
  }

  Future<DbOnlineMoviePage> latestPage({
    int page = 1,
    int limit = 9,
    String? sortBy,
    String? sort,
  }) async {
    return _toMoviePage(
      await _source.listMovies(
        source_models.MediaQuery(
          mode: source_models.MediaCatalogMode.latest,
          page: page,
          limit: limit,
          sortBy: sortBy,
          orderBy: sort,
        ),
      ),
    );
  }

  Future<DbOnlineMoviePage> taggedMoviesPage({
    String filterBy = '0:t:p::::',
    int page = 1,
    int limit = 24,
    String sortBy = 'update',
    String orderBy = 'desc',
  }) async {
    return _toMoviePage(
      await _source.listMovies(
        source_models.MediaQuery(
          mode: source_models.MediaCatalogMode.tagged,
          tagFilter: filterBy,
          page: page,
          limit: limit,
          sortBy: sortBy,
          orderBy: orderBy,
        ),
      ),
    );
  }

  Future<DbOnlineMoviePage> searchPage({
    required String query,
    int page = 1,
    int limit = 24,
  }) async {
    return _toMoviePage(
      await _source.searchMovies(
        source_models.MediaQuery(
          mode: source_models.MediaCatalogMode.search,
          searchText: query,
          page: page,
          limit: limit,
        ),
      ),
    );
  }

  Future<DbOnlineActorSearchResult> searchActors({required String query}) =>
      _source.searchActors(query: query);

  Future<DbOnlineSearchEntityPage> searchSeriesPage({
    required String query,
    int page = 1,
    int limit = 24,
  }) => _source.searchSeriesPage(query: query, page: page, limit: limit);

  Future<DbOnlineMovieDetail> getMovieByCode(String code, {String? videoId}) =>
      _source.getMovieByCode(code, videoId: videoId);

  Future<DbOnlineMovieDetail> getMovieByVideoId(String videoId) =>
      _source.getMovieByVideoId(videoId);

  Future<DbOnlinePlayEpisodes> getPlayEpisodes({
    required String code,
    required int sourceId,
    String? videoId,
  }) =>
      _source.getPlayEpisodes(code: code, sourceId: sourceId, videoId: videoId);

  List<DbOnlineMovie> _movies(
    source_models.MediaPage<source_models.MediaSummary> page,
  ) => page.items.map(_movie).toList(growable: false);

  DbOnlineMoviePage _toMoviePage(
    source_models.MediaPage<source_models.MediaSummary> page,
  ) => DbOnlineMoviePage(
    movies: _movies(page),
    page: page.page,
    limit: page.limit,
    total: page.total,
    hasMore: page.hasMore,
  );

  DbOnlineMovie _movie(source_models.MediaSummary item) {
    final payload = item.payload;
    if (payload is DbOnlineMovie) return payload;
    return DbOnlineMovie(
      id: item.ref.value,
      number: item.code ?? '',
      title: item.title,
      coverUrl: item.poster,
      thumbUrl: item.thumbnail,
      score: item.rating,
      canPlay: item.canPlay,
    );
  }
}
