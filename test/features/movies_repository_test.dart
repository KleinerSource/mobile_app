import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/api/services/favorites_api.dart';
import 'package:md_center/core/api/services/movies_api.dart';
import 'package:md_center/core/api/services/system_api.dart';
import 'package:md_center/features/movies/movie_filter.dart';
import 'package:md_center/features/movies/movies_repository.dart';
import 'package:retrofit/retrofit.dart';

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
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());
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
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());
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
  Future<dynamic> getMovies(Map<String, dynamic> q) async {
    lastQuery = q;
    return listResp;
  }

  @override
  Future<dynamic> getMovieDetail(int id) async => detail!;

  @override
  Future<dynamic> upsertWatchRecord(int id, Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> getWatchRecord(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> getExtraFanarts(int id) async =>
      {'success': true, 'message': 'ok', 'data': <String>[]};

  @override
  Future<dynamic> getMediaInfo(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> updateMovie(int id, Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> deleteMovies(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> syncNfo(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> refreshFromNfo(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> getNfoStatus(int id) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> searchThunderSubtitles(int id) async =>
      {'success': true, 'message': 'ok', 'data': {'items': []}};

  @override
  Future<dynamic> previewThunderSubtitle(
          int id, Map<String, dynamic> q) async =>
      {'success': true, 'message': 'ok', 'data': {'content': ''}};

  @override
  Future<dynamic> downloadThunderSubtitle(
          int id, Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> updatePosterWatermark(
          int id, Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<HttpResponse<List<int>>> previewPosterWatermark(
          int id, Map<String, dynamic> body) async =>
      HttpResponse(<int>[], Response(requestOptions: RequestOptions()));

  @override
  Future<dynamic> getDbonlineMetadata(int id) async =>
      {'success': true, 'message': 'ok', 'data': {}};

  @override
  Future<dynamic> getResources(int id, String source) async =>
      {'success': true, 'message': 'ok', 'data': []};

  @override
  Future<dynamic> getDownloadHistory(int id) async =>
      {'success': true, 'message': 'ok', 'data': {'magnets': {}, 'ed2ks': {}}};
}

class _StubSystemApi implements SystemApi {
  @override
  Future<dynamic> health() async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> version() async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> stats() async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> getDownloaders() async =>
      {'success': true, 'message': 'ok', 'data': {'downloaders': []}};

  @override
  Future<dynamic> pushDownload(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};
}

class _StubFavoritesApi implements FavoritesApi {
  @override
  Future<dynamic> list(Map<String, dynamic> q) async => {
        'success': true,
        'message': 'ok',
        'data': {'items': [], 'total_count': 0, 'limit': 50, 'offset': 0}
      };

  @override
  Future<dynamic> toggle(int movieId) async => {
        'success': true,
        'message': 'ok',
        'data': {'is_favorited': true}
      };

  @override
  Future<dynamic> status(int movieId) async => {
        'success': true,
        'message': 'ok',
        'data': {'is_favorited': false}
      };

  @override
  Future<dynamic> addBatch(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> removeBatch(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};
}
