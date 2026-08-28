import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import '../common/source_lifecycle.dart';
import 'file_capabilities.dart';
import 'file_entry.dart';
import 'file_operation.dart';

abstract interface class FileSource {
  SourceDescriptor get descriptor;

  Set<FileCapability> get capabilities;

  bool supports(FileCapability capability) => capabilities.contains(capability);
}

abstract interface class FileBrowseCapability {
  Future<DirectoryListing> listDirectory(FilePath path);

  Future<FileEntry> stat(FilePath path);

  Future<bool> exists(FilePath path);

  Future<FileEntry> validatePath(FilePath path);
}

abstract interface class FileTransferCapability {
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  });

  Future<void> upload(FileUploadRequest request);
}

abstract interface class FileMutationCapability {
  Future<FilePath> createDirectory(FilePath parent, String name);

  Future<void> delete(
    FilePath path, {
    FileDeleteOptions options = const FileDeleteOptions(),
  });

  Future<void> move(
    FilePath source,
    FilePath destination, {
    bool overwrite = false,
  });

  Future<void> rename(
    FilePath source,
    String newName, {
    bool overwrite = false,
  });
}

abstract interface class FileAccessCapability {
  Future<FileAccess> resolveAccess(FilePath path);
}

class FileSourceRegistry {
  FileSourceRegistry(Iterable<FileSource> sources) {
    for (final source in sources) {
      _sources[source.descriptor.id] = source;
    }
  }

  final Map<SourceId, FileSource> _sources = <SourceId, FileSource>{};

  Iterable<FileSource> get sources => _sources.values;

  void register(FileSource source) => _sources[source.descriptor.id] = source;

  FileSource? find(SourceId id) => _sources[id];

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
