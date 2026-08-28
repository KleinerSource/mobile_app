import '../common/source_descriptor.dart';
import '../common/source_id.dart';
import '../common/source_exception.dart';
import '../common/source_lifecycle.dart';
import 'media_capabilities.dart';
import 'media_models.dart';

abstract interface class MediaSource {
  SourceDescriptor get descriptor;

  Set<MediaCapability> get capabilities;

  bool supports(MediaCapability capability) =>
      capabilities.contains(capability);
}

abstract interface class CatalogSource {
  Future<MediaPage<MediaSummary>> listMovies(MediaQuery query);

  Future<MediaPage<MediaSummary>> searchMovies(MediaQuery query);
}

abstract interface class MovieDetailSource {
  Future<MediaDetails> getMovie(MediaRef ref);
}

abstract interface class PlaybackSource {
  Future<PlaybackDescriptor> resolvePlayback(
    MediaRef ref,
    PlaybackRequest request,
  );
}

abstract interface class ResourceSource {
  Future<List<MediaResource>> listResources(MediaRef ref, {String? category});
}

abstract interface class LibraryManagementSource {
  Future<List<MediaLibrary>> listLibraries({
    bool enabledOnly = false,
    bool withCover = false,
  });

  Future<MediaLibrary> getLibrary(MediaRef ref);

  Future<MediaLibrary> createLibrary({
    required String name,
    bool enabled = true,
  });

  Future<MediaLibrary> updateLibrary(MediaRef ref, MediaLibraryPatch patch);

  Future<void> deleteLibrary(MediaRef ref);

  Future<List<MediaLibraryFolder>> listFolders(MediaRef library);

  Future<MediaLibraryFolder> createFolder(
    MediaRef library, {
    required String path,
    String? name,
    bool enabled = true,
  });

  Future<MediaLibraryFolder> updateFolder(
    MediaRef library,
    MediaRef folder,
    MediaFolderPatch patch,
  );

  Future<void> deleteFolder(MediaRef library, MediaRef folder);

  Future<PathValidationResult> validatePath(String path, {MediaRef? folder});
}

abstract interface class ScanSource {
  Future<ScanJob> startScan(MediaRef library, {bool incremental = true});

  Future<List<ScanJob>> activeScans(MediaRef library);

  Future<ScanJob> scanProgress(MediaRef library, String jobId);

  Future<void> pauseScan(MediaRef library, String jobId);

  Future<void> resumeScan(MediaRef library, String jobId);

  Future<void> cancelScan(MediaRef library, String jobId);
}

/// OMM 的批量扫描是独立的能力，不要求其它媒体源实现。
abstract interface class BatchScanSource {
  Future<BatchScanResult> startBatchScan({required bool incremental});
}

/// Keeps source lookup and capability checks in one place.
class MediaSourceRegistry {
  MediaSourceRegistry(Iterable<MediaSource> sources) {
    for (final source in sources) {
      _sources[source.descriptor.id] = source;
    }
  }

  final Map<SourceId, MediaSource> _sources = <SourceId, MediaSource>{};

  Iterable<MediaSource> get sources => _sources.values;

  void register(MediaSource source) => _sources[source.descriptor.id] = source;

  MediaSource? find(SourceId id) => _sources[id];

  T? capability<T extends Object>(SourceId id) {
    final source = find(id);
    return source is T ? source as T : null;
  }

  T requireCapability<T extends Object>(SourceId id) {
    final source = find(id);
    if (source is T) return source as T;
    throw UnsupportedSourceCapabilityException(T.toString());
  }

  Future<void> dispose() async {
    for (final source in _sources.values) {
      if (source case final SourceLifecycle lifecycle) {
        await lifecycle.dispose();
      }
    }
  }
}
