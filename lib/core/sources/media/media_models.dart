import 'package:flutter/foundation.dart';

import '../../models/playback.dart';
import '../common/source_id.dart';

enum MediaCatalogMode { recommended, latest, tagged, search }

@immutable
class MediaRef {
  const MediaRef({
    required this.sourceId,
    required this.value,
    this.alternateValue,
  });

  final SourceId sourceId;
  final String value;
  final String? alternateValue;

  String get stableKey =>
      '${sourceId.value}:$value${alternateValue == null ? '' : ':$alternateValue'}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaRef &&
          other.sourceId == sourceId &&
          other.value == value &&
          other.alternateValue == alternateValue;

  @override
  int get hashCode => Object.hash(sourceId, value, alternateValue);
}

@immutable
class MediaQuery {
  const MediaQuery({
    this.mode = MediaCatalogMode.latest,
    this.searchText,
    this.tagFilter,
    this.page = 1,
    this.limit = 24,
    this.offset = 0,
    this.sortBy,
    this.orderBy,
    this.filters = const <String, Object?>{},
  });

  final MediaCatalogMode mode;
  final String? searchText;
  final String? tagFilter;
  final int page;
  final int limit;
  final int offset;
  final String? sortBy;
  final String? orderBy;
  final Map<String, Object?> filters;

  MediaQuery copyWith({
    MediaCatalogMode? mode,
    String? searchText,
    String? tagFilter,
    int? page,
    int? limit,
    int? offset,
    String? sortBy,
    String? orderBy,
    Map<String, Object?>? filters,
  }) {
    return MediaQuery(
      mode: mode ?? this.mode,
      searchText: searchText ?? this.searchText,
      tagFilter: tagFilter ?? this.tagFilter,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      sortBy: sortBy ?? this.sortBy,
      orderBy: orderBy ?? this.orderBy,
      filters: filters ?? this.filters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaQuery || !mapEquals(other.filters, filters)) {
      return false;
    }
    return other.mode == mode &&
        other.searchText == searchText &&
        other.tagFilter == tagFilter &&
        other.page == page &&
        other.limit == limit &&
        other.offset == offset &&
        other.sortBy == sortBy &&
        other.orderBy == orderBy;
  }

  @override
  int get hashCode => Object.hash(
    mode,
    searchText,
    tagFilter,
    page,
    limit,
    offset,
    sortBy,
    orderBy,
    Object.hashAll(
      filters.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

@immutable
class MediaPage<T> {
  const MediaPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
    this.total,
    this.metadata = const <String, Object?>{},
  });

  final List<T> items;
  final int page;
  final int limit;
  final bool hasMore;
  final int? total;
  final Map<String, Object?> metadata;
}

@immutable
class MediaSummary {
  const MediaSummary({
    required this.ref,
    required this.title,
    this.code,
    this.year,
    this.rating,
    this.duration,
    this.poster,
    this.thumbnail,
    this.fanart,
    this.canPlay = false,
    this.attributes = const <String, Object?>{},
    this.payload,
  });

  final MediaRef ref;
  final String title;
  final String? code;
  final int? year;
  final double? rating;
  final int? duration;
  final String? poster;
  final String? thumbnail;
  final String? fanart;
  final bool canPlay;
  final Map<String, Object?> attributes;
  final Object? payload;
}

@immutable
class MediaDetails {
  const MediaDetails({
    required this.summary,
    this.originalTitle,
    this.overview,
    this.filePath,
    this.fileSize,
    this.tags = const <String>[],
    this.genres = const <String>[],
    this.actors = const <String>[],
    this.attributes = const <String, Object?>{},
    this.payload,
  });

  final MediaSummary summary;
  final String? originalTitle;
  final String? overview;
  final String? filePath;
  final int? fileSize;
  final List<String> tags;
  final List<String> genres;
  final List<String> actors;
  final Map<String, Object?> attributes;
  final Object? payload;
}

@immutable
class PlaybackRequest {
  const PlaybackRequest({
    this.quality = 'auto',
    this.forceVideoTranscode = false,
    this.audioStreamIndex,
    this.subtitleTrackId,
    this.playSourceId,
    this.episodeIndex,
    this.clientCapabilities,
  });

  final String quality;
  final bool forceVideoTranscode;
  final int? audioStreamIndex;
  final String? subtitleTrackId;
  final int? playSourceId;
  final int? episodeIndex;
  final PlaybackClientCaps? clientCapabilities;

  @override
  bool operator ==(Object other) =>
      other is PlaybackRequest &&
      other.quality == quality &&
      other.forceVideoTranscode == forceVideoTranscode &&
      other.audioStreamIndex == audioStreamIndex &&
      other.subtitleTrackId == subtitleTrackId &&
      other.playSourceId == playSourceId &&
      other.episodeIndex == episodeIndex &&
      other.clientCapabilities == clientCapabilities;

  @override
  int get hashCode => Object.hash(
    quality,
    forceVideoTranscode,
    audioStreamIndex,
    subtitleTrackId,
    playSourceId,
    episodeIndex,
    clientCapabilities,
  );
}

@immutable
class PlaybackTrack {
  const PlaybackTrack({
    required this.id,
    required this.label,
    this.language,
    this.kind = 'unknown',
  });

  final String id;
  final String label;
  final String? language;
  final String kind;
}

@immutable
class PlaybackDescriptor {
  const PlaybackDescriptor({
    required this.uri,
    this.mimeType,
    this.headers = const <String, String>{},
    this.startAt = 0,
    this.isTranscode = false,
    this.audioTracks = const <PlaybackTrack>[],
    this.subtitleTracks = const <PlaybackTrack>[],
    this.payload,
  });

  final Uri uri;
  final String? mimeType;
  final Map<String, String> headers;
  final double startAt;
  final bool isTranscode;
  final List<PlaybackTrack> audioTracks;
  final List<PlaybackTrack> subtitleTracks;
  final Object? payload;
}

enum MediaResourceKind { file, subtitle, image, magnet, ed2k, episode, other }

@immutable
class MediaResource {
  const MediaResource({
    required this.kind,
    required this.name,
    this.value,
    this.mimeType,
    this.size,
    this.attributes = const <String, Object?>{},
  });

  final MediaResourceKind kind;
  final String name;
  final String? value;
  final String? mimeType;
  final int? size;
  final Map<String, Object?> attributes;
}

@immutable
class MediaLibrary {
  const MediaLibrary({
    required this.ref,
    required this.name,
    this.description,
    this.enabled = true,
    this.fileCount = 0,
    this.folders = const <MediaLibraryFolder>[],
    this.attributes = const <String, Object?>{},
  });

  final MediaRef ref;
  final String name;
  final String? description;
  final bool enabled;
  final int fileCount;
  final List<MediaLibraryFolder> folders;
  final Map<String, Object?> attributes;
}

@immutable
class MediaLibraryFolder {
  const MediaLibraryFolder({
    required this.ref,
    required this.path,
    this.name,
    this.enabled = true,
    this.fileCount = 0,
  });

  final MediaRef ref;
  final String path;
  final String? name;
  final bool enabled;
  final int fileCount;
}

@immutable
class PathValidationResult {
  const PathValidationResult({
    required this.exists,
    required this.isDirectory,
    required this.isDuplicate,
    this.error,
  });

  final bool exists;
  final bool isDirectory;
  final bool isDuplicate;
  final String? error;
}

enum ScanJobStatus {
  queued,
  running,
  paused,
  completed,
  failed,
  canceled,
  unknown,
}

@immutable
class ScanJob {
  const ScanJob({
    required this.id,
    required this.status,
    this.library,
    this.totalFiles,
    this.processedFiles,
    this.addedFiles = 0,
    this.updatedFiles = 0,
    this.removedFiles = 0,
    this.currentFile,
    this.message,
  });

  final String id;
  final ScanJobStatus status;
  final MediaRef? library;
  final int? totalFiles;
  final int? processedFiles;
  final int addedFiles;
  final int updatedFiles;
  final int removedFiles;
  final String? currentFile;
  final String? message;

  double get progress {
    final total = totalFiles ?? 0;
    final processed = processedFiles ?? 0;
    if (total <= 0) return 0;
    return (processed / total).clamp(0.0, 1.0);
  }
}

@immutable
class BatchScanTask {
  const BatchScanTask({
    required this.libraryId,
    required this.libraryName,
    required this.taskId,
    required this.status,
    this.queuePosition = 0,
    this.reused = false,
  });

  final int libraryId;
  final String libraryName;
  final String taskId;
  final String status;
  final int queuePosition;
  final bool reused;
}

@immutable
class BatchScanResult {
  const BatchScanResult({
    this.message = '',
    this.scanType = '',
    this.enabledCount = 0,
    this.acceptedCount = 0,
    this.reusedCount = 0,
    this.failedCount = 0,
    this.skippedDisabledCount = 0,
    this.tasks = const <BatchScanTask>[],
  });

  final String message;
  final String scanType;
  final int enabledCount;
  final int acceptedCount;
  final int reusedCount;
  final int failedCount;
  final int skippedDisabledCount;
  final List<BatchScanTask> tasks;
}

class MediaLibraryPatch {
  const MediaLibraryPatch({this.name, this.enabled});

  final String? name;
  final bool? enabled;
}

class MediaFolderPatch {
  const MediaFolderPatch({this.name, this.path, this.enabled});

  final String? name;
  final String? path;
  final bool? enabled;
}
