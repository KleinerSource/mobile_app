import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/models/resource_scan.dart';
import 'package:omm/core/models/subtitle_search.dart';
import 'package:omm/core/models/watch_record.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'movie_data_changes.dart';
import 'movie_filter.dart';

/// 影片 Feature 的 Source 门面。
///
/// 这里只负责把现有页面使用的模型映射到 Source 模型，并记录 UI 所需的
/// 数据变更计数；网络协议、鉴权和 DTO 解析全部由 Source 适配器完成。
class MediaRepository {
  MediaRepository({
    required CatalogSource catalog,
    required MovieDetailSource details,
    required OmmMediaOperationsSource operations,
  }) : _catalog = catalog,
       _details = details,
       _operations = operations;

  static const _ommSourceId = SourceId('omm');

  final CatalogSource _catalog;
  final MovieDetailSource _details;
  final OmmMediaOperationsSource _operations;

  Future<PagedResult<MovieListItem>> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
    bool compact = false,
  }) async {
    final filters = <String, Object?>{
      ...filter.toQuery(limit: limit, offset: offset),
      if (compact) 'compact': true,
    };
    final page = await _catalog.listMovies(
      source_models.MediaQuery(
        page: limit <= 0 ? 1 : (offset ~/ limit) + 1,
        limit: limit,
        offset: offset,
        sortBy: filter.sortBy,
        orderBy: filter.sortOrder,
        filters: filters,
      ),
    );
    return PagedResult(
      items: page.items.map(_toMovieListItem).toList(growable: false),
      totalCount: page.total ?? page.items.length + offset,
      limit: page.limit,
      offset: offset,
    );
  }

  Future<MovieDetail> detail(int id) async {
    final result = await _details.getMovie(_movieRef(id));
    final payload = result.payload;
    if (payload is MovieDetail) return payload;
    throw StateError('OMM Source 未返回完整影片详情');
  }

  Future<List<String>> extraFanarts(int id) =>
      _operations.extraFanarts(_movieRef(id));

  Future<void> downloadExtraFanarts(int id) =>
      _operations.downloadExtraFanarts(_movieRef(id));

  Future<MediaInfoDetail?> mediaInfoDetail(int id) =>
      _operations.mediaInfoDetail(_movieRef(id));

  Future<bool> toggleFavorite(int id) async {
    final result = await _operations.toggleFavorite(_movieRef(id));
    MovieDataChanges.bumpMetadata(movieId: id);
    return result;
  }

  Future<void> markWatched(int id, bool completed) async {
    await _operations.markWatched(_movieRef(id), completed);
    MovieDataChanges.bumpProgress(movieId: id);
  }

  Future<WatchRecord?> watchRecord(int id) =>
      _operations.watchRecord(_movieRef(id));

  Future<void> acknowledgeResources(int id) =>
      _operations.acknowledgeResources(_movieRef(id));

  Future<ResourceScanStartResult> startResourceScan({
    List<int>? movieIds,
    MovieFilter? filter,
    bool favoriteOnly = false,
  }) {
    return _operations.startResourceScan(
      movies: movieIds?.map(_movieRef).toList(growable: false),
      filter: (filter ?? const MovieFilter()).toResourceScanBody(),
      favoriteOnly: favoriteOnly,
    );
  }

  Future<ResourceScanTask> resourceScanProgress(String taskId) =>
      _operations.resourceScanProgress(taskId);

  Future<void> upsertWatchRecord(
    int id, {
    required int positionSec,
    required int durationSec,
    bool? completed,
  }) async {
    await _operations.upsertWatchRecord(
      _movieRef(id),
      positionSec: positionSec,
      durationSec: durationSec,
      completed: completed,
    );
    MovieDataChanges.bumpProgress(movieId: id);
  }

  Future<MovieDetail> updateMovie(int id, Map<String, dynamic> body) async {
    final result = await _operations.updateMovie(_movieRef(id), body);
    MovieDataChanges.bumpMetadata(movieId: id);
    return result;
  }

  Future<void> deleteMovie(int id, {bool force = false}) async {
    await _operations.deleteMovie(_movieRef(id), force: force);
    MovieDataChanges.bumpMetadata(movieId: id);
  }

  Future<void> syncNfo(int id) => _operations.syncNfo(_movieRef(id));

  Future<void> refreshFromNfo(int id) async {
    await _operations.refreshFromNfo(_movieRef(id));
    MovieDataChanges.bumpMetadata(movieId: id);
    MovieDataChanges.bumpImages(movieId: id);
  }

  Future<({String keyword, List<SubtitleSearchItem> items})> searchSubtitles(
    int id,
  ) => _operations.searchSubtitles(_movieRef(id));

  Future<String> previewSubtitle(int id, String url) =>
      _operations.previewSubtitle(_movieRef(id), url);

  Future<void> downloadSubtitle(
    int id, {
    required String url,
    required String ext,
    bool overwrite = false,
  }) => _operations.downloadSubtitle(
    _movieRef(id),
    url: url,
    ext: ext,
    overwrite: overwrite,
  );

  Future<Map<String, dynamic>> getDbonlineMetadata(int id) =>
      _operations.getDbonlineMetadata(_movieRef(id));

  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getResourcesBySource(int id, String source) =>
      _operations.getResourcesBySource(_movieRef(id), source);

  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getAllResources(int id) => _operations.getAllResources(_movieRef(id));

  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() => _operations.getDownloaders();

  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(int id) => _operations.getDownloadHistory(_movieRef(id));

  Future<({String message, String lastDownloadedAt})> pushDownload({
    required List<String> urls,
    required String downloader,
    required int movieId,
    Map<String, dynamic>? videoInfo,
    List<Map<String, dynamic>> recordResources = const [],
    String savePath = '',
  }) => _operations.pushDownload(
    urls: urls,
    downloader: downloader,
    movie: _movieRef(movieId),
    videoInfo: videoInfo,
    recordResources: recordResources,
    savePath: savePath,
  );

  Future<void> batchAddAssociations({
    required List<int> movieIds,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) => _operations.batchAddAssociations(
    movies: movieIds.map(_movieRef).toList(growable: false),
    tagIds: tagIds,
    genreIds: genreIds,
    seriesId: seriesId,
  );

  Future<void> batchRemoveAssociations({
    required List<int> movieIds,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) => _operations.batchRemoveAssociations(
    movies: movieIds.map(_movieRef).toList(growable: false),
    tagIds: tagIds,
    genreIds: genreIds,
    seriesId: seriesId,
  );

  Future<({int successCount, int failedCount})> batchWatermark({
    required List<int> movieIds,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) => _operations.batchWatermark(
    movies: movieIds.map(_movieRef).toList(growable: false),
    subtitle: subtitle,
    exsub: exsub,
    crack: crack,
    uhd: uhd,
  );

  Future<String?> mergeDuplicateFiles({
    required List<int> movieIds,
    required int targetMovieId,
  }) => _operations.mergeDuplicateFiles(
    movies: movieIds.map(_movieRef).toList(growable: false),
    targetMovie: _movieRef(targetMovieId),
  );

  Future<Map<String, dynamic>> compareDuplicateNfo(List<int> movieIds) =>
      _operations.compareDuplicateNfo(
        movieIds.map(_movieRef).toList(growable: false),
      );

  Future<void> applyDuplicateNfo(Map<String, dynamic> payload) =>
      _operations.applyDuplicateNfo(payload);

  Future<String> requestDownload({
    required List<int> movieIds,
    required Map<String, dynamic> requirements,
  }) => _operations.requestDownload(
    movies: movieIds.map(_movieRef).toList(growable: false),
    requirements: requirements,
  );

  Future<void> applyPosterCrop(
    int id, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    await _operations.applyPosterCrop(
      _movieRef(id),
      cropOffset: cropOffset,
      subtitle: subtitle,
      exsub: exsub,
      crack: crack,
      uhd: uhd,
    );
    MovieDataChanges.bumpImages(movieId: id);
  }

  Future<List<int>> previewPosterCrop(
    int id, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) => _operations.previewPosterCrop(
    _movieRef(id),
    cropOffset: cropOffset,
    subtitle: subtitle,
    exsub: exsub,
    crack: crack,
    uhd: uhd,
  );

  source_models.MediaRef _movieRef(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id', '影片 ID 必须为正数');
    return source_models.MediaRef(sourceId: _ommSourceId, value: '$id');
  }

  MovieListItem _toMovieListItem(source_models.MediaSummary item) {
    final payload = item.payload;
    if (payload is MovieListItem) return payload;
    final id = int.tryParse(item.ref.value);
    if (id == null || id <= 0) throw StateError('Source 返回了无效的 OMM 影片 ID');
    final attributes = item.attributes;
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
      fileSize: _asInt(attributes['file_size']),
      fileName: attributes['file_name']?.toString(),
      seriesName: attributes['series_name']?.toString(),
      hasNewResources: attributes['has_new_resources'] == true,
      actors: const [],
    );
  }
}

int? _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
