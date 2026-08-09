import '../../core/api/envelope.dart';
import '../../core/api/services/favorites_api.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../movies/movie_filter.dart';

class FavoriteStats {
  const FavoriteStats({
    required this.watchedCount,
    required this.watchedMinutes,
  });

  final int watchedCount;
  final int watchedMinutes;

  factory FavoriteStats.fromJson(Map<String, dynamic> json) {
    return FavoriteStats(
      watchedCount: (json['watched_count'] as num?)?.toInt() ?? 0,
      watchedMinutes: (json['watched_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  int get hours => watchedMinutes ~/ 60;
}

class FavoritePage {
  const FavoritePage({required this.page, required this.stats});

  final PagedResult<MovieListItem> page;
  final FavoriteStats? stats;
}

class FavoritesRepository {
  FavoritesRepository(this._api);
  final FavoritesApi _api;

  Future<FavoritePage> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final raw = await _api.list(filter.toQuery(limit: limit, offset: offset));
    // 注意: /favorites 返回的 items 是 [{movie: {...}, favorited_at, ...}], 不是 [movie] 直接。
    // 解出 item.movie 再 decode 成 MovieListItem。
    final page = unwrapMovieList<MovieListItem>(raw, (json) {
      // 兼容两种 schema:
      //  · {movie: {id, title, ...}, favorited_at, ...}  → 取 movie
      //  · {id, title, ...}                              → 直接 decode
      final movieJson = json['movie'];
      if (movieJson is Map) {
        return MovieListItem.fromJson(Map<String, dynamic>.from(movieJson));
      }
      return MovieListItem.fromJson(json);
    });
    final data = raw is Map && raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : null;
    final statsRaw = data?['stats'];
    return FavoritePage(
      page: page,
      stats: statsRaw is Map
          ? FavoriteStats.fromJson(Map<String, dynamic>.from(statsRaw))
          : null,
    );
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
