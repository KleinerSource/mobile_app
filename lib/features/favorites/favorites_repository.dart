import '../../core/api/envelope.dart';
import '../../core/api/services/favorites_api.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../movies/movie_filter.dart';

class FavoritesRepository {
  FavoritesRepository(this._api);
  final FavoritesApi _api;

  Future<PagedResult<MovieListItem>> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final raw = await _api.list(filter.toQuery(limit: limit, offset: offset));
    return unwrapMovieList<MovieListItem>(raw, MovieListItem.fromJson);
  }

  /// 切换收藏状态，返回切换后的 is_favorited 值。
  Future<bool> toggle(int movieId) async {
    final raw = await _api.toggle(movieId);
    return unwrapStd<bool>(raw, (d) {
      if (d is Map && d['is_favorited'] is bool) {
        return d['is_favorited'] as bool;
      }
      return false;
    });
  }

  Future<bool> status(int movieId) async {
    final raw = await _api.status(movieId);
    return unwrapStd<bool>(raw, (d) {
      if (d is Map && d['is_favorited'] is bool) {
        return d['is_favorited'] as bool;
      }
      return false;
    });
  }

  Future<void> addBatch(List<int> movieIds) async {
    final raw = await _api.addBatch({'movie_ids': movieIds});
    unwrapStd<void>(raw, (_) {});
  }

  Future<void> removeBatch(List<int> movieIds) async {
    final raw = await _api.removeBatch({'movie_ids': movieIds});
    unwrapStd<void>(raw, (_) {});
  }
}
