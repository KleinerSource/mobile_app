import '../../core/api/envelope.dart';
import '../../core/api/services/libraries_api.dart';
import '../../core/api/services/libraries_extended_api.dart';
import '../../core/models/library.dart';

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

class LibrariesRepository {
  LibrariesRepository(this._api, this._extendedApi);
  final LibrariesApi _api;
  final LibrariesExtendedApi _extendedApi;

  // ===== List =====

  Future<List<LibraryItem>> list({
    bool enabledOnly = false,
    bool withCover = true,
  }) async {
    final raw = await _api.list({
      'enabled_only': enabledOnly,
      'with_cover': withCover,
    });
    if (raw is! Map || raw['success'] != true) return const [];
    final data = raw['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<LibraryItem> detail(int id) async {
    final raw = await _api.detail(id);
    return unwrapStd<LibraryItem>(
      raw,
      (d) => LibraryItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  // ===== Create / Update / Delete =====

  Future<LibraryItem> create({
    required String name,
    bool enabled = true,
  }) async {
    final raw = await _api.create({'name': name, 'enabled': enabled});
    return unwrapStd<LibraryItem>(
      raw,
      (d) => LibraryItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<LibraryItem> update(int id, {String? name, bool? enabled}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (enabled != null) body['enabled'] = enabled;
    final raw = await _api.update(id, body);
    return unwrapStd<LibraryItem>(
      raw,
      (d) => LibraryItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<void> delete(int id) async {
    final raw = await _api.delete({
      'libraries_ids': [id],
    });
    unwrapStd<void>(raw, (_) {});
  }

  // ===== Scan =====

  /// 触发扫描。返回 taskId (后端可能返回 task_id 或直接放在 data)
  Future<String> scan(int id, {bool incremental = true}) async {
    final raw = await _api.scan(id, {'incremental': incremental});
    if (raw is Map && raw['success'] == true && raw['task_id'] != null) {
      return raw['task_id'].toString();
    }
    return unwrapStd<String>(raw, (d) {
      if (d == null) return '';
      if (d is Map) {
        final tid = d['task_id'] ?? d['id'] ?? d['taskId'];
        return tid?.toString() ?? '';
      }
      // data 直接是字符串 / 数字
      return d.toString();
    });
  }

  Future<BatchLibraryScanResult> batchScan({required bool incremental}) async {
    final raw = await _extendedApi.batchScan({'incremental': incremental});
    final message = raw is Map ? (raw['message'] ?? '').toString() : '';
    final data = unwrapStd<Map<String, dynamic>>(
      raw,
      (value) =>
          value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
    );
    final tasks = <BatchLibraryScanTask>[];
    final rawTasks = data['tasks'];
    if (rawTasks is List) {
      for (final rawTask in rawTasks.whereType<Map>()) {
        final task = Map<String, dynamic>.from(rawTask);
        final libraryId = _asInt(task['library_id']);
        final taskId = (task['task_id'] ?? '').toString();
        if (libraryId <= 0 || taskId.isEmpty) continue;
        tasks.add((
          libraryId: libraryId,
          libraryName: (task['library_name'] ?? '媒体库 $libraryId').toString(),
          taskId: taskId,
          status: (task['status'] ?? 'queued').toString(),
          queuePosition: _asInt(task['queue_position']),
          reused: task['reused'] == true,
        ));
      }
    }
    return (
      message: message,
      scanType: (data['scan_type'] ?? (incremental ? '增量扫描' : '全量扫描'))
          .toString(),
      enabledCount: _asInt(data['enabled_count']),
      acceptedCount: _asInt(data['accepted_count']),
      reusedCount: _asInt(data['reused_count']),
      failedCount: _asInt(data['failed_count']),
      skippedDisabledCount: _asInt(data['skipped_disabled_count']),
      tasks: tasks,
    );
  }

  Future<List<ScanTask>> activeScans(int id) async {
    final raw = await _api.activeScans(id);
    if (raw is! Map || raw['success'] != true) return const [];
    final data = raw['data'];
    final items = data is List
        ? data
        : data is Map && data['active_scans'] is List
        ? data['active_scans'] as List
        : data is Map && data['items'] is List
        ? data['items'] as List
        : const [];
    return items.whereType<Map>().map(_decodeScanTask).toList();
  }

  Future<ScanTask> scanProgress(int id, String taskId) async {
    final raw = await _api.scanProgress(id, taskId);
    return unwrapStd<ScanTask>(raw, (d) => _decodeScanTask(d as Map));
  }

  ScanTask _decodeScanTask(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    json['current_file'] ??= json['current_file_path'];
    json['added_files'] ??= json['new_movies'];
    json['updated_files'] ??= json['updated_movies'];
    json['removed_files'] ??= json['deleted_movies'];
    json['started_at'] ??= json['start_time'];
    json['finished_at'] ??= json['end_time'];
    return ScanTask.fromJson(json);
  }

  Future<void> pauseScan(int id, String taskId) async {
    final raw = await _api.pauseScan(id, taskId);
    unwrapStd<void>(raw, (_) {});
  }

  Future<void> resumeScan(int id, String taskId) async {
    final raw = await _api.resumeScan(id, taskId);
    unwrapStd<void>(raw, (_) {});
  }

  Future<void> cancelScan(int id, String taskId) async {
    final raw = await _api.cancelScan(id, taskId);
    unwrapStd<void>(raw, (_) {});
  }

  // ===== Directories =====

  Future<List<DirectoryItem>> listDirectories(int libraryId) async {
    final raw = await _api.listDirectories(libraryId);
    if (raw is! Map || raw['success'] != true) return const [];
    final data = raw['data'];
    final list = data is List
        ? data
        : (data is Map && data['items'] is List
              ? data['items'] as List
              : const []);
    return list
        .whereType<Map>()
        .map((e) => DirectoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DirectoryItem> createDirectory(
    int libraryId, {
    required String path,
    String? name,
    bool enabled = true,
  }) async {
    final raw = await _api.createDirectory(libraryId, {
      'path': path,
      'name': name ?? path,
      'enabled': enabled,
    });
    return unwrapStd<DirectoryItem>(
      raw,
      (d) => DirectoryItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<DirectoryItem> updateDirectory(
    int libraryId,
    int dirId, {
    String? path,
    String? name,
    bool? enabled,
  }) async {
    final body = <String, dynamic>{};
    if (path != null) body['path'] = path;
    if (name != null) body['name'] = name;
    if (enabled != null) body['enabled'] = enabled;
    final raw = await _api.updateDirectory(libraryId, dirId, body);
    return unwrapStd<DirectoryItem>(
      raw,
      (d) => DirectoryItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<void> deleteDirectory(int libraryId, int dirId) async {
    final raw = await _api.deleteDirectory(libraryId, {
      'directories_ids': [dirId],
    });
    unwrapStd<void>(raw, (_) {});
  }

  // ===== Tools =====

  /// 验证路径 · 返回 { exists, is_directory, is_duplicate, error? }
  Future<Map<String, dynamic>> validatePath(
    String path, {
    int? directoryId,
  }) async {
    final body = <String, dynamic>{'path': path};
    if (directoryId != null) body['directory_id'] = directoryId;
    final raw = await _api.validatePath(body);
    return unwrapStd<Map<String, dynamic>>(raw, (d) {
      if (d is Map) return Map<String, dynamic>.from(d);
      return const {};
    });
  }
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
