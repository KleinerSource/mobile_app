import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_watched.dart';

import '../support/watched_test_support.dart';

void main() {
  test('已看默认参数、额外data信封、字符串ID及可播放字段', () async {
    final backend = WatchedTestBackend()
      ..movies = [watchedMovie(1), watchedMovie(2, playable: true)];
    final api = DbOnlineApi(backend.dio('https://a.test'));
    final page = await api.watchedMoviesPage();
    expect(backend.to('/subs/watched').single.queryParameters, {
      'type': 'all',
      'star': '',
      'sort_by': 'create',
      'order_by': 'desc',
      'page': 1,
      'limit': 24,
    });
    expect(page.movies.map((movie) => movie.id), ['watched-1', 'watched-2']);
    expect(page.movies.first.canPlay, isFalse);
    expect(page.movies.last.canPlay, isTrue);
    expect(page.movies.first.hasCnsub, isTrue);
    expect(page.movies.first.magnetsCount, 2);
    expect(page.hasMore, isFalse);
  });

  test('全部类型/评分/排序参数可组合，不添加 can_play 过滤', () async {
    final backend = WatchedTestBackend();
    final api = DbOnlineApi(backend.dio('https://a.test'));
    for (final type in ['all', '0', '1', '2', '3', '4']) {
      await api.watchedMoviesPage(
        filter: DbOnlineWatchedFilter(
          type: type,
          star: '3',
          sortBy: 'release',
          orderBy: 'asc',
        ),
        page: 7,
      );
      expect(backend.to('/subs/watched').last.queryParameters, {
        'type': type,
        'star': '3',
        'sort_by': 'release',
        'order_by': 'asc',
        'page': 7,
        'limit': 24,
      });
    }
  });

  test('原始24条为未结束，短批次/空批次结束', () async {
    final backend = WatchedTestBackend()
      ..pages[1] = [for (var i = 0; i < 24; i++) watchedMovie(i)]
      ..pages[2] = [watchedMovie(24)];
    final api = DbOnlineApi(backend.dio('https://a.test'));
    expect((await api.watchedMoviesPage()).hasMore, isTrue);
    expect((await api.watchedMoviesPage(page: 2)).hasMore, isFalse);
    expect((await api.watchedMoviesPage(page: 3)).movies, isEmpty);
  });

  test('复查仅发送筛选四项与九项下载条件，五分钟超时', () async {
    final backend = WatchedTestBackend();
    final api = DbOnlineApi(backend.dio('https://a.test'));
    const filter = DbOnlineWatchedFilter(
      type: '0',
      star: '5',
      sortBy: 'release',
      orderBy: 'asc',
    );
    const requirements = DbOnlineRecheckRequirements(
      quality: 'uhd',
      requireSub: true,
      requireUncensored: true,
      preDownloadMode: true,
      washMode: true,
      minSizeMb: 100,
      maxSizeMb: 8000,
      maxFileCount: 3,
      afterDate: '2026-10-01',
    );
    expect(
      await api.recheckWatchedVideos(
        filter: filter,
        requirements: requirements,
      ),
      12,
    );
    final request = backend.to('/videos/recheck').single;
    expect(request.method, 'POST');
    expect(request.receiveTimeout, const Duration(minutes: 5));
    expect(request.data, {
      'scope': 'watched',
      'filters': {
        'type': '0',
        'star': '5',
        'sort_by': 'release',
        'order_by': 'asc',
      },
      'requirements': {
        'quality': 'uhd',
        'require_sub': true,
        'require_uncensored': true,
        'pre_download_mode': true,
        'wash_mode': true,
        'min_size_mb': 100.0,
        'max_size_mb': 8000.0,
        'max_file_count': 3,
        'after_date': '2026-10-01',
      },
    });
  });

  test('查询/复查业务失败向上抛出，不把失败作为空列表或零结果', () async {
    final backend = WatchedTestBackend()
      ..respond = (_) => {'success': false, 'error': '测试失败'};
    final api = DbOnlineApi(backend.dio('https://a.test'));
    await expectLater(api.watchedMoviesPage(), throwsA(isA<Exception>()));
    await expectLater(
      api.recheckWatchedVideos(
        filter: const DbOnlineWatchedFilter(),
        requirements: const DbOnlineRecheckRequirements(),
      ),
      throwsA(isA<Exception>()),
    );
    expect(backend.to('/videos/recheck'), hasLength(1));
  });
}
