import '../../api/api_client.dart';
import '../../api/envelope.dart';
import '../../api/error_codes.dart';
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
  Future<Object?> searchActors(Map<String, dynamic> query) =>
      _call(() => client.actors.search(query));

  @override
  Future<List<int>> previewActorAvatar(Map<String, dynamic> body) =>
      _call(() async {
        final response = await client.actors.previewAvatar(body);
        _throwIfBinaryError(response.data);
        if (response.data.isEmpty) {
          throw const SourceException(
            AppErrorCode.avatarContentEmpty,
            code: AppErrorCode.avatarContentEmpty,
          );
        }
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
        _ => throw const SourceException(
          AppErrorCode.unsupportedResourceType,
          code: AppErrorCode.unsupportedResourceType,
        ),
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
        _ => throw const SourceException(
          AppErrorCode.unsupportedResourceType,
          code: AppErrorCode.unsupportedResourceType,
        ),
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
        _ => throw const SourceException(
          AppErrorCode.unsupportedResourceType,
          code: AppErrorCode.unsupportedResourceType,
        ),
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
        _ => throw const SourceException(
          AppErrorCode.unsupportedResourceType,
          code: AppErrorCode.unsupportedResourceType,
        ),
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
        _ => throw const SourceException(
          AppErrorCode.unsupportedResourceType,
          code: AppErrorCode.unsupportedResourceType,
        ),
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
    () => client.tasks.submit('subtitle_transcription', {
      'audio_asset_ids': assetIds,
      'overwrite': overwrite,
    }),
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
    () => client.tasks.submit('audio_extract', {
      'movie_id': movieId,
      'format': format,
      'bitrate_kbps': bitrateKbps,
    }),
  );

  @override
  Future<Object?> cancelAudioExtraction(String taskId) =>
      _call(() => client.tasks.control(taskId, 'cancel'));

  @override
  Future<Object?> cancelSubtitleTranscription(String taskId) =>
      _call(() => client.tasks.control(taskId, 'cancel'));

  @override
  Future<Object?> retrySubtitleTranscription(String taskId) =>
      _call(() => client.tasks.control(taskId, 'retry'));

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
  Future<({String taskId, String? message})> downloadExtraFanarts(
    MediaRef movie,
  ) async {
    final raw = await _call(
      () => client.tasks.submit('extra_fanart_download', {
        'movie_ids': [_ommId(movie)],
      }),
    );
    final task = _taskSnapshot(raw);
    return (
      taskId: _taskId(task),
      message: envelopeMessageOrNull(raw) ?? envelopeMessageOrNull(task),
    );
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
  Future<({bool value, String? message})> toggleFavorite(MediaRef movie) async {
    final raw = await _call(() => client.favorites.toggle(_ommId(movie)));
    final value = unwrapStd<bool>(raw, (data) {
      return data is Map && data['is_favorited'] == true;
    });
    return (value: value, message: envelopeMessageOrNull(raw));
  }

  @override
  Future<String?> addFavoriteBatch(List<MediaRef> movies) async {
    final raw = await _call(
      () => client.favorites.addBatch({
        'movie_ids': movies.map(_ommId).toList(growable: false),
      }),
    );
    unwrapStd<void>(raw, (_) {});
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> removeFavoriteBatch(List<MediaRef> movies) async {
    final raw = await _call(
      () => client.favorites.removeBatch({
        'movie_ids': movies.map(_ommId).toList(growable: false),
      }),
    );
    unwrapStd<void>(raw, (_) {});
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<void> markWatched(MediaRef movie, bool completed) async {
    final raw = await _call(
      () =>
          client.movies.upsertWatchRecord(_ommId(movie), {'ended': completed}),
    );
    unwrapStd<void>(raw, (_) {});
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
    final raw = await _call(() => client.tasks.submit('resource_scan', body));
    final task = _taskSnapshot(raw);
    final data = raw is Map && raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : const <String, dynamic>{};
    final rejectedIds = _resourceScanRejectedIds(data['rejected']);
    final skippedIds = <int>{
      ..._intList(data['skipped_ids']),
      ...rejectedIds,
    }.toList(growable: false);
    final explicitMovieCount = ids?.length ?? 0;
    final hasAcceptedCount = data.containsKey('accepted_count');
    final hasSkippedCount = data.containsKey('skipped_count');
    final skippedCount = hasSkippedCount
        ? _intValue(data['skipped_count'])
        : skippedIds.length;
    final acceptedCount = hasAcceptedCount
        ? _intValue(data['accepted_count'])
        : (ids == null
              ? 0
              : (explicitMovieCount - skippedCount)
                    .clamp(0, explicitMovieCount)
                    .toInt());
    return ResourceScanStartResult(
      taskId: _taskId(task),
      acceptedCount: acceptedCount,
      skippedCount: skippedCount,
      skippedIds: skippedIds,
      message: envelopeMessageOrNull(raw) ?? envelopeMessageOrNull(task),
    );
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
    final raw = await _call(
      () => client.movies.upsertWatchRecord(_ommId(movie), body),
    );
    unwrapStd<void>(raw, (_) {});
  }

  @override
  Future<({MovieDetail item, String? message})> updateMovie(
    MediaRef movie,
    Map<String, dynamic> body,
  ) async {
    final raw = await _call(
      () => client.movies.updateMovie(_ommId(movie), body),
    );
    final item = unwrapStd<MovieDetail>(
      raw,
      (data) => MovieDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    return (item: item, message: envelopeMessageOrNull(raw));
  }

  @override
  Future<String?> deleteMovie(MediaRef movie, {bool force = false}) async {
    final raw = await _call(
      () => client.movies.deleteMovies({
        'movie_ids': [_ommId(movie)],
        'force': force,
      }),
    );
    unwrapStd<void>(raw, (_) {});
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> syncNfo(MediaRef movie) async {
    final raw = await _call(
      () => client.tasks.submit('nfo_sync', {
        'movie_ids': [_ommId(movie)],
      }),
    );
    final task = _taskSnapshot(raw);
    return envelopeMessageOrNull(raw) ?? envelopeMessageOrNull(task);
  }

  @override
  Future<String?> refreshFromNfo(MediaRef movie) async {
    final raw = await _call(() => client.movies.refreshFromNfo(_ommId(movie)));
    unwrapStd<void>(raw, (_) {});
    return envelopeMessageOrNull(raw);
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
  Future<String?> downloadSubtitle(
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
    return envelopeMessageOrNull(raw);
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
    _throwIfUnsuccessful(raw);
    final message = envelopeMessageOrNull(raw) ?? '';
    final lastDownloadedAt = raw is Map && raw['data'] is Map
        ? ((raw['data'] as Map)['last_downloaded_at'] ?? '').toString()
        : '';
    return (message: message, lastDownloadedAt: lastDownloadedAt);
  }

  @override
  Future<String?> batchAddAssociations({
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
    _throwIfUnsuccessful(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> batchRemoveAssociations({
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
    _throwIfUnsuccessful(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<({String? message, int successCount, int failedCount})>
  batchWatermark({
    required List<MediaRef> movies,
    bool? subtitle,
    bool? exsub,
    bool? crack,
    String? resolution,
  }) async {
    // null（未设置）不发送，由后端按各影片标签保持现有水印。
    final raw = await _call(
      () => client.movies.batchWatermark({
        'movie_ids': movies.map(_ommId).toList(growable: false),
        if (subtitle != null) 'subtitle': subtitle,
        if (exsub != null) 'exsub': exsub,
        if (crack != null) 'crack': crack,
        if (resolution != null) 'resolution': resolution,
      }),
    );
    _throwIfUnsuccessful(raw);
    if (raw is Map && raw['data'] is Map) {
      final data = raw['data'] as Map;
      return (
        message: envelopeMessageOrNull(raw),
        successCount: _intValue(data['success_count']),
        failedCount: _intValue(data['failed_count']),
      );
    }
    return (
      message: envelopeMessageOrNull(raw),
      successCount: 0,
      failedCount: 0,
    );
  }

  @override
  Future<({String? taskId, String? message})> mergeDuplicateFiles({
    required List<MediaRef> movies,
    required MediaRef targetMovie,
  }) async {
    final raw = await _call(
      () => client.tasks.submit('duplicate_movie_merge', {
        'movie_ids': movies.map(_ommId).toList(growable: false),
        'target_movie_id': _ommId(targetMovie),
      }),
    );
    _throwIfUnsuccessful(raw);
    final task = _taskSnapshot(raw);
    return (
      taskId: _taskId(task),
      message: envelopeMessageOrNull(raw) ?? envelopeMessageOrNull(task),
    );
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
  Future<String?> applyDuplicateNfo(Map<String, dynamic> payload) async {
    final raw = await _call(() => client.movies.applyDuplicateNfo(payload));
    _throwIfUnsuccessful(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> requestDownload({
    required List<MediaRef> movies,
    required Map<String, dynamic> requirements,
  }) async {
    final raw = await _call(
      () => client.movies.requestDownload({
        'movie_ids': movies.map(_ommId).toList(growable: false),
        'requirements': requirements,
      }),
    );
    _throwIfUnsuccessful(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> applyPosterCrop(
    MediaRef movie, {
    required double cropOffset,
    bool? subtitle,
    bool? exsub,
    bool? crack,
    String? resolution,
    bool syncParts = false,
  }) async {
    final raw = await _call(
      () => client.movies.updatePosterWatermark(_ommId(movie), {
        if (subtitle != null) 'subtitle': subtitle,
        if (exsub != null) 'exsub': exsub,
        if (crack != null) 'crack': crack,
        if (resolution != null) 'resolution': resolution,
        'crop_offset': cropOffset,
        'sync_parts': syncParts,
      }),
    );
    _throwIfUnsuccessful(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<List<int>> previewPosterCrop(
    MediaRef movie, {
    required double cropOffset,
    bool? subtitle,
    bool? exsub,
    bool? crack,
    String? resolution,
  }) async {
    final response = await _call(
      () => client.movies.previewPosterWatermark(_ommId(movie), {
        if (subtitle != null) 'subtitle': subtitle,
        if (exsub != null) 'exsub': exsub,
        if (crack != null) 'crack': crack,
        if (resolution != null) 'resolution': resolution,
        'crop_offset': cropOffset,
      }),
    );
    _throwIfBinaryError(response.data);
    if (response.data.isEmpty) {
      throw const SourceException(
        AppErrorCode.ommResponseInvalid,
        code: AppErrorCode.ommResponseInvalid,
      );
    }
    return response.data;
  }

  @override
  Future<PreviewStartResult> generatePreview(
    MediaRef movie, {
    bool overwrite = false,
  }) async {
    final raw = await _call(
      () => client.tasks.submit('preview_generation', {
        'movie_ids': [_ommId(movie)],
        'targets': <String>[],
        'overwrite': overwrite,
      }),
    );
    final task = _taskSnapshot(raw);
    final taskId = _taskId(task);
    return PreviewStartResult(
      taskId: taskId,
      reused: false,
      task: PreviewTask(
        taskId: taskId,
        status: (task['status'] ?? 'queued').toString(),
        movieIds: [_ommId(movie)],
        overwrite: overwrite,
        totalCount: 1,
        message: (task['message'] ?? '').toString(),
      ),
      message: envelopeMessageOrNull(raw) ?? envelopeMessageOrNull(task),
    );
  }

  @override
  Future<PreviewStatus> previewStatus(MediaRef movie) async {
    final raw = await _call(
      () => client.moviesExtended.getMoviePreviews(_ommId(movie)),
    );
    return unwrapStd<PreviewStatus>(
      raw,
      (data) => PreviewStatus.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  @override
  Future<String?> cancelPreviewTask(String taskId) async {
    if (taskId.trim().isEmpty) {
      throw const SourceException(
        AppErrorCode.previewTaskIdRequired,
        code: AppErrorCode.previewTaskIdRequired,
      );
    }
    final raw = await _call(() => client.tasks.control(taskId, 'cancel'));
    unwrapStd<void>(raw, (_) {});
    return envelopeMessageOrNull(raw);
  }

  int _ommId(MediaRef ref) {
    if (ref.sourceId.value != 'omm') {
      throw const SourceException(
        AppErrorCode.ommSourceIdInvalid,
        code: AppErrorCode.ommSourceIdInvalid,
      );
    }
    final id = int.tryParse(ref.value);
    if (id == null || id <= 0) {
      throw const SourceException(
        AppErrorCode.ommIdInvalid,
        code: AppErrorCode.ommIdInvalid,
      );
    }
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

  void _throwIfUnsuccessful(Object? raw) {
    if (raw is! Map || raw['success'] != true) {
      final message = envelopeMessageOrNull(raw);
      final code = envelopeCodeOrNull(raw);
      throw SourceException(
        message ?? code ?? AppErrorCode.ommRequestFailed,
        code: code ?? (message == null ? AppErrorCode.ommRequestFailed : null),
      );
    }
  }

  void _throwIfBinaryError(Object? raw) {
    final envelope = decodeJsonMap(raw);
    if (envelope == null) return;
    final message = envelopeMessageOrNull(envelope);
    final code = envelopeCodeOrNull(envelope);
    if (envelope['success'] != true) {
      throw SourceException(
        message ?? code ?? AppErrorCode.ommRequestFailed,
        code: code ?? (message == null ? AppErrorCode.ommRequestFailed : null),
      );
    }
    throw const SourceException(
      AppErrorCode.ommResponseInvalid,
      code: AppErrorCode.ommResponseInvalid,
    );
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
      throw mapSourceError(error, fallbackCode: AppErrorCode.ommRequestFailed);
    }
  }

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<int> _intList(Object? value) {
    if (value is! List) return <int>[];
    return value.map(_intValue).where((id) => id > 0).toSet().toList();
  }

  List<int> _resourceScanRejectedIds(Object? value) {
    if (value is! List) return <int>[];
    return value
        .map((item) {
          if (item is Map) {
            return _intValue(item['movie_id'] ?? item['movieId'] ?? item['id']);
          }
          return _intValue(item);
        })
        .where((id) => id > 0)
        .toSet()
        .toList();
  }

  Map<String, dynamic> _taskSnapshot(Object? raw) {
    return unwrapStd<Map<String, dynamic>>(raw, (data) {
      final value = data is Map && data['task'] is Map ? data['task'] : data;
      if (value is! Map) {
        throw const SourceException(
          AppErrorCode.taskResponseInvalid,
          code: AppErrorCode.taskResponseInvalid,
        );
      }
      return Map<String, dynamic>.from(value);
    });
  }

  String _taskId(Map<String, dynamic> task) {
    final taskId = (task['taskId'] ?? task['task_id'] ?? '').toString().trim();
    if (taskId.isEmpty) {
      throw const SourceException(
        AppErrorCode.taskIdMissing,
        code: AppErrorCode.taskIdMissing,
      );
    }
    return taskId;
  }
}
