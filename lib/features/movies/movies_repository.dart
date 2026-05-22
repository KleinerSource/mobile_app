import '../../core/api/api_exception.dart';
import '../../core/api/envelope.dart';
import '../../core/api/services/favorites_api.dart';
import '../../core/api/services/movies_api.dart';
import '../../core/models/media_info.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import 'movie_filter.dart';

class MoviesRepository {
  MoviesRepository(this._api, this._favorites);
  final MoviesApi _api;
  final FavoritesApi _favorites;

  Future<PagedResult<MovieListItem>> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final raw = await _api.getMovies(filter.toQuery(limit: limit, offset: offset));
    return unwrapMovieList<MovieListItem>(raw, MovieListItem.fromJson);
  }

  Future<MovieDetail> detail(int id) async {
    final raw = await _api.getMovieDetail(id);
    return unwrapStd<MovieDetail>(
      raw,
      (d) => MovieDetail.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<List<String>> extraFanarts(int id) async {
    final raw = await _api.getExtraFanarts(id);
    return unwrapStd<List<String>>(raw, (d) {
      if (d is List) {
        return d.whereType<String>().toList();
      }
      return const <String>[];
    });
  }

  Future<MediaInfo?> mediaInfo(int id) async {
    try {
      final raw = await _api.getMediaInfo(id);
      return unwrapStd<MediaInfo?>(raw, (d) {
        if (d is Map) {
          return MediaInfo.fromJson(Map<String, dynamic>.from(d));
        }
        return null;
      });
    } on ApiException {
      // backend returns 404 when no media info; surface as null instead of error
      return null;
    }
  }

  Future<bool> toggleFavorite(int id) async {
    final raw = await _favorites.toggle(id);
    return unwrapStd<bool>(raw, (d) {
      if (d is Map) {
        final v = d['is_favorited'];
        return v == true;
      }
      return false;
    });
  }

  Future<void> markWatched(int id, bool completed) async {
    await _api.upsertWatchRecord(id, {'completed': completed});
  }
}
