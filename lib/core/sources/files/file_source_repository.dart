import 'dart:async';

import '../common/source_exception.dart';
import '../common/source_id.dart';
import 'file_entry.dart';
import 'file_operation.dart';
import 'file_source.dart';

/// 文件源的领域门面。
///
/// 页面只依赖这个门面和 [FilePath]，不拼接 SMB/WebDAV 路径，也不接触
/// 具体协议客户端。协议不支持的能力统一抛出
/// [UnsupportedFileOperationException]。
class FileSourceRepository {
  FileSourceRepository(this.source);

  final FileSource source;

  Future<DirectoryListing> listDirectory(FilePath path, {bool refresh = false}) =>
      _browse().listDirectory(path, refresh: refresh);

  Future<FileEntry> stat(FilePath path) => _browse().stat(path);

  Future<bool> exists(FilePath path) => _browse().exists(path);

  Future<FileEntry> validatePath(FilePath path) => _browse().validatePath(path);

  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) => _transfer().download(path, options: options);

  Future<void> upload(FileUploadRequest request) => _transfer().upload(request);

  Future<FilePath> createDirectory(FilePath parent, String name) =>
      _mutation().createDirectory(parent, name);

  Future<void> delete(
    FilePath path, {
    FileDeleteOptions options = const FileDeleteOptions(),
  }) => _mutation().delete(path, options: options);

  Future<void> move(
    FilePath sourcePath,
    FilePath destination, {
    bool overwrite = false,
  }) => _mutation().move(sourcePath, destination, overwrite: overwrite);

  Future<void> rename(
    FilePath path,
    String newName, {
    bool overwrite = false,
  }) => _mutation().rename(path, newName, overwrite: overwrite);

  Future<FileAccess> resolveAccess(FilePath path) =>
      _access().resolveAccess(path);

  bool get supportsRange => source is FileRangeAccessCapability;

  Future<Stream<List<int>>> openRange(
    FilePath path, {
    required int offset,
    required int length,
    FileTransferOptions options = const FileTransferOptions(),
  }) =>
      _range().openRange(
        path,
        offset: offset,
        length: length,
        options: options,
      );

  FileBrowseCapability _browse() => _require<FileBrowseCapability>('browse');

  FileTransferCapability _transfer() =>
      _require<FileTransferCapability>('transfer');

  FileMutationCapability _mutation() =>
      _require<FileMutationCapability>('mutation');

  FileAccessCapability _access() => _require<FileAccessCapability>('access');

  FileRangeAccessCapability _range() =>
      _require<FileRangeAccessCapability>('range_access');

  T _require<T extends Object>(String capability) {
    if (source is T) return source as T;
    throw UnsupportedFileOperationException(capability);
  }
}

/// 给文件操作提供统一的生命周期、进度和取消事件。
class FileOperationTracker {
  FileOperationTracker({this.sourceId});

  final SourceId? sourceId;
  final StreamController<FileOperation> _events =
      StreamController<FileOperation>.broadcast();
  final Map<String, FileCancellationToken> _cancellations =
      <String, FileCancellationToken>{};
  final Map<String, FileOperation> _operations = <String, FileOperation>{};
  var _nextId = 0;

  Stream<FileOperation> get events => _events.stream;

  String start(
    FileOperationKind kind, {
    FilePath? source,
    FilePath? destination,
  }) {
    final id = '${sourceId?.value ?? 'file'}-${++_nextId}';
    _cancellations[id] = FileCancellationToken();
    final operation = FileOperation(
      id: id,
      kind: kind,
      status: FileOperationStatus.running,
      source: source,
      destination: destination,
    );
    _operations[id] = operation;
    _emit(operation);
    return id;
  }

  FileCancellationToken? cancellation(String id) => _cancellations[id];

  FileOperation? operation(String id) => _operations[id];

  void progress(String id, FileTransferProgress progress) {
    final current = _operations[id];
    if (current == null || current.status != FileOperationStatus.running) {
      return;
    }
    final operation = FileOperation(
      id: current.id,
      kind: current.kind,
      status: FileOperationStatus.running,
      source: current.source,
      destination: current.destination,
      progress: progress,
    );
    _operations[id] = operation;
    _emit(operation);
  }

  void complete(String id, FileOperationKind kind) {
    final current = _operations[id];
    if (current == null) return;
    final canceled = _cancellations.remove(id)?.isCancelled == true;
    final operation = FileOperation(
      id: current.id,
      kind: current.kind,
      status: canceled
          ? FileOperationStatus.canceled
          : FileOperationStatus.completed,
      source: current.source,
      destination: current.destination,
      progress: current.progress,
      message: canceled ? '操作已取消' : current.message,
    );
    _operations[id] = operation;
    _emit(operation);
  }

  void fail(String id, FileOperationKind kind, Object error) {
    final current = _operations[id];
    final token = _cancellations.remove(id);
    final canceled = token?.isCancelled == true;
    final operation = FileOperation(
      id: id,
      kind: current?.kind ?? kind,
      status: canceled
          ? FileOperationStatus.canceled
          : FileOperationStatus.failed,
      source: current?.source,
      destination: current?.destination,
      progress: current?.progress,
      message: error.toString(),
    );
    _operations[id] = operation;
    _emit(operation);
  }

  void cancel(String id) => _cancellations[id]?.cancel();

  Future<void> dispose() async {
    for (final token in _cancellations.values) {
      token.cancel();
    }
    _cancellations.clear();
    _operations.clear();
    await _events.close();
  }

  void _emit(FileOperation operation) {
    if (!_events.isClosed) _events.add(operation);
  }
}
