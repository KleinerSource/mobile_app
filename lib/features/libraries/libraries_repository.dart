import '../../core/api/envelope.dart';
import '../../core/api/services/libraries_api.dart';
import '../../core/models/library.dart';

class LibrariesRepository {
  LibrariesRepository(this._api);
  final LibrariesApi _api;

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

  Future<LibraryItem> create({required String name, bool enabled = true}) async {
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
    final raw = await _api.delete(id);
    unwrapStd<void>(raw, (_) {});
  }

  // ===== Scan =====

  /// 触发扫描。返回 taskId (后端可能返回 task_id 或直接放在 data)
  Future<String> scan(int id, {bool incremental = true}) async {
    final raw = await _api.scan(id, {'incremental': incremental});
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

  Future<List<ScanTask>> activeScans(int id) async {
    final raw = await _api.activeScans(id);
    if (raw is! Map || raw['success'] != true) return const [];
    final data = raw['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ScanTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => ScanTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<ScanTask> scanProgress(int id, String taskId) async {
    final raw = await _api.scanProgress(id, taskId);
    return unwrapStd<ScanTask>(
      raw,
      (d) => ScanTask.fromJson(Map<String, dynamic>.from(d as Map)),
    );
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
        : (data is Map && data['items'] is List ? data['items'] as List : const []);
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
    final raw = await _api.deleteDirectory(libraryId, dirId);
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
