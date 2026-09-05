import '../../api/api_client.dart';
import '../../api/envelope.dart';
import '../../models/media_streams.dart';
import '../../models/movie.dart';
import '../../models/preview.dart';
import '../../models/resource_scan.dart';
import '../../models/subtitle_search.dart';
import '../../models/watch_record.dart';
import '../common/source_error_mapper.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'media_models.dart';
import 'omm_audio_operations_source.dart';
import 'omm_metadata_operations_source.dart';
import 'omm_media_operations_source.dart';

/// OMM 专属影片操作的 HTTP 适配器。
///
/// 这是协议客户端和 Feature 之间的唯一边界。Feature 只能拿到
/// [OmmMediaOperationsSource]，不会直接接触 `MoviesApi` 等服务。
class OmmMediaOperationsAdapter
    implements
        OmmMediaOperationsSource,
        OmmMetadataOperationsSource,
        OmmAudioOperationsSource {
  OmmMediaOperationsAdapter(this.client);

  final ApiClient client;

  @override
  Future<Object?> listActors(Map<String, dynamic> query) =>
      _call(() => client.actors.list(query));

  @override
  Future<Object?> actorOptions(Map<String, dynamic> query) =>
      _call(() => client.actors.options(query));

  @override
  Future<List<int>> previewActorAvatar(Map<String, dynamic> body) =>
      _call(() async {
        final response = await client.actors.previewAvatar(body);
        if (response.data.isEmpty) throw const SourceException('头像内容为空');
        return response.data;
      });

  @override
  Future<Object?> actorDetail(int id) =>
      _call(() => client.catalog.detail('actors', id));

  @override
  Future<Object?> createActor(Map<String, dynamic> body) =>
      _call(() => client.catalog.createActor(body));

  @override
  Future<Object?> updateActor(int id, Map<String, dynamic> body) =>
      _call(() => client.catalog.updateActor(id, body));

  @override
  Future<Object?> deleteActors(Map<String, dynamic> body) =>
      _call(() => client.catalog.deleteActors(body));

  @override
  Future<Object?> resourceDetail(String type, int id) =>
      _call(() => client.catalog.detail(type, id));

  @override
  Future<Object?> resourceList(String type, Map<String, dynamic> query) {
    return _call(() {
      return switch (type) {
        'genres' => client.genres.list(query),
        'tags' => client.tags.list(query),
        'series' => client.series.list(query),
        _ => throw ArgumentError.value(type, 'type', '不支持的资源类型'),
      };
    });
  }

  @override
  Future<Object?> resourceOptions(String type, Map<String, dynamic> query) {
    return _call(() {
      return switch (type) {
        'genres' => client.genres.options(query),
        'tags' => client.tags.options(query),
        'series' => client.series.options(query),
        _ => throw ArgumentError.value(type, 'type', '不支持的资源类型'),
      };
    });
  }

  @override
  Future<Object?> resourceCreate(String type, Map<String, dynamic> body) {
    return _call(() {
      return switch (type) {
        'genres' => client.genres.create(body),
        'tags' => client.tags.create(body),
        'series' => client.series.create(body),
        _ => throw ArgumentError.value(type, 'type', '不支持的资源类型'),
      };
    });
  }

  @override
  Future<Object?> resourceUpdate(
    String type,
    int id,
    Map<String, dynamic> body,
  ) {
    return _call(() {
      return switch (type) {
        'genres' => client.genres.update(id, body),
        'tags' => client.tags.update(id, body),
        'series' => client.series.update(id, body),
        _ => throw ArgumentError.value(type, 'type', '不支持的资源类型'),
      };
    });
  }

  @override
  Future<Object?> resourceDelete(String type, Map<String, dynamic> body) {
    return _call(() {
      return switch (type) {
        'genres' => client.genres.batchDelete(body),
        'tags' => client.tags.batchDelete(body),
        'series' => client.series.batchDelete(body),
        _ => throw ArgumentError.value(type, 'type', '不支持的资源类型'),
      };
    });
  }

  @override
  Future<Object?> resourceMerge(String type, Map<String, dynamic> body) =>
      _call(() => client.catalog.merge(type, body));

  @override
  Future<Object?> mappingList(String type, Map<String, dynamic> query) =>
      _call(() => client.mappings.list(type, query));

  @override
  Future<Object?> mappingCreate(String type, Map<String, dynamic> body) =>
      _call(() => client.mappings.create(type, body));

  @override
  Future<Object?> mappingUpdate(
    String type,
    int id,
    Map<String, dynamic> body,
  ) => _call(() => client.mappings.update(type, id, body));

  @override
  Future<Object?> mappingDelete(String type, Map<String, dynamic> body) =>
      _call(() => client.mappings.delete(type, body));

  @override
  Future<Object?> actorExternalSyncPreview(Map<String, dynamic> body) =>
      _call(() => client.mappings.actorExternalSyncPreview(body));

  @override
  Future<Object?> mixedExternalSyncPreviewStart(Map<String, dynamic> body) =>
      _call(() => client.mappings.mixedExternalSyncPreviewStart(body));

  @override
  Future<Object?> mixedExternalSyncPreviewSession(String taskId) =>
      _call(() => client.mappings.mixedExternalSyncPreviewSession(taskId));

  @override
  Future<Object?> actorExternalSyncApply(Map<String, dynamic> body) =>
      _call(() => client.mappings.actorExternalSyncApply(body));

  @override
  Future<Object?> listAssets({
    int limit = 20,
    int offset = 0,
    String? search,
  }) => _call(
    () => client.audio.listAssets(limit: limit, offset: offset, search: search),
  );

  @override
  Future<Object?> deleteAssets(List<int> ids) =>
      _call(() => client.audio.deleteAssets(ids));

  @override
  Future<Object?> enqueueTranscriptions(
    List<int> assetIds, {
    bool overwrite = false,
  }) => _call(
    () => client.audio.enqueueTranscriptions(assetIds, overwrite: overwrite),
  );

  @override
  Future<Object?> listTranscriptions({
    int limit = 100,
    int offset = 0,
    String? status,
  }) => _call(
    () => client.audio.listTranscriptions(
      limit: limit,
      offset: offset,
      status: status,
    ),
  );

  @override
  Future<Object?> extractAudio({
    required int movieId,
    String format = 'mp3',
    int bitrateKbps = 192,
  }) => _call(
    () => client.audio.extractAudio(
      movieId: movieId,
      format: format,
      bitrateKbps: bitrateKbps,
    ),
  );

  @override
  Future<Object?> cancelAudioExtraction(String taskId) =>
      _call(() => client.audio.cancelAudioExtraction(taskId));

  @override
  Future<Object?> cancelSubtitleTranscription(String assetId) =>
      _call(() => client.audio.cancelSubtitleTranscription(assetId));

  @override
  Future<Object?> retrySubtitleTranscription(
    String assetId, {
    bool? overwrite,
  }) => _call(
    () =>
        client.audio.retrySubtitleTranscription(assetId, overwrite: overwrite),
  );

  @override
  Future<MediaPage<MediaSummary>> listFavorites(MediaQuery query) async {
    final raw = await _call(() => client.favorites.list(query.filters));
    final page = unwrapMovieList<MovieListItem>(raw, (json) {
      final movie = json['movie'];
      return movie is Map
          ? MovieListItem.fromJson(Map<String, dynamic>.from(movie))
          : MovieListItem.fromJson(json);
    });
    final data = raw is Map && raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : const <String, dynamic>{};
    final stats = data['stats'];
    return MediaPage(
      items: page.items.map(_summaryFromMovie).toList(growable: false),
      page: query.limit <= 0 ? 1 : (query.offset ~/ query.limit) + 1,
      limit: page.limit,
      total: page.totalCount,
      hasMore: page.hasMore,
      metadata: stats is Map
          ? {'stats': Map<String, dynamic>.from(stats)}
          : const {},
    );
  }

  @override
  Future<bool> favoriteStatus(MediaRef movie) async {
    final raw = await _call(() => client.favorites.status(_ommId(movie)));
    return unwrapStd<bool>(
      raw,
      (data) => data is Map && data['is_favorited'] == true,
    );
  }

  @override
  Future<List<String>> extraFanarts(MediaRef movie) async {
    final raw = await _call(() => client.movies.getExtraFanarts(_ommId(movie)));
    return unwrapStd<List<String>>(raw, (data) {
      if (data is List) return data.whereType<String>().toList(growable: false);
      return const <String>[];
    });
  }

  @override
  Future<void> downloadExtraFanarts(MediaRef movie) async {
    final api = client.moviesExtended;
    await _call(() => api.downloadDbonlineExtrafanart(_ommId(movie)));
  }

  @override
  Future<MediaInfoDetail?> mediaInfoDetail(MediaRef movie) async {
    try {
      final raw = await _call(() => client.movies.getMediaInfo(_ommId(movie)));
      return unwrapStd<MediaInfoDetail?>(raw, (data) {
        if (data is Map) {
          return MediaInfoDetail.fromJson(Map<String, dynamic>.from(data));
        }
        return null;
      });
    } on SourceException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<bool> toggleFavorite(MediaRef movie) async {
    final raw = await _call(() => client.favorites.toggle(_ommId(movie)));
    final value = unwrapStd<bool>(raw, (data) {
      return data is Map && data['is_favorited'] == true;
    });
    return value;
  }

  @override
  Future<void> addFavoriteBatch(List<MediaRef> movies) async {
    final raw = await _call(
      () => client.favorites.addBatch({
        'movie_ids': movies.map(_ommId).toList(growable: false),
      }),
    );
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<void> removeFavoriteBatch(List<MediaRef> movies) async {
    final raw = await _call(
      () => client.favorites.removeBatch({
        'movie_ids': movies.map(_ommId).toList(growable: false),
      }),
    );
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<void> markWatched(MediaRef movie, bool completed) async {
    await _call(
      () =>
          client.movies.upsertWatchRecord(_ommId(movie), {'ended': completed}),
    );
  }

  @override
  Future<WatchRecord?> watchRecord(MediaRef movie) async {
    try {
      final raw = await _call(
        () => client.movies.getWatchRecord(_ommId(movie)),
      );
      return unwrapStd<WatchRecord?>(raw, (data) {
        if (data is! Map) return null;
        return WatchRecord.fromJson(Map<String, dynamic>.from(data));
      });
    } on SourceException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> acknowledgeResources(MediaRef movie) async {
    final raw = await _call(
      () => client.movies.acknowledgeResources(_ommId(movie)),
    );
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<ResourceScanStartResult> startResourceScan({
    List<MediaRef>? movies,
    Map<String, dynamic>? filter,
    bool favoriteOnly = false,
  }) async {
    final api = client.moviesExtended;
    final ids = movies
        ?.map(_ommId)
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    final body = ids != null && ids.isNotEmpty
        ? <String, dynamic>{'movie_ids': ids}
        : <String, dynamic>{
            'scan_all': true,
            'favorite_only': favoriteOnly,
            'filters': filter ?? const <String, dynamic>{},
          };
    final data = await _call(() => api.batchResourceScan(body));
    if (data is! Map) throw const SourceException('资源扫描响应格式错误');
    return ResourceScanStartResult.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<ResourceScanTask> resourceScanProgress(String taskId) async {
    final api = client.moviesExtended;
    final data = await _call(() => api.resourceScanProgress(taskId));
    if (data is! Map) throw const SourceException('资源扫描进度响应格式错误');
    return ResourceScanTask.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> upsertWatchRecord(
    MediaRef movie, {
    required int positionSec,
    required int durationSec,
    bool? completed,
  }) async {
    final body = <String, dynamic>{
      'last_position_sec': positionSec,
      'duration_sec': durationSec,
      if (completed != null) 'ended': completed,
    };
    await _call(() => client.movies.upsertWatchRecord(_ommId(movie), body));
  }

  @override
  Future<MovieDetail> updateMovie(
    MediaRef movie,
    Map<String, dynamic> body,
  ) async {
    final raw = await _call(
      () => client.movies.updateMovie(_ommId(movie), body),
    );
    return unwrapStd<MovieDetail>(
      raw,
      (data) => MovieDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  @override
  Future<void> deleteMovie(MediaRef movie, {bool force = false}) async {
    final raw = await _call(
      () => client.movies.deleteMovies({
        'movie_ids': [_ommId(movie)],
        'force': force,
      }),
    );
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<void> syncNfo(MediaRef movie) async {
    final raw = await _call(() => client.movies.syncNfo(_ommId(movie)));
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<void> refreshFromNfo(MediaRef movie) async {
    final raw = await _call(() => client.movies.refreshFromNfo(_ommId(movie)));
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<({String keyword, List<SubtitleSearchItem> items})> searchSubtitles(
    MediaRef movie,
  ) async {
    final raw = await _call(
      () => client.movies.searchThunderSubtitles(_ommId(movie)),
    );
    return unwrapStd<({String keyword, List<SubtitleSearchItem> items})>(raw, (
      data,
    ) {
      if (data is Map) {
        final json = Map<String, dynamic>.from(data);
        final list = json['items'] is List ? json['items'] as List : const [];
        return (
          keyword: json['keyword']?.toString() ?? '',
          items: list
              .whereType<Map>()
              .map(
                (item) => SubtitleSearchItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
        );
      }
      return (keyword: '', items: <SubtitleSearchItem>[]);
    });
  }

  @override
  Future<String> previewSubtitle(MediaRef movie, String url) async {
    final raw = await _call(
      () => client.movies.previewThunderSubtitle(_ommId(movie), {'url': url}),
    );
    return unwrapStd<String>(raw, (data) {
      if (data is Map) return data['content']?.toString() ?? '';
      return data?.toString() ?? '';
    });
  }

  @override
  Future<void> downloadSubtitle(
    MediaRef movie, {
    required String url,
    required String ext,
    bool overwrite = false,
  }) async {
    final raw = await _call(
      () => client.movies.downloadThunderSubtitle(_ommId(movie), {
        'url': url,
        'ext': ext,
        'overwrite': overwrite,
      }),
    );
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<Map<String, dynamic>> getDbonlineMetadata(MediaRef movie) async {
    final raw = await _call(
      () => client.movies.getDbonlineMetadata(_ommId(movie)),
    );
    return unwrapStd<Map<String, dynamic>>(raw, (data) {
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    });
  }

  @override
  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getResourcesBySource(MediaRef movie, String source) async {
    final raw = await _call(
      () => client.movies.getResources(_ommId(movie), source),
    );
    return _resourceResult(raw);
  }

  @override
  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getAllResources(MediaRef movie) async {
    const sources = ['detail', 'custom', 'nyaa'];
    final magnets = <Map<String, dynamic>>[];
    final ed2ks = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final errors = <String>[];
    await Future.wait(
      sources.map((source) async {
        try {
          final result = await getResourcesBySource(movie, source);
          magnets.addAll(result.magnets);
          ed2ks.addAll(result.ed2ks);
          warnings.addAll(result.warnings);
        } catch (error) {
          errors.add(
            '$source: ${error is SourceException ? error.message : error}',
          );
        }
      }),
    );
    if (magnets.isEmpty && ed2ks.isEmpty && errors.isNotEmpty) {
      throw SourceException(errors.first);
    }
    return (magnets: magnets, ed2ks: ed2ks, warnings: warnings);
  }

  @override
  Future<List<({String name, String displayName, bool? ed2kEnabled})>>
  getDownloaders() async {
    final raw = await _call(client.system.getDownloaders);
    return unwrapStd<
      List<({String name, String displayName, bool? ed2kEnabled})>
    >(raw, (data) {
      final items = data is Map && data['downloaders'] is List
          ? data['downloaders'] as List
          : data is List
          ? data
          : const [];
      return items
          .whereType<Map>()
          .map((item) {
            final json = Map<String, dynamic>.from(item);
            final name = (json['name'] ?? '').toString().trim();
            final displayName =
                (json['display_name'] ?? json['displayName'] ?? name)
                    .toString()
                    .trim();
            final ed2k = json['ed2k_enabled'] is bool
                ? json['ed2k_enabled'] as bool
                : json['ed2kEnabled'] is bool
                ? json['ed2kEnabled'] as bool
                : null;
            return (name: name, displayName: displayName, ed2kEnabled: ed2k);
          })
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);
    });
  }

  @override
  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(MediaRef movie) async {
    final raw = await _call(
      () => client.movies.getDownloadHistory(_ommId(movie)),
    );
    return unwrapStd(raw, (data) {
      Map<String, String> normalize(Object? value) {
        if (value is! Map) return <String, String>{};
        final result = <String, String>{};
        for (final entry in value.entries) {
          final key = entry.key.toString().trim().toUpperCase();
          if (key.isNotEmpty) result[key] = (entry.value ?? '').toString();
        }
        return result;
      }

      if (data is Map) {
        return (
          magnets: normalize(data['magnets']),
          ed2ks: normalize(data['ed2ks']),
        );
      }
      return (magnets: <String, String>{}, ed2ks: <String, String>{});
    });
  }

  @override
  Future<({String message, String lastDownloadedAt})> pushDownload({
    required List<String> urls,
    required String downloader,
    required MediaRef movie,
    Map<String, dynamic>? videoInfo,
    List<Map<String, dynamic>> recordResources = const [],
    String savePath = '',
  }) async {
    final raw = await _call(
      () => client.system.pushDownload({
        'urls': urls,
        'downloader': downloader,
        'save_path': savePath,
        'video_info': videoInfo,
        'record_resources': recordResources,
        'movie_id': _ommId(movie),
      }),
    );
    if (raw is Map && raw['success'] == false) {
      throw SourceException((raw['message'] as String?) ?? '推送失败');
    }
    final message = raw is Map
        ? (raw['message']?.toString() ?? '下载任务已添加')
        : '下载任务已添加';
    final lastDownloadedAt = raw is Map && raw['data'] is Map
        ? ((raw['data'] as Map)['last_downloaded_at'] ?? '').toString()
        : '';
    return (message: message, lastDownloadedAt: lastDownloadedAt);
  }

  @override
  Future<void> batchAddAssociations({
    required List<MediaRef> movies,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) async {
    final raw = await _call(
      () => client.movies.batchAddAssociations(
        _associationBody(
          movies: movies,
          tagIds: tagIds,
          genreIds: genreIds,
          seriesId: seriesId,
        ),
      ),
    );
    _throwIfUnsuccessful(raw, '批量编辑失败');
  }

  @override
  Future<void> batchRemoveAssociations({
    required List<MediaRef> movies,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) async {
    final raw = await _call(
      () => client.movies.batchRemoveAssociations(
        _associationBody(
          movies: movies,
          tagIds: tagIds,
          genreIds: genreIds,
          seriesId: seriesId,
        ),
      ),
    );
    _throwIfUnsuccessful(raw, '批量编辑失败');
  }

  @override
  Future<({int successCount, int failedCount})> batchWatermark({
    required List<MediaRef> movies,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    final raw = await _call(
      () => client.movies.batchWatermark({
        'movie_ids': movies.map(_ommId).toList(growable: false),
        'subtitle': subtitle,
        'exsub': exsub,
        'crack': crack,
        'uhd': uhd,
      }),
    );
    _throwIfUnsuccessful(raw, '海报裁剪失败');
    if (raw is Map && raw['data'] is Map) {
      final data = raw['data'] as Map;
      return (
        successCount: _intValue(data['success_count']),
        failedCount: _intValue(data['failed_count']),
      );
    }
    return (successCount: 0, failedCount: 0);
  }

  @override
  Future<String?> mergeDuplicateFiles({
    required List<MediaRef> movies,
    required MediaRef targetMovie,
  }) async {
    final raw = await _call(
      () => client.movies.mergeDuplicateFiles({
        'movie_ids': movies.map(_ommId).toList(growable: false),
        'target_movie_id': _ommId(targetMovie),
      }),
    );
    _throwIfUnsuccessful(raw, '合并失败');
    return raw is Map && raw['data'] is Map
        ? (raw['data'] as Map)['task_id']?.toString()
        : null;
  }

  @override
  Future<Map<String, dynamic>> compareDuplicateNfo(
    List<MediaRef> movies,
  ) async {
    final raw = await _call(
      () => client.movies.compareDuplicateNfo({
        'movie_ids': movies.map(_ommId).toList(growable: false),
      }),
    );
    return unwrapStd<Map<String, dynamic>>(raw, (data) {
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    });
  }

  @override
  Future<void> applyDuplicateNfo(Map<String, dynamic> payload) async {
    final raw = await _call(() => client.movies.applyDuplicateNfo(payload));
    _throwIfUnsuccessful(raw, '应用失败');
  }

  @override
  Future<String> requestDownload({
    required List<MediaRef> movies,
    required Map<String, dynamic> requirements,
  }) async {
    final raw = await _call(
      () => client.movies.requestDownload({
        'movie_ids': movies.map(_ommId).toList(growable: false),
        'requirements': requirements,
      }),
    );
    _throwIfUnsuccessful(raw, '下载请求失败');
    return raw is Map ? (raw['message']?.toString() ?? '下载请求已提交') : '下载请求已提交';
  }

  @override
  Future<void> applyPosterCrop(
    MediaRef movie, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    final raw = await _call(
      () => client.movies.updatePosterWatermark(_ommId(movie), {
        'subtitle': subtitle,
        'exsub': exsub,
        'crack': crack,
        'uhd': uhd,
        'crop_offset': cropOffset,
      }),
    );
    _throwIfUnsuccessful(raw, '裁剪失败');
  }

  @override
  Future<List<int>> previewPosterCrop(
    MediaRef movie, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    final response = await _call(
      () => client.movies.previewPosterWatermark(_ommId(movie), {
        'subtitle': subtitle,
        'exsub': exsub,
        'crack': crack,
        'uhd': uhd,
        'crop_offset': cropOffset,
      }),
    );
    return response.data;
  }

  @override
  Future<PreviewStartResult> generatePreview(
    MediaRef movie, {
    bool overwrite = false,
  }) async {
    final raw = await _call(
      () => client.moviesExtended.generateMoviePreviews(
        _ommId(movie),
        overwrite: overwrite,
      ),
    );
    return unwrapStd<PreviewStartResult>(
      raw,
      (data) =>
          PreviewStartResult.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  @override
  Future<PreviewStatus> previewStatus(MediaRef movie, {String? taskId}) async {
    final raw = await _call(
      () =>
          client.moviesExtended.getMoviePreviews(_ommId(movie), taskId: taskId),
    );
    return unwrapStd<PreviewStatus>(
      raw,
      (data) => PreviewStatus.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  @override
  Future<PreviewTask> previewTask(String taskId) async {
    if (taskId.trim().isEmpty) throw const SourceException('预览任务 ID 不能为空');
    final raw = await _call(() => client.moviesExtended.getPreviewTask(taskId));
    return unwrapStd<PreviewTask>(
      raw,
      (data) => PreviewTask.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  @override
  Future<void> cancelPreviewTask(String taskId) async {
    if (taskId.trim().isEmpty) throw const SourceException('预览任务 ID 不能为空');
    final raw = await _call(
      () => client.moviesExtended.cancelPreviewTask(taskId),
    );
    unwrapStd<void>(raw, (_) {});
  }

  int _ommId(MediaRef ref) {
    if (ref.sourceId.value != 'omm') {
      throw SourceException('来源 ID 不属于 OMM：${ref.sourceId.value}');
    }
    final id = int.tryParse(ref.value);
    if (id == null || id <= 0) throw SourceException('OMM ID 无效：${ref.value}');
    return id;
  }

  Map<String, dynamic> _associationBody({
    required List<MediaRef> movies,
    required List<int> tagIds,
    required List<int> genreIds,
    required int? seriesId,
  }) {
    final body = <String, dynamic>{
      'movie_ids': movies.map(_ommId).toList(growable: false),
    };
    if (tagIds.isNotEmpty) body['tag_ids'] = tagIds;
    if (genreIds.isNotEmpty) body['genre_ids'] = genreIds;
    if (seriesId != null) body['series_id'] = seriesId;
    return body;
  }

  ({
    List<Map<String, dynamic>> magnets,
    List<Map<String, dynamic>> ed2ks,
    List<String> warnings,
  })
  _resourceResult(Object? raw) {
    return unwrapStd(raw, (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        List<Map<String, dynamic>> list(Object? value) {
          if (value is! List) return <Map<String, dynamic>>[];
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
        }

        return (
          magnets: list(map['magnets']),
          ed2ks: list(map['ed2ks']),
          warnings: map['warnings'] is List
              ? (map['warnings'] as List)
                    .map((item) => item.toString())
                    .toList(growable: false)
              : <String>[],
        );
      }
      return (
        magnets: <Map<String, dynamic>>[],
        ed2ks: <Map<String, dynamic>>[],
        warnings: <String>[],
      );
    });
  }

  void _throwIfUnsuccessful(Object? raw, String fallback) {
    if (raw is Map && raw['success'] == false) {
      throw SourceException((raw['message'] as String?) ?? fallback);
    }
  }

  MediaSummary _summaryFromMovie(MovieListItem movie) => MediaSummary(
    ref: MediaRef(sourceId: const SourceId('omm'), value: '${movie.id}'),
    title: movie.title,
    code: movie.num,
    year: movie.year,
    rating: movie.rating,
    duration: movie.runtime,
    poster: movie.posterUuid,
    thumbnail: movie.thumbUuid,
    fanart: movie.fanartUuid,
    canPlay: true,
    attributes: {
      'file_size': movie.fileSize,
      'file_name': movie.fileName,
      'series_name': movie.seriesName,
      'preview_video_url': movie.previewVideoUrl,
      'has_new_resources': movie.hasNewResources,
      'actors': movie.actors,
      'watch_record': movie.watchRecord,
    },
    payload: movie,
  );

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw mapSourceError(error, fallback: 'OMM 请求失败');
    }
  }

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
