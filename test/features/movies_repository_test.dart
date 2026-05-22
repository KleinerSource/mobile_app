import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/favorites_api.dart';
import 'package:md_center/core/api/services/movies_api.dart';
import 'package:md_center/features/movies/movie_filter.dart';
import 'package:md_center/features/movies/movies_repository.dart';

void main() {
  test('list 调 MoviesApi.getMovies 并解 envelope', () async {
    final api = _StubMoviesApi({
      'success': true,
      'message': 'ok',
      'data': {
        'items': [
          {'id': 7, 'title': 'A'},
        ],
        'total_count': 1,
        'limit': 50,
        'offset': 0,
      }
    });
    final repo = MoviesRepository(api, _StubFavoritesApi());
    final paged = await repo.list(const MovieFilter(), limit: 50, offset: 0);
    expect(paged.items.first.id, 7);
    expect(paged.items.first.title, 'A');
    expect(paged.totalCount, 1);
    expect(api.lastQuery!['limit'], 50);
    expect(api.lastQuery!['offset'], 0);
    expect(api.lastQuery!['sort_by'], 'created_at');
  });

  test('detail 解 StdEnvelope', () async {
    final api = _StubMoviesApi({}, detail: {
      'success': true,
      'message': 'ok',
      'data': {'id': 9, 'title': 'D'}
    });
    final repo = MoviesRepository(api, _StubFavoritesApi());
    final d = await repo.detail(9);
    expect(d.id, 9);
    expect(d.title, 'D');
  });
}

class _StubMoviesApi implements MoviesApi {
  _StubMoviesApi(this.listResp, {this.detail});

  final Map<String, dynamic> listResp;
  Map<String, dynamic>? detail;
  Map<String, dynamic>? lastQuery;

  @override
  Future<Map<String, dynamic>> getMovies(Map<String, dynamic> q) async {
    lastQuery = q;
    return listResp;
  }

  @override
  Future<Map<String, dynamic>> getMovieDetail(int id) async => detail!;

  @override
  Future<Map<String, dynamic>> upsertWatchRecord(
          int id, Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<Map<String, dynamic>> getWatchRecord(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<Map<String, dynamic>> getExtraFanarts(int id) async =>
      {'success': true, 'message': 'ok', 'data': <String>[]};

  @override
  Future<Map<String, dynamic>> getMediaInfo(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};
}

class _StubFavoritesApi implements FavoritesApi {
  @override
  Future<Map<String, dynamic>> list(Map<String, dynamic> q) async =>
      {'success': true, 'message': 'ok', 'data': {'items': [], 'total_count': 0, 'limit': 50, 'offset': 0}};

  @override
  Future<Map<String, dynamic>> toggle(int movieId) async =>
      {'success': true, 'message': 'ok', 'data': {'is_favorited': true}};

  @override
  Future<Map<String, dynamic>> status(int movieId) async =>
      {'success': true, 'message': 'ok', 'data': {'is_favorited': false}};

  @override
  Future<Map<String, dynamic>> addBatch(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<Map<String, dynamic>> removeBatch(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};
}
