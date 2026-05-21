import '../../core/api/envelope.dart';
import '../../core/api/services/movies_api.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import 'movie_filter.dart';

class MoviesRepository {
  MoviesRepository(this._api);
  final MoviesApi _api;

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
}
