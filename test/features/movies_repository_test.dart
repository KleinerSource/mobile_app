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

  test('compact list 请求携带紧凑响应参数', () async {
    final api = _StubMoviesApi({
      'success': true,
      'message': 'ok',
      'data': {
        'items': [
          {
            'id': 7,
            'title': 'A',
            'movie_created_at': '2026-08-12T00:00:00Z',
          },
        ],
        'total_count': 1,
        'limit': 1,
        'offset': 0,
      }
    });
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());

    final paged = await repo.list(
      const MovieFilter(),
      limit: 1,
      offset: 0,
      compact: true,
    );

    expect(api.lastQuery!['compact'], true);
    expect(paged.items.first.movieCreatedAt, isNotNull);
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

  test('读取观看记录并保留服务端最后播放位置', () async {
    final api = _StubMoviesApi(
      {},
      watchRecordResponse: {
        'success': true,
        'message': 'ok',
        'data': {
          'id': 1303,
          'created_at': '2026-08-15T09:31:33.9252514+08:00',
          'updated_at': '2026-08-15T22:01:06.7510243+08:00',
          'movie_id': 2015,
          'quality': 'auto',
          'last_position_sec': 1457,
          'duration_sec': 7915,
          'subtitle_sub_id': null,
          'completed': false,
          'last_watched_at': '2026-08-15T22:01:06.7510243+08:00',
        },
      },
    );
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());

    final record = await repo.watchRecord(9);

    expect(record?.resumePositionSec, 1457);
    expect(record?.durationSec, 7915);
  });

  test('upsertWatchRecord 使用后端观看记录字段', () async {
    final api = _StubMoviesApi({});
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());

    await repo.upsertWatchRecord(
      9,
      positionSec: 123,
      durationSec: 600,
      completed: false,
    );

    expect(api.lastWatchRecordBody, {
      'last_position_sec': 123,
      'duration_sec': 600,
      'ended': false,
    });
  });

  test('markWatched 使用 ended 字段', () async {
    final api = _StubMoviesApi({});
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());

    await repo.markWatched(9, true);

    expect(api.lastWatchRecordBody, {'ended': true});
  });

  test('打开新资源影片会调用确认接口', () async {
    final api = _StubMoviesApi({});
    final repo = MoviesRepository(api, _StubFavoritesApi(), _StubSystemApi());

    await repo.acknowledgeResources(9);

    expect(api.lastAcknowledgedId, 9);
  });

  test('影片筛选支持新资源参数和资源扫描 JSON 筛选体', () {
    const filter = MovieFilter(
      hasNewResources: true,
      genreIds: [3, 8],
      yearFrom: 2020,
    );

    expect(filter.toQuery(limit: 20, offset: 0)['has_new_resources'], true);
    expect(filter.toResourceScanBody(), {
      'genre_ids': [3, 8],
      'year_from': 2020,
      'has_new_resources': true,
    });
  });

  test('影片搜索支持四种搜索类型', () {
    const expected = {
      MovieSearchType.title: 'title',
      MovieSearchType.num: 'num',
      MovieSearchType.actor: 'actor',
      MovieSearchType.filename: 'filename',
    };

    for (final entry in expected.entries) {
      final query = MovieFilter(
        search: '关键词',
        searchType: entry.key,
      ).toQuery(limit: 20, offset: 0);
      expect(query['search'], '关键词');
      expect(query['search_type'], entry.value);
    }
  });

  test('关闭新资源筛选会清除当前状态', () {
    const filter = MovieFilter(hasNewResources: true);

    expect(
      filter
          .copyWith(hasNewResources: null, clearHasNewResources: true)
          .hasNewResources,
      isNull,
    );
  });
}

class _StubMoviesApi implements MoviesApi {
  _StubMoviesApi(this.listResp, {this.detail, this.watchRecordResponse});

  final Map<String, dynamic> listResp;
  Map<String, dynamic>? detail;
  final Map<String, dynamic>? watchRecordResponse;
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastWatchRecordBody;
  int? lastAcknowledgedId;

  @override
  Future<dynamic> getMovies(Map<String, dynamic> q) async {
    lastQuery = q;
    return listResp;
  }

  @override
  Future<dynamic> getMovieDetail(int id) async => detail!;

  @override
  Future<dynamic> upsertWatchRecord(int id, Map<String, dynamic> body) async {
    lastWatchRecordBody = body;
    return {'success': true, 'message': 'ok', 'data': null};
  }

  @override
  Future<dynamic> getWatchRecord(int id) async =>
      watchRecordResponse ??
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> acknowledgeResources(int id) async {
    lastAcknowledgedId = id;
    return {
      'success': true,
      'message': 'ok',
      'data': {'has_new_resources': false},
    };
  }

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

  @override
  Future<dynamic> batchAddAssociations(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> batchRemoveAssociations(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> batchWatermark(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> mergeDuplicateFiles(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> compareDuplicateNfo(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> applyDuplicateNfo(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};

  @override
  Future<dynamic> requestDownload(Map<String, dynamic> body) async =>
      {'success': true, 'message': 'ok', 'data': null};
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
