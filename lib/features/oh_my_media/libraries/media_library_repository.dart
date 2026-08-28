import 'package:omm/core/models/library.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/media_source.dart';

typedef BatchLibraryScanTask = ({
  int libraryId,
  String libraryName,
  String taskId,
  String status,
  int queuePosition,
  bool reused,
});

typedef BatchLibraryScanResult = ({
  String message,
  String scanType,
  int enabledCount,
  int acceptedCount,
  int reusedCount,
  int failedCount,
  int skippedDisabledCount,
  List<BatchLibraryScanTask> tasks,
});

/// 面向现有 OMM 页面模型的 Source 门面。
///
/// 页面仍使用 [LibraryItem] 以保持 UI 行为，但所有媒体库和扫描请求都
/// 通过能力接口完成，不再直接依赖 OMM API Service。
class MediaLibraryRepository {
  MediaLibraryRepository({
    required LibraryManagementSource management,
    required ScanSource scanning,
    required BatchScanSource batchScanning,
  }) : _management = management,
       _scanning = scanning,
       _batchScanning = batchScanning;

  static const _ommSourceId = SourceId('omm');

  final LibraryManagementSource _management;
  final ScanSource _scanning;
  final BatchScanSource _batchScanning;

  Future<List<LibraryItem>> list({
    bool enabledOnly = false,
    bool withCover = true,
  }) async {
    final libraries = await _management.listLibraries(
      enabledOnly: enabledOnly,
      withCover: withCover,
    );
    return libraries.map(_toLibraryItem).toList(growable: false);
  }

  Future<LibraryItem> detail(int id) async {
    final libraryRef = _ommRef(id);
    final library = await _management.getLibrary(libraryRef);
    final folders = library.folders.isNotEmpty
        ? library.folders
        : await _management.listFolders(libraryRef);
    return _toLibraryItem(library, folders: folders);
  }

  Future<LibraryItem> create({
    required String name,
    bool enabled = true,
  }) async {
    return _toLibraryItem(
      await _management.createLibrary(name: name, enabled: enabled),
    );
  }

  Future<LibraryItem> update(int id, {String? name, bool? enabled}) async {
    return _toLibraryItem(
      await _management.updateLibrary(
        _ommRef(id),
        source_models.MediaLibraryPatch(name: name, enabled: enabled),
      ),
    );
  }

  Future<void> delete(int id) => _management.deleteLibrary(_ommRef(id));

  Future<String> scan(int id, {bool incremental = true}) async {
    final task = await _scanning.startScan(
      _ommRef(id),
      incremental: incremental,
    );
    return task.id;
  }

  Future<BatchLibraryScanResult> batchScan({required bool incremental}) async {
    final result = await _batchScanning.startBatchScan(
      incremental: incremental,
    );
    return (
      message: result.message,
      scanType: result.scanType,
      enabledCount: result.enabledCount,
      acceptedCount: result.acceptedCount,
      reusedCount: result.reusedCount,
      failedCount: result.failedCount,
      skippedDisabledCount: result.skippedDisabledCount,
      tasks: result.tasks
          .map(
            (task) => (
              libraryId: task.libraryId,
              libraryName: task.libraryName,
              taskId: task.taskId,
              status: task.status,
              queuePosition: task.queuePosition,
              reused: task.reused,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<ScanTask>> activeScans(int id) async {
    final tasks = await _scanning.activeScans(_ommRef(id));
    return tasks.map(_toScanTask).toList(growable: false);
  }

  Future<ScanTask> scanProgress(int id, String taskId) async {
    return _toScanTask(await _scanning.scanProgress(_ommRef(id), taskId));
  }

  Future<void> pauseScan(int id, String taskId) =>
      _scanning.pauseScan(_ommRef(id), taskId);

  Future<void> resumeScan(int id, String taskId) =>
      _scanning.resumeScan(_ommRef(id), taskId);

  Future<void> cancelScan(int id, String taskId) =>
      _scanning.cancelScan(_ommRef(id), taskId);

  Future<List<DirectoryItem>> listDirectories(int libraryId) async {
    final folders = await _management.listFolders(_ommRef(libraryId));
    return folders
        .map((folder) => _toDirectoryItem(folder, libraryId: libraryId))
        .toList(growable: false);
  }

  Future<DirectoryItem> createDirectory(
    int libraryId, {
    required String path,
    String? name,
    bool enabled = true,
  }) async {
    final folder = await _management.createFolder(
      _ommRef(libraryId),
      path: path,
      name: name,
      enabled: enabled,
    );
    return _toDirectoryItem(folder, libraryId: libraryId);
  }

  Future<DirectoryItem> updateDirectory(
    int libraryId,
    int dirId, {
    String? path,
    String? name,
    bool? enabled,
  }) async {
    final folder = await _management.updateFolder(
      _ommRef(libraryId),
      _ommRef(dirId),
      source_models.MediaFolderPatch(path: path, name: name, enabled: enabled),
    );
    return _toDirectoryItem(folder, libraryId: libraryId);
  }

  Future<void> deleteDirectory(int libraryId, int dirId) =>
      _management.deleteFolder(_ommRef(libraryId), _ommRef(dirId));

  Future<Map<String, dynamic>> validatePath(
    String path, {
    int? directoryId,
  }) async {
    final result = await _management.validatePath(
      path,
      folder: directoryId == null ? null : _ommRef(directoryId),
    );
    return {
      'exists': result.exists,
      'is_directory': result.isDirectory,
      'is_duplicate': result.isDuplicate,
      if (result.error != null) 'error': result.error,
    };
  }

  source_models.MediaRef _ommRef(int id) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', '媒体库 ID 必须为正数');
    }
    return source_models.MediaRef(sourceId: _ommSourceId, value: '$id');
  }

  LibraryItem _toLibraryItem(
    source_models.MediaLibrary library, {
    List<source_models.MediaLibraryFolder>? folders,
  }) {
    final id = int.tryParse(library.ref.value);
    if (id == null || id <= 0) {
      throw StateError('Source 返回了无效的 OMM 媒体库 ID：${library.ref.value}');
    }
    final selectedFolders = folders ?? library.folders;
    return LibraryItem(
      id: id,
      name: library.name,
      description: library.description,
      enabled: library.enabled,
      fileCount: library.fileCount,
      coverImageBase64: library.attributes['cover_image_base64']?.toString(),
      directories: selectedFolders
          .map((folder) => _toDirectoryItem(folder, libraryId: id))
          .toList(growable: false),
    );
  }

  DirectoryItem _toDirectoryItem(
    source_models.MediaLibraryFolder folder, {
    required int libraryId,
  }) {
    final id = int.tryParse(folder.ref.value);
    if (id == null || id <= 0) {
      throw StateError('Source 返回了无效的 OMM 目录 ID：${folder.ref.value}');
    }
    return DirectoryItem(
      id: id,
      name: folder.name,
      path: folder.path,
      enabled: folder.enabled,
      libraryId: libraryId,
      fileCount: folder.fileCount,
    );
  }

  ScanTask _toScanTask(source_models.ScanJob task) => ScanTask(
    taskId: task.id,
    libraryId: task.library == null ? null : int.tryParse(task.library!.value),
    status: switch (task.status) {
      source_models.ScanJobStatus.queued => 'queued',
      source_models.ScanJobStatus.running => 'running',
      source_models.ScanJobStatus.paused => 'paused',
      source_models.ScanJobStatus.completed => 'completed',
      source_models.ScanJobStatus.failed => 'failed',
      source_models.ScanJobStatus.canceled => 'canceled',
      source_models.ScanJobStatus.unknown => 'unknown',
    },
    totalFiles: task.totalFiles,
    processedFiles: task.processedFiles,
    addedFiles: task.addedFiles,
    updatedFiles: task.updatedFiles,
    removedFiles: task.removedFiles,
    currentFile: task.currentFile,
    message: task.message,
  );
}
