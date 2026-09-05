import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';

class FavoriteStats {
  const FavoriteStats({
    required this.watchedCount,
    required this.watchedMinutes,
  });

  final int watchedCount;
  final int watchedMinutes;

  factory FavoriteStats.fromMovies(Iterable<MovieListItem> movies) {
    var watchedCount = 0;
    var watchedMinutes = 0;
    for (final movie in movies) {
      final record = movie.watchRecord;
      if (record == null) continue;
      if (record.completed) watchedCount++;
      if (movie.runtime != null && movie.runtime! > 0) {
        final ratio = record.completed ? 1.0 : record.progressRatio;
        watchedMinutes += (movie.runtime! * ratio.clamp(0.0, 1.0)).round();
      }
    }
    return FavoriteStats(
      watchedCount: watchedCount,
      watchedMinutes: watchedMinutes,
    );
  }

  factory FavoriteStats.fromJson(Map<String, dynamic> json) => FavoriteStats(
    watchedCount: (json['watched_count'] as num?)?.toInt() ?? 0,
    watchedMinutes: (json['watched_minutes'] as num?)?.toInt() ?? 0,
  );

  int get hours => watchedMinutes ~/ 60;
}

class FavoritePage {
  const FavoritePage({required this.page, required this.stats});

  final PagedResult<MovieListItem> page;
  final FavoriteStats? stats;
}

/// 收藏 Feature 的 Source 门面。
class MediaFavoritesRepository {
  MediaFavoritesRepository(this._source);

  final OmmMediaOperationsSource _source;
  static const _ommSourceId = SourceId('omm');

  Future<FavoritePage> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final page = await _source.listFavorites(
      source_models.MediaQuery(
        limit: limit,
        offset: offset,
        page: limit <= 0 ? 1 : (offset ~/ limit) + 1,
        sortBy: filter.sortBy,
        orderBy: filter.sortOrder,
        filters: filter.toQuery(limit: limit, offset: offset),
      ),
    );
    final items = page.items.map(_toMovie).toList(growable: false);
    final rawStats = page.metadata['stats'];
    return FavoritePage(
      page: PagedResult(
        items: items,
        totalCount: page.total ?? items.length + offset,
        limit: page.limit,
        offset: offset,
      ),
      stats: rawStats is Map
          ? FavoriteStats.fromJson(Map<String, dynamic>.from(rawStats))
          : null,
    );
  }

  Future<bool> toggle(int movieId) async {
    final value = await _source.toggleFavorite(_ref(movieId));
    MovieDataChanges.bumpMetadata(movieId: movieId);
    return value;
  }

  Future<bool> status(int movieId) => _source.favoriteStatus(_ref(movieId));

  Future<void> addBatch(List<int> movieIds) async {
    // 收藏批量接口是 OMM 专属操作，由 Source adapter 复用同一协议边界。
    await _source.addFavoriteBatch(movieIds.map(_ref).toList(growable: false));
    for (final movieId in movieIds) {
      MovieDataChanges.bumpMetadata(movieId: movieId);
    }
  }

  Future<void> removeBatch(List<int> movieIds) async {
    await _source.removeFavoriteBatch(
      movieIds.map(_ref).toList(growable: false),
    );
    for (final movieId in movieIds) {
      MovieDataChanges.bumpMetadata(movieId: movieId);
    }
  }

  source_models.MediaRef _ref(int id) =>
      source_models.MediaRef(sourceId: _ommSourceId, value: '$id');

  MovieListItem _toMovie(source_models.MediaSummary item) {
    final payload = item.payload;
    if (payload is MovieListItem) return payload;
    final id = int.tryParse(item.ref.value);
    if (id == null || id <= 0) throw StateError('收藏 Source 返回了无效影片 ID');
    return MovieListItem(
      id: id,
      title: item.title,
      num: item.code,
      year: item.year,
      rating: item.rating,
      runtime: item.duration,
      posterUuid: item.poster,
      thumbUuid: item.thumbnail,
      fanartUuid: item.fanart,
      previewVideoUrl: item.attributes['preview_video_url']?.toString(),
    );
  }
}
