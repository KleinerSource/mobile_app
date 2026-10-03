import 'dart:typed_data';

import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_search.dart';
import 'package:omm/core/sources/media/dbo/db_online_subtitle.dart';
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
    String filterBy = '0:t:::::',
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
    String movieType = 'all',
    String movieSortBy = 'relevance',
    String movieFilterBy = 'all',
  }) async {
    return _toMoviePage(
      await _source.searchMovies(
        source_models.MediaQuery(
          mode: source_models.MediaCatalogMode.search,
          searchText: query,
          page: page,
          limit: limit,
          filters: {
            'movie_type': movieType,
            'movie_sort_by': movieSortBy,
            'movie_filter_by': movieFilterBy,
          },
        ),
      ),
    );
  }

  Future<DbOnlineActorSearchResult> searchActors({required String query}) =>
      _source.searchActors(query: query);

  Future<DbOnlineSearchEntityPage> searchEntitiesPage({
    required String type,
    required String query,
    int page = 1,
    int limit = 24,
  }) => _source.searchEntitiesPage(
    type: type,
    query: query,
    page: page,
    limit: limit,
  );

  Future<List<DbOnlineSubtitleFile>> findSubtitles(String code) =>
      _source.findSubtitles(code);

  Future<List<DbOnlineSubtitleCandidate>> searchExternalSubtitles(
    String code,
  ) => _source.searchExternalSubtitles(code);

  Future<DbOnlineSubtitlePreview> previewLocalSubtitle(String id) =>
      _source.previewLocalSubtitle(id);

  Future<DbOnlineSubtitlePreview> previewExternalSubtitle(String url) =>
      _source.previewExternalSubtitle(url);

  Future<Uint8List> downloadLocalSubtitle(String id) =>
      _source.downloadLocalSubtitle(id);

  Future<Uint8List> downloadExternalSubtitle({
    required String url,
    required String name,
    required String extension,
  }) => _source.downloadExternalSubtitle(
    url: url,
    name: name,
    extension: extension,
  );

  Future<DbOnlineMovieDetail> getMovieByCode(
    String code, {
    String? videoId,
    bool refresh = true,
  }) => _source.getMovieByCode(code, videoId: videoId, refresh: refresh);

  Future<DbOnlineMovieDetail> getMovieByVideoId(
    String videoId, {
    bool refresh = true,
  }) => _source.getMovieByVideoId(videoId, refresh: refresh);

  Future<DbOnlineExternalResources> getCustomResources(String code) =>
      _source.getCustomResources(code);

  Future<DbOnlineExternalResources> getNyaaResources(String code) =>
      _source.getNyaaResources(code);

  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(String code) => _source.getDownloadHistory(code);

  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() => _source.getDownloaders();

  Future<({String message, String downloader})> pushDownload({
    required List<String> urls,
    required String downloader,
    required Map<String, dynamic> videoInfo,
    required List<Map<String, dynamic>> recordResources,
  }) => _source.pushDownload(
    urls: urls,
    downloader: downloader,
    videoInfo: videoInfo,
    recordResources: recordResources,
  );

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
