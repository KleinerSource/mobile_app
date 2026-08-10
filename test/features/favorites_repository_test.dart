import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/favorites_api.dart';
import 'package:md_center/features/favorites/favorites_repository.dart';
import 'package:md_center/features/movies/movie_filter.dart';

void main() {
  test('解析收藏影片的观看记录和跨分页统计', () async {
    final repository = FavoritesRepository(_StubFavoritesApi());

    final result = await repository.list(
      const MovieFilter(),
      limit: 30,
      offset: 0,
    );

    expect(result.page.items, hasLength(1));
    expect(result.page.items.single.watchRecord?.completed, isTrue);
    expect(result.stats?.watchedCount, 2);
    expect(result.stats?.watchedMinutes, 180);
    expect(result.stats?.hours, 3);

    final local = FavoriteStats.fromMovies(result.page.items);
    expect(local.watchedCount, 1);
    expect(local.watchedMinutes, 120);
  });

  test('旧服务端没有统计字段时保留空统计以便页面回退本地计算', () async {
    final repository = FavoritesRepository(_StubFavoritesApi(withStats: false));

    final result = await repository.list(
      const MovieFilter(),
      limit: 30,
      offset: 0,
    );

    expect(result.stats, isNull);
  });
}

class _StubFavoritesApi implements FavoritesApi {
  _StubFavoritesApi({this.withStats = true});

  final bool withStats;

  @override
  Future<dynamic> list(Map<String, dynamic> q) async {
    return {
      'success': true,
      'message': 'ok',
      'data': {
        'items': [
          {
            'movie': {
              'id': 1,
              'title': 'Watched movie',
              'runtime': 120,
              'watch_record': {
                'progress_ratio': 1.0,
                'completed': true,
              },
            },
          },
        ],
        'total_count': 2,
        'limit': q['limit'],
        'offset': q['offset'],
        if (withStats)
          'stats': {
            'watched_count': 2,
            'watched_minutes': 180,
          },
      },
    };
  }

  @override
  Future<dynamic> toggle(int movieId) async => {
        'success': true,
        'message': 'ok',
        'data': {'is_favorited': true},
      };

  @override
  Future<dynamic> status(int movieId) async => {
        'success': true,
        'message': 'ok',
        'data': {'is_favorited': false},
      };

  @override
  Future<dynamic> addBatch(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> removeBatch(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};
}
