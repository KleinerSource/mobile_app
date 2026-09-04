import 'dart:convert';

import 'package:dio/dio.dart';

import '../../api/api_client.dart';
import '../../api/envelope.dart';
import '../../models/movie.dart';
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
    final page = await _call(() async {
      final raw = await client.movies.getMovies(params);
      return unwrapMovieList<MovieListItem>(raw, MovieListItem.fromJson);
    });
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
      throw const SourceException('OMM 播放决策未返回有效地址');
    }
    return PlaybackDescriptor(
      uri: uri,
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
      throw mapSourceError(error, fallback: 'OMM 转码状态请求失败');
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
      if (!content.contains('-->')) {
        throw const SourceException('字幕内容无效或为空');
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
    if (data is! Map) throw const SourceException('OMM 媒体库响应格式错误');
    return _libraryFromJson(data);
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
    if (data is! Map) throw const SourceException('OMM 媒体库响应格式错误');
    return _libraryFromJson(data);
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
    if (data is! Map) throw const SourceException('OMM 媒体库响应格式错误');
    return _libraryFromJson(data);
  }

  @override
  Future<void> deleteLibrary(MediaRef ref) async {
    final raw = await _call(
      () => client.libraries.delete({
        'libraries_ids': [_ommId(ref)],
      }),
    );
    _unwrapData(raw);
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
    if (data is! Map) throw const SourceException('OMM 目录响应格式错误');
    return _folderFromJson(Map<String, dynamic>.from(data));
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
    if (data is! Map) throw const SourceException('OMM 目录响应格式错误');
    return _folderFromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> deleteFolder(MediaRef library, MediaRef folder) async {
    final raw = await _call(
      () => client.libraries.deleteDirectory(_ommId(library), {
        'directories_ids': [_ommId(folder)],
      }),
    );
    _unwrapData(raw);
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
    if (json is! Map) throw const SourceException('OMM 路径校验响应格式错误');
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
      () =>
          client.libraries.scan(_ommId(library), {'incremental': incremental}),
    );
    final data = _unwrapData(raw);
    final jobId = data is Map
        ? (data['task_id'] ?? data['id'] ?? data['taskId'])?.toString()
        : data?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw const SourceException('OMM 扫描响应缺少任务 ID');
    }
    return ScanJob(id: jobId, library: library, status: ScanJobStatus.queued);
  }

  @override
  Future<List<ScanJob>> activeScans(MediaRef library) async {
    final raw = await _call(
      () => client.libraries.activeScans(_ommId(library)),
    );
    final data = _unwrapData(raw);
    final items = data is List
        ? data
        : data is Map && data['active_scans'] is List
        ? data['active_scans'] as List
        : data is Map && data['items'] is List
        ? data['items'] as List
        : const <Object?>[];
    return items
        .whereType<Map>()
        .map((item) {
          return _scanFromJson(Map<String, dynamic>.from(item), library);
        })
        .toList(growable: false);
  }

  @override
  Future<ScanJob> scanProgress(MediaRef library, String jobId) async {
    final raw = await _call(
      () => client.libraries.scanProgress(_ommId(library), jobId),
    );
    final data = _unwrapData(raw);
    if (data is! Map) throw const SourceException('OMM 扫描进度响应格式错误');
    return _scanFromJson(Map<String, dynamic>.from(data), library);
  }

  @override
  Future<void> pauseScan(MediaRef library, String jobId) async {
    await _call(() => client.libraries.pauseScan(_ommId(library), jobId));
  }

  @override
  Future<void> resumeScan(MediaRef library, String jobId) async {
    await _call(() => client.libraries.resumeScan(_ommId(library), jobId));
  }

  @override
  Future<void> cancelScan(MediaRef library, String jobId) async {
    await _call(() => client.libraries.cancelScan(_ommId(library), jobId));
  }

  @override
  Future<BatchScanResult> startBatchScan({required bool incremental}) async {
    final raw = await _call(
      () => client.librariesExtended.batchScan({'incremental': incremental}),
    );
    final message = raw is Map ? (raw['message'] ?? '').toString() : '';
    final data = _unwrapData(raw);
    if (data is! Map) {
      throw const SourceException('OMM 批量扫描响应格式错误');
    }
    final tasks = <BatchScanTask>[];
    final rawTasks = data['tasks'];
    if (rawTasks is List) {
      for (final rawTask in rawTasks.whereType<Map>()) {
        final task = Map<String, dynamic>.from(rawTask);
        final libraryId = _intValue(task['library_id']) ?? 0;
        final taskId = (task['task_id'] ?? '').toString();
        if (libraryId <= 0 || taskId.isEmpty) continue;
        tasks.add(
          BatchScanTask(
            libraryId: libraryId,
            libraryName: (task['library_name'] ?? '媒体库 $libraryId').toString(),
            taskId: taskId,
            status: (task['status'] ?? 'queued').toString(),
            queuePosition: _intValue(task['queue_position']) ?? 0,
            reused: task['reused'] == true,
          ),
        );
      }
    }
    return BatchScanResult(
      message: message,
      scanType: (data['scan_type'] ?? (incremental ? '增量扫描' : '全量扫描'))
          .toString(),
      enabledCount: _intValue(data['enabled_count']) ?? 0,
      acceptedCount: _intValue(data['accepted_count']) ?? 0,
      reusedCount: _intValue(data['reused_count']) ?? 0,
      failedCount: _intValue(data['failed_count']) ?? 0,
      skippedDisabledCount: _intValue(data['skipped_disabled_count']) ?? 0,
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
      'series_name': movie.seriesName,
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

  MediaLibrary _libraryFromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    final id = _intValue(json['id']);
    if (id == null) throw const SourceException('OMM 媒体库缺少有效 ID');
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
    );
  }

  MediaLibraryFolder _folderFromJson(Map<String, dynamic> json) {
    final id = _intValue(json['id']);
    if (id == null) throw const SourceException('OMM 目录缺少有效 ID');
    return MediaLibraryFolder(
      ref: MediaRef(sourceId: _sourceId, value: '$id'),
      path: json['path']?.toString() ?? '',
      name: _stringOrNull(json['name']),
      enabled: json['enabled'] != false,
      fileCount: _intValue(json['file_count']) ?? 0,
    );
  }

  ScanJob _scanFromJson(Map<String, dynamic> json, MediaRef library) {
    return ScanJob(
      id: (json['task_id'] ?? json['id'] ?? '').toString(),
      library: library,
      status: _scanStatus(json['status']),
      totalFiles: _intValue(json['total_files']),
      processedFiles: _intValue(json['processed_files']),
      addedFiles: _intValue(json['added_files'] ?? json['new_movies']) ?? 0,
      updatedFiles:
          _intValue(json['updated_files'] ?? json['updated_movies']) ?? 0,
      removedFiles:
          _intValue(json['removed_files'] ?? json['deleted_movies']) ?? 0,
      currentFile: _stringOrNull(
        json['current_file'] ?? json['current_file_path'],
      ),
      message: _stringOrNull(json['message']),
    );
  }

  int _ommId(MediaRef ref) {
    if (ref.sourceId != _sourceId) {
      throw SourceException('来源 ID 不属于 OMM：${ref.sourceId.value}');
    }
    final id = int.tryParse(ref.value);
    if (id == null || id <= 0) {
      throw SourceException('OMM ID 无效：${ref.value}');
    }
    return id;
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw mapSourceError(error, fallback: 'OMM 请求失败');
    }
  }
}

SourceException _mapSubtitleError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['message'] is String) {
          return SourceException(
            decoded['message'] as String,
            statusCode: error.response?.statusCode,
            cause: error,
          );
        }
      } catch (_) {}
    }
  }
  return mapSourceError(error, fallback: '字幕内容获取失败');
}

Object? _unwrapData(Object? raw) {
  if (raw is Map && raw['success'] == false) {
    throw SourceException(raw['message']?.toString() ?? '服务端请求失败');
  }
  if (raw is Map && raw.containsKey('data')) return raw['data'];
  return raw;
}

MediaResourceKind _resourceKind(String? category) => switch (category?.trim()) {
  'subtitle' => MediaResourceKind.subtitle,
  'image' => MediaResourceKind.image,
  'file' => MediaResourceKind.file,
  'magnet' => MediaResourceKind.magnet,
  'ed2k' => MediaResourceKind.ed2k,
  _ => MediaResourceKind.other,
};

ScanJobStatus _scanStatus(Object? value) => switch (value?.toString()) {
  'queued' || 'pending' => ScanJobStatus.queued,
  'running' => ScanJobStatus.running,
  'paused' => ScanJobStatus.paused,
  'completed' || 'success' || 'finished' => ScanJobStatus.completed,
  'failed' || 'error' => ScanJobStatus.failed,
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
