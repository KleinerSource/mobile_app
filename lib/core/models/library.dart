import 'package:freezed_annotation/freezed_annotation.dart';

part 'library.freezed.dart';
part 'library.g.dart';

@freezed
abstract class LibraryItem with _$LibraryItem {
  const factory LibraryItem({
    required int id,
    required String name,
    String? description,
    @Default(true) bool enabled,
    @JsonKey(name: 'file_count') @Default(0) int fileCount,

    /// 封面图 (JPEG base64, with_cover=true 时后端内联返回)
    @JsonKey(name: 'cover_image_base64') String? coverImageBase64,
    @Default(<DirectoryItem>[]) List<DirectoryItem> directories,
  }) = _LibraryItem;

  factory LibraryItem.fromJson(Map<String, dynamic> json) =>
      _$LibraryItemFromJson(json);
}

@freezed
abstract class DirectoryItem with _$DirectoryItem {
  const factory DirectoryItem({
    required int id,
    String? name,
    required String path,
    @Default(true) bool enabled,
    @JsonKey(name: 'library_id') int? libraryId,
    @JsonKey(name: 'file_count') @Default(0) int fileCount,
  }) = _DirectoryItem;

  factory DirectoryItem.fromJson(Map<String, dynamic> json) =>
      _$DirectoryItemFromJson(json);
}

@freezed
abstract class ScanTask with _$ScanTask {
  const factory ScanTask({
    @JsonKey(name: 'task_id') required String taskId,
    @JsonKey(name: 'library_id') int? libraryId,
    @Default('pending') String status,
    @Default(false) bool incremental,
    @JsonKey(name: 'total_files') int? totalFiles,
    @JsonKey(name: 'processed_files') int? processedFiles,
    @JsonKey(name: 'added_files') @Default(0) int addedFiles,
    @JsonKey(name: 'updated_files') @Default(0) int updatedFiles,
    @JsonKey(name: 'removed_files') @Default(0) int removedFiles,
    @JsonKey(name: 'current_file') String? currentFile,
    String? message,
    @JsonKey(name: 'started_at') String? startedAt,
    @JsonKey(name: 'finished_at') String? finishedAt,
  }) = _ScanTask;

  factory ScanTask.fromJson(Map<String, dynamic> json) =>
      _$ScanTaskFromJson(json);
}

extension ScanTaskX on ScanTask {
  double get progressRatio {
    final t = totalFiles ?? 0;
    final p = processedFiles ?? 0;
    if (t <= 0) return 0;
    return (p / t).clamp(0.0, 1.0);
  }

  bool get isActive =>
      status == 'pending' ||
      status == 'queued' ||
      status == 'running' ||
      status == 'paused';

  bool get isPaused => status == 'paused';
}
