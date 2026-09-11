import 'dart:convert';

import 'package:dio/dio.dart';

import '../../api/api_client.dart';
import '../../api/envelope.dart';
import '../../api/error_codes.dart';
import '../../models/movie.dart';
import '../../models/paged_result.dart';
import '../../models/playback.dart';
import '../common/source_descriptor.dart';
import '../common/source_error_mapper.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'media_capabilities.dart';
import 'media_metadata_normalizer.dart';
import 'media_models.dart';
import 'media_source.dart';
import 'omm_audio_operations_source.dart';
import 'omm_media_operations_adapter.dart';
import 'omm_metadata_operations_source.dart';
import 'omm_media_operations_source.dart';

/// OMM HTTP API adapter.
///
/// This adapter deliberately depends on [ApiClient] rather than a Feature
/// Repository.  Existing repositories remain compatibility facades while the
/// new Source layer can be introduced without creating a dependency cycle
/// from `core` back into `features`.
class OmmMediaSourceAdapter
    implements
        MediaSource,
        CatalogSource,
        MovieDetailSource,
        PlaybackSource,
        ResourceSource,
        LibraryManagementSource,
        ScanSource,
        BatchScanSource,
        OmmPlaybackOperationsSource {
  OmmMediaSourceAdapter(this.client)
    : operations = OmmMediaOperationsAdapter(client);

  final ApiClient client;
  final OmmMediaOperationsSource operations;

  OmmMetadataOperationsSource get metadataOperations =>
      operations as OmmMetadataOperationsSource;

  OmmAudioOperationsSource get audioOperations =>
      operations as OmmAudioOperationsSource;

  static const _sourceId = SourceId('omm');

  @override
  SourceDescriptor get descriptor => SourceDescriptor(
    id: _sourceId,
    kind: SourceKind.omm,
    name: 'Oh My Media',
    serverId: client.config?.activeServerId,
    endpoint: client.config?.baseUrl,
  );

  @override
  Set<MediaCapability> get capabilities => const {
    MediaCapability.catalog,
    MediaCapability.movieDetails,
    MediaCapability.playback,
    MediaCapability.resources,
    MediaCapability.libraryManagement,
    MediaCapability.scanning,
  };

  @override
  bool supports(MediaCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<MediaPage<MediaSummary>> listMovies(MediaQuery query) async {
    final offset = query.offset > 0
        ? query.offset
        : (query.page - 1) * query.limit;
    final params = <String, dynamic>{
      ...query.filters,
      'limit': query.limit,
      'offset': offset,
      if (query.sortBy != null) 'sort_by': query.sortBy,
      if (query.orderBy != null) 'sort_order': query.orderBy,
    };
    late final PagedResult<MovieListItem> page;
    try {
      page = await _call(() async {
        final raw = await client.movies.getMovies(params);
        return unwrapMovieList<MovieListItem>(raw, MovieListItem.fromJson);
      });
    } on SourceException catch (error) {
      if (offset != 0 || !_isNoResultMessage(error.message)) rethrow;
      page = PagedResult<MovieListItem>(
        items: const [],
        totalCount: 0,
        limit: query.limit,
        offset: 0,
      );
    }
    return MediaPage(
      items: page.items.map(_summaryFromMovie).toList(growable: false),
      page: query.limit <= 0 ? 1 : (offset ~/ query.limit) + 1,
      limit: page.limit,
      total: page.totalCount,
      hasMore: page.hasMore,
    );
  }

  @override
  Future<MediaPage<MediaSummary>> searchMovies(MediaQuery query) {
    final search = query.searchText?.trim() ?? '';
    return listMovies(
      query.copyWith(
        filters: {
          ...query.filters,
          if (search.isNotEmpty) 'search': search,
          if (search.isNotEmpty) 'search_type': 'title',
        },
      ),
    );
  }

  @override
  Future<MediaDetails> getMovie(MediaRef ref) async {
    final id = _ommId(ref);
    final movie = await _call(() async {
      final raw = await client.movies.getMovieDetail(id);
      return unwrapStd<MovieDetail>(
        raw,
        (data) => MovieDetail.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    });
    return _detailsFromMovie(movie);
  }

  @override
  Future<PlaybackDescriptor> resolvePlayback(
    MediaRef ref,
    PlaybackRequest request,
  ) async {
    final caps =
        request.clientCapabilities ??
        PlaybackClientCaps.mediaKit(
          qualityPreset: request.quality,
          audioStreamIndex: request.audioStreamIndex,
          subtitleTrackId: request.subtitleTrackId,
          forceVideoTranscode: request.forceVideoTranscode,
        );
    final decision = await resolvePlaybackDecision(ref, caps);
    final rawUrl = decision.streamUrl.trim().isNotEmpty
        ? decision.streamUrl.trim()
        : decision.directUrl.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      throw const SourceException(
        AppErrorCode.ommResponseInvalid,
        code: AppErrorCode.ommResponseInvalid,
      );
    }
    return PlaybackDescriptor(
      uri: uri,
      headers: decision.strmHeaders,
      mimeType: decision.mimeType,
      startAt: decision.startSec,
      isTranscode: decision.isTranscode,
      audioTracks: [
        for (final track in decision.audioTracks)
          PlaybackTrack(
            id: '${track.index}',
            label: track.title,
            language: track.language,
            kind: 'audio',
          ),
      ],
      subtitleTracks: [
        for (final track in decision.subtitleTracks)
          PlaybackTrack(
            id: track.id,
            label: track.title,
            language: track.language,
            kind: 'subtitle',
          ),
      ],
      payload: decision,
    );
  }

  @override
  Future<PlaybackDecision> resolvePlaybackDecision(
    MediaRef movie,
    PlaybackClientCaps capabilities,
  ) => _call(() => client.playback.decision(_ommId(movie), capabilities));

  @override
  Future<TranscodeStatus> transcodeStatus(
    MediaRef movie, {
    String quality = 'auto',
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) => _call(
    () => client.playback.status(
      _ommId(movie),
      quality: quality,
      mode: mode,
      audioStreamIndex: audioStreamIndex,
      subtitleTrackId: subtitleTrackId,
    ),
  );

  @override
  Stream<TranscodeStatus> transcodeEvents(
    MediaRef movie, {
    String quality = 'auto',
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) async* {
    try {
      yield* client.playback.events(
        _ommId(movie),
        quality: quality,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      );
    } catch (error) {
      throw mapSourceError(
        error,
        fallbackCode: AppErrorCode.ommTranscodeStatusFailed,
      );
    }
  }

  @override
  Future<void> stopTranscode(MediaRef movie) =>
      _call(() => client.playback.stop(_ommId(movie)));

  @override
  Future<String> fetchSubtitleContent(String url) async {
    try {
      final response = await client.dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final content = (response.data ?? '').trim();
      final envelope = decodeJsonMap(content);
      if (envelope != null) {
        final message = envelopeMessageOrNull(envelope);
        final code = envelopeCodeOrNull(envelope);
        throw SourceException(
          message ?? code ?? AppErrorCode.ommSubtitleFetchFailed,
          code:
              code ??
              (message == null ? AppErrorCode.ommSubtitleFetchFailed : null),
          statusCode: response.statusCode,
        );
      }
      if (!content.contains('-->')) {
        throw const SourceException(
          AppErrorCode.ommSubtitleInvalid,
          code: AppErrorCode.ommSubtitleInvalid,
        );
      }
      return content;
    } catch (error) {
      if (error is SourceException) rethrow;
      throw _mapSubtitleError(error);
    }
  }

  @override
  Future<List<MediaResource>> listResources(
    MediaRef ref, {
    String? category,
  }) async {
    final id = _ommId(ref);
    final source = category?.trim().isNotEmpty == true
        ? category!.trim()
        : 'all';
    final raw = await _call(() => client.movies.getResources(id, source));
    final data = _unwrapData(raw);
    final items = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : const <Object?>[];
    return items
        .whereType<Map>()
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          final value = (json['url'] ?? json['path'] ?? json['value'])
              ?.toString();
          return MediaResource(
            kind: _resourceKind(category),
            name: (json['name'] ?? json['label'] ?? value ?? '').toString(),
            value: value,
            mimeType: json['mime_type']?.toString(),
            size: _intValue(json['size'] ?? json['file_size']),
            attributes: json,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<MediaLibrary>> listLibraries({
    bool enabledOnly = false,
    bool withCover = false,
  }) async {
    final raw = await _call(
      () => client.libraries.list({
        'enabled_only': enabledOnly,
        'with_cover': withCover,
      }),
    );
    final data = _unwrapData(raw);
    final items = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : const <Object?>[];
    return items.whereType<Map>().map(_libraryFromJson).toList(growable: false);
  }

  @override
  Future<MediaLibrary> getLibrary(MediaRef ref) async {
    final raw = await _call(() => client.libraries.detail(_ommId(ref)));
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommLibraryResponseInvalid,
        code: AppErrorCode.ommLibraryResponseInvalid,
      );
    }
    return _libraryFromJson(data, message: envelopeMessageOrNull(raw));
  }

  @override
  Future<MediaLibrary> createLibrary({
    required String name,
    bool enabled = true,
  }) async {
    final raw = await _call(
      () => client.libraries.create({'name': name, 'enabled': enabled}),
    );
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommLibraryResponseInvalid,
        code: AppErrorCode.ommLibraryResponseInvalid,
      );
    }
    return _libraryFromJson(data, message: envelopeMessageOrNull(raw));
  }

  @override
  Future<MediaLibrary> updateLibrary(
    MediaRef ref,
    MediaLibraryPatch patch,
  ) async {
    final body = <String, dynamic>{
      if (patch.name != null) 'name': patch.name,
      if (patch.enabled != null) 'enabled': patch.enabled,
    };
    final raw = await _call(() => client.libraries.update(_ommId(ref), body));
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommLibraryResponseInvalid,
        code: AppErrorCode.ommLibraryResponseInvalid,
      );
    }
    return _libraryFromJson(data, message: envelopeMessageOrNull(raw));
  }

  @override
  Future<String?> deleteLibrary(MediaRef ref) async {
    final raw = await _call(
      () => client.libraries.delete({
        'libraries_ids': [_ommId(ref)],
      }),
    );
    _unwrapData(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<List<MediaLibraryFolder>> listFolders(MediaRef library) async {
    final raw = await _call(
      () => client.libraries.listDirectories(_ommId(library)),
    );
    final data = _unwrapData(raw);
    final items = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : const <Object?>[];
    return items
        .whereType<Map>()
        .map((item) {
          return _folderFromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  @override
  Future<MediaLibraryFolder> createFolder(
    MediaRef library, {
    required String path,
    String? name,
    bool enabled = true,
  }) async {
    final raw = await _call(
      () => client.libraries.createDirectory(_ommId(library), {
        'path': path,
        'name': name ?? path,
        'enabled': enabled,
      }),
    );
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommFolderResponseInvalid,
        code: AppErrorCode.ommFolderResponseInvalid,
      );
    }
    return _folderFromJson(
      Map<String, dynamic>.from(data),
      message: envelopeMessageOrNull(raw),
    );
  }

  @override
  Future<MediaLibraryFolder> updateFolder(
    MediaRef library,
    MediaRef folder,
    MediaFolderPatch patch,
  ) async {
    final body = <String, dynamic>{
      if (patch.name != null) 'name': patch.name,
      if (patch.path != null) 'path': patch.path,
      if (patch.enabled != null) 'enabled': patch.enabled,
    };
    final raw = await _call(
      () => client.libraries.updateDirectory(
        _ommId(library),
        _ommId(folder),
        body,
      ),
    );
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommFolderResponseInvalid,
        code: AppErrorCode.ommFolderResponseInvalid,
      );
    }
    return _folderFromJson(
      Map<String, dynamic>.from(data),
      message: envelopeMessageOrNull(raw),
    );
  }

  @override
  Future<String?> deleteFolder(MediaRef library, MediaRef folder) async {
    final raw = await _call(
      () => client.libraries.deleteDirectory(_ommId(library), {
        'directories_ids': [_ommId(folder)],
      }),
    );
    _unwrapData(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<PathValidationResult> validatePath(
    String path, {
    MediaRef? folder,
  }) async {
    final raw = await _call(
      () => client.libraries.validatePath({
        'path': path,
        if (folder != null) 'directory_id': _ommId(folder),
      }),
    );
    final json = _unwrapData(raw);
    if (json is! Map) {
      throw const SourceException(
        AppErrorCode.ommPathValidationResponseInvalid,
        code: AppErrorCode.ommPathValidationResponseInvalid,
      );
    }
    return PathValidationResult(
      exists: json['exists'] == true,
      isDirectory: json['is_directory'] == true,
      isDuplicate: json['is_duplicate'] == true,
      error: _stringOrNull(json['error']),
    );
  }

  @override
  Future<ScanJob> startScan(MediaRef library, {bool incremental = true}) async {
    final raw = await _call(
      () => client.tasks.submit('library_scan', {
        'library_ids': [_ommId(library)],
        'incremental': incremental,
      }),
    );
    final data = _unwrapData(raw);
    final task = data is Map && data['task'] is Map
        ? data['task'] as Map
        : data;
    final jobId = task is Map
        ? (task['task_id'] ?? task['id'] ?? task['taskId'])?.toString()
        : data?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw const SourceException(
        AppErrorCode.ommScanTaskIdMissing,
        code: AppErrorCode.ommScanTaskIdMissing,
      );
    }
    return ScanJob(
      id: jobId,
      library: library,
      status: ScanJobStatus.queued,
      message: envelopeMessageOrNull(raw),
    );
  }

  @override
  Future<List<ScanJob>> activeScans(MediaRef library) async {
    final raw = await _call(() => client.tasks.list(taskType: 'library_scan'));
    final data = _unwrapData(raw);
    final items = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : const <Object?>[];
    return items
        .whereType<Map>()
        .where((item) {
          final status = (item['status'] ?? '').toString().trim().toLowerCase();
          final ids = item['libraryIds'] ?? item['library_ids'];
          return const {
                'queued',
                'running',
                'processing',
                'paused',
                'canceling',
                'cancelling',
              }.contains(status) &&
              (ids is! List ||
                  ids.isEmpty ||
                  ids
                      .map((value) => value.toString())
                      .contains(_ommId(library).toString()));
        })
        .map((item) {
          return _scanFromJson(Map<String, dynamic>.from(item), library);
        })
        .toList(growable: false);
  }

  @override
  Future<ScanJob> scanProgress(MediaRef library, String jobId) async {
    final raw = await _call(() => client.tasks.get(jobId));
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommResponseInvalid,
        code: AppErrorCode.ommResponseInvalid,
      );
    }
    return _scanFromJson(Map<String, dynamic>.from(data), library);
  }

  @override
  Future<String?> pauseScan(MediaRef library, String jobId) async {
    final raw = await _call(() => client.tasks.control(jobId, 'pause'));
    _unwrapData(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> resumeScan(MediaRef library, String jobId) async {
    final raw = await _call(() => client.tasks.control(jobId, 'resume'));
    _unwrapData(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<String?> cancelScan(MediaRef library, String jobId) async {
    final raw = await _call(() => client.tasks.control(jobId, 'cancel'));
    _unwrapData(raw);
    return envelopeMessageOrNull(raw);
  }

  @override
  Future<BatchScanResult> startBatchScan({required bool incremental}) async {
    final raw = await _call(
      () => client.tasks.submit('library_scan', {
        'library_ids': <int>[],
        'incremental': incremental,
      }),
    );
    final message = envelopeMessage(raw, fallback: '');
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException(
        AppErrorCode.ommBatchScanResponseInvalid,
        code: AppErrorCode.ommBatchScanResponseInvalid,
      );
    }
    final json = Map<String, dynamic>.from(data);
    final tasks = _batchScanTasks(json['tasks']);
    return BatchScanResult(
      message: message,
      scanType: (json['scan_type'] ?? (incremental ? 'incremental' : 'full'))
          .toString(),
      enabledCount: _intValue(json['enabled_count']) ?? 0,
      acceptedCount: _intValue(json['accepted_count']) ?? 0,
      reusedCount: _intValue(json['reused_count']) ?? 0,
      failedCount: _intValue(json['failed_count']) ?? 0,
      skippedDisabledCount: _intValue(json['skipped_disabled_count']) ?? 0,
      tasks: tasks,
    );
  }

  MediaSummary _summaryFromMovie(MovieListItem movie) => MediaSummary(
    ref: MediaRef(sourceId: _sourceId, value: '${movie.id}'),
    title: normalizeMediaText(movie.title) ?? '',
    code: normalizeMediaText(movie.num),
    year: normalizeMediaYear(movie.year),
    rating: normalizeMediaRating(movie.rating),
    duration: normalizeMediaDurationMinutes(movie.runtime),
    poster: movie.posterUuid,
    thumbnail: movie.thumbUuid,
    fanart: movie.fanartUuid,
    canPlay: true,
    attributes: {
      'file_size': movie.fileSize,
      'file_name': movie.fileName,
      'resolution_tier': resolutionTierToApi(movie.resolutionTier),
      'series_name': movie.seriesName,
      'preview_video_url': movie.previewVideoUrl,
      'has_new_resources': movie.hasNewResources,
      'actors': movie.actors,
      'watch_record': movie.watchRecord,
    },
    payload: movie,
  );

  MediaDetails _detailsFromMovie(MovieDetail movie) {
    final summary = MediaSummary(
      ref: MediaRef(sourceId: _sourceId, value: '${movie.id}'),
      title: normalizeMediaText(movie.title) ?? '',
      code: normalizeMediaText(movie.num),
      year: normalizeMediaYear(movie.year),
      rating: normalizeMediaRating(movie.rating),
      duration: normalizeMediaDurationMinutes(movie.runtime),
      poster: movie.posterUuid,
      thumbnail: movie.thumbUuid,
      fanart: movie.fanartUuid,
      canPlay: movie.filePath?.isNotEmpty == true,
      attributes: {
        'is_favorited': movie.isFavorited,
        'has_external_subtitle': movie.hasExternalSubtitle,
        'has_internal_subtitle': movie.hasInternalSubtitle,
        'movie_part': movie.moviePart,
        'series': movie.series,
        'watch_record': movie.watchRecord,
      },
      payload: movie,
    );
    return MediaDetails(
      summary: summary,
      originalTitle: normalizeMediaText(movie.originalTitle),
      overview:
          normalizeMediaText(movie.plot) ?? normalizeMediaText(movie.outline),
      filePath: movie.filePath,
      fileSize: movie.fileSize,
      tags: normalizeMediaLabels(movie.tags.map((item) => item.name)),
      genres: normalizeMediaLabels(movie.genres.map((item) => item.name)),
      actors: normalizeMediaLabels(movie.actors.map((item) => item.name)),
      payload: movie,
    );
  }

  MediaLibrary _libraryFromJson(Map raw, {String? message}) {
    final json = Map<String, dynamic>.from(raw);
    final id = _intValue(json['id']);
    if (id == null) {
      throw const SourceException(
        AppErrorCode.ommLibraryIdMissing,
        code: AppErrorCode.ommLibraryIdMissing,
      );
    }
    final rawFolders = json['directories'];
    final folders = rawFolders is List
        ? rawFolders
              .whereType<Map>()
              .map((item) => _folderFromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
        : const <MediaLibraryFolder>[];
    return MediaLibrary(
      ref: MediaRef(sourceId: _sourceId, value: '$id'),
      name: json['name']?.toString() ?? '',
      description: _stringOrNull(json['description']),
      enabled: json['enabled'] != false,
      fileCount: _intValue(json['file_count']) ?? 0,
      folders: folders,
      attributes: json,
      message: message,
    );
  }

  MediaLibraryFolder _folderFromJson(
    Map<String, dynamic> json, {
    String? message,
  }) {
    final id = _intValue(json['id']);
    if (id == null) {
      throw const SourceException(
        AppErrorCode.ommFolderIdMissing,
        code: AppErrorCode.ommFolderIdMissing,
      );
    }
    return MediaLibraryFolder(
      ref: MediaRef(sourceId: _sourceId, value: '$id'),
      path: json['path']?.toString() ?? '',
      name: _stringOrNull(json['name']),
      enabled: json['enabled'] != false,
      fileCount: _intValue(json['file_count']) ?? 0,
      message: message,
    );
  }

  ScanJob _scanFromJson(Map<String, dynamic> json, MediaRef library) {
    final progress = json['progress'];
    return ScanJob(
      id: (json['task_id'] ?? json['taskId'] ?? json['id'] ?? '').toString(),
      library: library,
      status: _scanStatus(json['status']),
      totalFiles: _intValue(
        progress is Map ? progress['total'] : json['total_files'],
      ),
      processedFiles: _intValue(
        progress is Map ? progress['completed'] : json['processed_files'],
      ),
      addedFiles: _intValue(json['added_files'] ?? json['new_movies']) ?? 0,
      updatedFiles:
          _intValue(json['updated_files'] ?? json['updated_movies']) ?? 0,
      removedFiles:
          _intValue(json['removed_files'] ?? json['deleted_movies']) ?? 0,
      currentFile: _stringOrNull(
        json['current_file'] ?? json['current_file_path'] ?? json['fileName'],
      ),
      message: _stringOrNull(json['message']),
    );
  }

  int _ommId(MediaRef ref) {
    if (ref.sourceId != _sourceId) {
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

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw mapSourceError(error, fallbackCode: AppErrorCode.ommRequestFailed);
    }
  }
}

bool _isNoResultMessage(String message) {
  final normalized = message.trim().toLowerCase();
  return normalized == '没有找到符合条件的影片' || normalized == 'no matching titles';
}

SourceException _mapSubtitleError(Object error) {
  if (error is DioException) {
    Object? data = error.response?.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }
    final message = envelopeMessageOrNull(data);
    if (message != null) {
      return SourceException(
        message,
        code: envelopeCodeOrNull(data),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }
  return mapSourceError(
    error,
    fallbackCode: AppErrorCode.ommSubtitleFetchFailed,
  );
}

Object? _unwrapData(Object? raw) {
  if (raw is! Map || raw['success'] != true) {
    final message = envelopeMessageOrNull(raw);
    final code = envelopeCodeOrNull(raw);
    throw SourceException(
      message ?? code ?? AppErrorCode.ommRequestFailed,
      code: code ?? (message == null ? AppErrorCode.ommRequestFailed : null),
    );
  }
  if (raw.containsKey('data')) return raw['data'];
  return raw;
}

List<BatchScanTask> _batchScanTasks(Object? value) {
  if (value is! List) return const <BatchScanTask>[];
  return value
      .whereType<Map>()
      .map((item) {
        final json = Map<String, dynamic>.from(item);
        return BatchScanTask(
          libraryId: _intValue(json['library_id'] ?? json['libraryId']) ?? 0,
          libraryName: (json['library_name'] ?? json['libraryName'] ?? '')
              .toString(),
          taskId: (json['task_id'] ?? json['taskId'] ?? json['id'] ?? '')
              .toString(),
          status: (json['status'] ?? '').toString(),
          queuePosition:
              _intValue(json['queue_position'] ?? json['queuePosition']) ?? 0,
          reused: json['reused'] == true,
        );
      })
      .toList(growable: false);
}

MediaResourceKind _resourceKind(String? category) => switch (category?.trim()) {
  'subtitle' => MediaResourceKind.subtitle,
  'image' => MediaResourceKind.image,
  'file' => MediaResourceKind.file,
  'magnet' => MediaResourceKind.magnet,
  'ed2k' => MediaResourceKind.ed2k,
  _ => MediaResourceKind.other,
};

ScanJobStatus _scanStatus(Object? value) =>
    switch (value?.toString().trim().toLowerCase()) {
      'queued' || 'pending' => ScanJobStatus.queued,
      'running' || 'processing' => ScanJobStatus.running,
      'paused' => ScanJobStatus.paused,
      'completed' || 'success' || 'finished' => ScanJobStatus.completed,
      'failed' || 'error' => ScanJobStatus.failed,
      'canceling' || 'cancelling' => ScanJobStatus.canceling,
      'canceled' || 'cancelled' => ScanJobStatus.canceled,
      _ => ScanJobStatus.unknown,
    };

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
