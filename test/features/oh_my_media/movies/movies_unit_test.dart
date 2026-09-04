// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/oh_my_media/movies/image_cache_test.dart
//   - test/features/oh_my_media/movies/media_repository_test.dart
//   - test/features/oh_my_media/movies/movie_data_changes_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/resource_scan.dart';
import 'package:omm/core/models/subtitle_search.dart';
import 'package:omm/core/models/watch_record.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';

// ==================== 原 test/features/oh_my_media/movies/image_cache_test.dart ====================
void _main_0() {
  test('封面缓存版本为零时保留原始地址', () {
    const url = 'https://example.com/api/images/poster-1?token=abc';

    expect(imageUrlWithCacheRevision(url, 0), url);
  });

  test('刷新封面时追加新的缓存键并保留已有查询参数', () {
    const url = 'https://example.com/api/images/poster-1?token=abc';

    final refreshed = Uri.parse(imageUrlWithCacheRevision(url, 3));

    expect(refreshed.queryParameters['token'], 'abc');
    expect(refreshed.queryParameters['_mdc_image_revision'], '3');
  });
}

// ==================== 原 test/features/oh_my_media/movies/media_repository_test.dart ====================
void _main_1() {
  late _FakeCatalog catalog;
  late _FakeDetails details;
  late _FakeOperations operations;
  late MediaRepository repository;

  setUp(() {
    catalog = _FakeCatalog();
    details = _FakeDetails();
    operations = _FakeOperations();
    repository = MediaRepository(
      catalog: catalog,
      details: details,
      operations: operations,
    );
  });

  test('分页查询通过 Source，并保留旧影片模型字段', () async {
    final result = await repository.list(
      const MovieFilter(hasNewResources: true),
      limit: 50,
      offset: 0,
      compact: true,
    );

    expect(result.items.single.id, 7);
    expect(result.items.single.title, 'A');
    expect(result.totalCount, 1);
    expect(catalog.lastQuery?.filters['compact'], true);
    expect(catalog.lastQuery?.filters['has_new_resources'], true);
  });

  test('详情通过带 sourceId 的 MediaRef 委托给 Source', () async {
    final result = await repository.detail(9);

    expect(result.id, 9);
    expect(details.lastRef?.sourceId, const SourceId('omm'));
    expect(details.lastRef?.value, '9');
  });

  test('观看记录、收藏和进度操作只委托 Source', () async {
    expect(await repository.toggleFavorite(9), isTrue);
    await repository.markWatched(9, true);
    await repository.upsertWatchRecord(
      9,
      positionSec: 123,
      durationSec: 600,
      completed: false,
    );

    expect(operations.lastRef?.value, '9');
    expect(operations.lastCompleted, true);
    expect(operations.lastPosition, 123);
  });

  test('资源扫描筛选转换在 Feature 门面完成后传入 Source', () async {
    await repository.startResourceScan(
      filter: const MovieFilter(genreIds: [3, 8], yearFrom: 2020),
      favoriteOnly: true,
    );

    expect(operations.lastResourceFilter, {
      'genre_ids': [3, 8],
      'year_from': 2020,
    });
    expect(operations.lastFavoriteOnly, true);
  });
}

class _FakeCatalog implements CatalogSource {
  source_models.MediaQuery? lastQuery;

  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> listMovies(
    source_models.MediaQuery query,
  ) async {
    lastQuery = query;
    final movie = const MovieListItem(id: 7, title: 'A');
    return source_models.MediaPage(
      items: [
        source_models.MediaSummary(
          ref: const source_models.MediaRef(
            sourceId: SourceId('omm'),
            value: '7',
          ),
          title: movie.title,
          payload: movie,
        ),
      ],
      page: 1,
      limit: query.limit,
      total: 1,
      hasMore: false,
    );
  }

  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> searchMovies(
    source_models.MediaQuery query,
  ) => listMovies(query);
}

class _FakeDetails implements MovieDetailSource {
  source_models.MediaRef? lastRef;

  @override
  Future<source_models.MediaDetails> getMovie(
    source_models.MediaRef ref,
  ) async {
    lastRef = ref;
    return source_models.MediaDetails(
      summary: source_models.MediaSummary(ref: ref, title: 'D'),
      payload: const MovieDetail(id: 9, title: 'D'),
    );
  }
}

class _FakeOperations implements OmmMediaOperationsSource {
  source_models.MediaRef? lastRef;
  bool? lastCompleted;
  int? lastPosition;
  Map<String, dynamic>? lastResourceFilter;
  bool? lastFavoriteOnly;

  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> listFavorites(
    source_models.MediaQuery query,
  ) => throw UnimplementedError();

  @override
  Future<bool> favoriteStatus(source_models.MediaRef movie) async => false;

  @override
  Future<void> addFavoriteBatch(List<source_models.MediaRef> movies) async {}

  @override
  Future<void> removeFavoriteBatch(List<source_models.MediaRef> movies) async {}

  @override
  Future<List<String>> extraFanarts(source_models.MediaRef movie) async => [];

  @override
  Future<void> downloadExtraFanarts(source_models.MediaRef movie) async {}

  @override
  Future<MediaInfoDetail?> mediaInfoDetail(
    source_models.MediaRef movie,
  ) async => null;

  @override
  Future<bool> toggleFavorite(source_models.MediaRef movie) async {
    lastRef = movie;
    return true;
  }

  @override
  Future<void> markWatched(source_models.MediaRef movie, bool completed) async {
    lastRef = movie;
    lastCompleted = completed;
  }

  @override
  Future<WatchRecord?> watchRecord(source_models.MediaRef movie) async => null;

  @override
  Future<void> acknowledgeResources(source_models.MediaRef movie) async {}

  @override
  Future<ResourceScanStartResult> startResourceScan({
    List<source_models.MediaRef>? movies,
    Map<String, dynamic>? filter,
    bool favoriteOnly = false,
  }) async {
    lastResourceFilter = filter;
    lastFavoriteOnly = favoriteOnly;
    return const ResourceScanStartResult(
      taskId: 'task',
      acceptedCount: 0,
      skippedCount: 0,
      skippedIds: [],
    );
  }

  @override
  Future<ResourceScanTask> resourceScanProgress(String taskId) =>
      throw UnimplementedError();

  @override
  Future<void> upsertWatchRecord(
    source_models.MediaRef movie, {
    required int positionSec,
    required int durationSec,
    bool? completed,
  }) async {
    lastRef = movie;
    lastPosition = positionSec;
  }

  @override
  Future<MovieDetail> updateMovie(
    source_models.MediaRef movie,
    Map<String, dynamic> body,
  ) => throw UnimplementedError();

  @override
  Future<void> deleteMovie(
    source_models.MediaRef movie, {
    bool force = false,
  }) async {}

  @override
  Future<PreviewStartResult> generatePreview(
    source_models.MediaRef movie, {
    bool overwrite = false,
  }) => throw UnimplementedError();

  @override
  Future<PreviewStatus> previewStatus(
    source_models.MediaRef movie, {
    String? taskId,
  }) => throw UnimplementedError();

  @override
  Future<PreviewTask> previewTask(String taskId) => throw UnimplementedError();

  @override
  Future<void> cancelPreviewTask(String taskId) async {}

  @override
  Future<void> syncNfo(source_models.MediaRef movie) async {}

  @override
  Future<void> refreshFromNfo(source_models.MediaRef movie) async {}

  @override
  Future<({String keyword, List<SubtitleSearchItem> items})> searchSubtitles(
    source_models.MediaRef movie,
  ) => throw UnimplementedError();

  @override
  Future<String> previewSubtitle(source_models.MediaRef movie, String url) =>
      throw UnimplementedError();

  @override
  Future<void> downloadSubtitle(
    source_models.MediaRef movie, {
    required String url,
    required String ext,
    bool overwrite = false,
  }) async {}

  @override
  Future<Map<String, dynamic>> getDbonlineMetadata(
    source_models.MediaRef movie,
  ) => throw UnimplementedError();

  @override
  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getResourcesBySource(source_models.MediaRef movie, String source) =>
      throw UnimplementedError();

  @override
  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getAllResources(source_models.MediaRef movie) => throw UnimplementedError();

  @override
  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() => throw UnimplementedError();

  @override
  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(source_models.MediaRef movie) =>
      throw UnimplementedError();

  @override
  Future<({String message, String lastDownloadedAt})> pushDownload({
    required List<String> urls,
    required String downloader,
    required source_models.MediaRef movie,
    Map<String, dynamic>? videoInfo,
    List<Map<String, dynamic>> recordResources = const [],
    String savePath = '',
  }) => throw UnimplementedError();

  @override
  Future<void> batchAddAssociations({
    required List<source_models.MediaRef> movies,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) async {}

  @override
  Future<void> batchRemoveAssociations({
    required List<source_models.MediaRef> movies,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) async {}

  @override
  Future<({int successCount, int failedCount})> batchWatermark({
    required List<source_models.MediaRef> movies,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) => throw UnimplementedError();

  @override
  Future<String?> mergeDuplicateFiles({
    required List<source_models.MediaRef> movies,
    required source_models.MediaRef targetMovie,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> compareDuplicateNfo(
    List<source_models.MediaRef> movies,
  ) => throw UnimplementedError();

  @override
  Future<void> applyDuplicateNfo(Map<String, dynamic> payload) async {}

  @override
  Future<String> requestDownload({
    required List<source_models.MediaRef> movies,
    required Map<String, dynamic> requirements,
  }) => throw UnimplementedError();

  @override
  Future<void> applyPosterCrop(
    source_models.MediaRef movie, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {}

  @override
  Future<List<int>> previewPosterCrop(
    source_models.MediaRef movie, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async => [];
}

// ==================== 原 test/features/oh_my_media/movies/movie_data_changes_test.dart ====================
void _main_2() {
  test('按影片快照不会被其他影片的变更误触发', () {
    const movieA = 901001;
    const movieB = 901002;
    final before = MovieDataChanges.snapshot(movieId: movieA);

    MovieDataChanges.bumpImages(movieId: movieB);

    expect(before.latest.changedSince(before), isFalse);
    expect(before.latest.imagesChangedSince(before), isFalse);
  });

  test('影片编辑和播放进度分别只触发对应的变更类型', () {
    const movieA = 901003;
    final before = MovieDataChanges.snapshot(movieId: movieA);

    MovieDataChanges.bumpMetadata(movieId: movieA);
    final afterMetadata = before.latest;
    expect(afterMetadata.displayChangedSince(before), isTrue);
    expect(afterMetadata.imagesChangedSince(before), isFalse);
    expect(afterMetadata.progressChangedSince(before), isFalse);

    final beforeProgress = MovieDataChanges.snapshot(movieId: movieA);
    MovieDataChanges.bumpProgress(movieId: movieA);
    final afterProgress = beforeProgress.latest;
    expect(afterProgress.displayChangedSince(beforeProgress), isFalse);
    expect(afterProgress.progressChangedSince(beforeProgress), isTrue);
  });
}

void main() {
  group('image_cache', _main_0);
  group('media_repository', _main_1);
  group('movie_data_changes', _main_2);
}
