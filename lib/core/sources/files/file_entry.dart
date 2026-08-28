import 'dart:async';

import 'package:flutter/foundation.dart';

import '../common/source_id.dart';

enum FileEntryType { file, directory, link }

@immutable
class FilePath {
  const FilePath({required this.sourceId, required this.value});

  final SourceId sourceId;
  final String value;

  String get stableKey => '${sourceId.value}:$value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilePath && other.sourceId == sourceId && other.value == value;

  @override
  int get hashCode => Object.hash(sourceId, value);
}

@immutable
class FileEntry {
  const FileEntry({
    required this.path,
    required this.name,
    required this.type,
    this.size,
    this.modifiedAt,
    this.createdAt,
    this.mimeType,
    this.isHidden = false,
    this.attributes = const <String, Object?>{},
  });

  final FilePath path;
  final String name;
  final FileEntryType type;
  final int? size;
  final DateTime? modifiedAt;
  final DateTime? createdAt;
  final String? mimeType;
  final bool isHidden;
  final Map<String, Object?> attributes;

  String get stableKey => path.stableKey;

  bool get isDirectory => type == FileEntryType.directory;

  bool get isFile => type == FileEntryType.file;
}

@immutable
class DirectoryListing {
  const DirectoryListing({
    required this.currentPath,
    required this.entries,
    this.parentPath,
    this.breadcrumbs = const <FilePath>[],
    this.hasMore = false,
  });

  final FilePath currentPath;
  final FilePath? parentPath;
  final List<FilePath> breadcrumbs;
  final List<FileEntry> entries;
  final bool hasMore;
}

@immutable
class FileAccess {
  const FileAccess({
    this.uri,
    this.openStream,
    this.size,
    this.mimeType,
    this.headers = const <String, String>{},
  }) : assert(uri != null || openStream != null);

  final Uri? uri;
  final Stream<List<int>> Function()? openStream;
  final int? size;
  final String? mimeType;
  final Map<String, String> headers;

  Future<Stream<List<int>>> open() async {
    final streamFactory = openStream;
    if (streamFactory == null) {
      throw StateError('文件访问句柄不包含可读取的流');
    }
    return streamFactory();
  }
}

typedef FileProgressCallback = void Function(FileTransferProgress progress);

@immutable
class FileTransferProgress {
  const FileTransferProgress({required this.transferred, this.total});

  final int transferred;
  final int? total;

  double? get ratio {
    final totalBytes = total;
    if (totalBytes == null || totalBytes <= 0) return null;
    return (transferred / totalBytes).clamp(0.0, 1.0);
  }
}

/// Protocol-neutral cancellation token for long-running file operations.
class FileCancellationToken {
  final Completer<Object?> _completer = Completer<Object?>();

  bool get isCancelled => _completer.isCompleted;

  Future<Object?> get whenCancelled => _completer.future;

  void cancel([Object? reason]) {
    if (!_completer.isCompleted) _completer.complete(reason);
  }
}

@immutable
class FileTransferOptions {
  const FileTransferOptions({
    this.overwrite = false,
    this.onProgress,
    this.cancellation,
  });

  final bool overwrite;
  final FileProgressCallback? onProgress;
  final FileCancellationToken? cancellation;
}

String normalizeRelativeFilePath(String value) {
  final raw = value.trim().replaceAll('\\', '/');
  final parts = <String>[];
  for (final part in raw.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isEmpty) {
        throw ArgumentError.value(value, 'value', '路径不能越过来源根目录');
      }
      parts.removeLast();
      continue;
    }
    parts.add(part);
  }
  var path = parts.join('/');
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  while (path.contains('//')) {
    path = path.replaceAll('//', '/');
  }
  if (path == '.') return '';
  if (path.endsWith('/') && path.isNotEmpty) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

String normalizeFileName(String value) {
  final name = value.trim().replaceAll('\\', '/');
  if (name.isEmpty || name == '.' || name == '..' || name.contains('/')) {
    throw ArgumentError.value(value, 'value', '文件名必须是单个路径片段');
  }
  return name;
}

String normalizeWebDavPath(String value) {
  final relative = normalizeRelativeFilePath(value);
  return relative.isEmpty ? '/' : '/$relative';
}

String joinRelativeFilePath(String parent, String child) {
  final normalizedParent = normalizeRelativeFilePath(parent);
  final normalizedChild = normalizeFileName(child);
  if (normalizedParent.isEmpty) return normalizedChild;
  if (normalizedChild.isEmpty) return normalizedParent;
  return '$normalizedParent/$normalizedChild';
}

String joinWebDavPath(String parent, String child) {
  return normalizeWebDavPath('$parent/${normalizeFileName(child)}');
}

List<FilePath> buildBreadcrumbs(FilePath path, {required bool webDav}) {
  final normalized = webDav
      ? normalizeWebDavPath(path.value)
      : normalizeRelativeFilePath(path.value);
  if (webDav) {
    if (normalized == '/') {
      return [FilePath(sourceId: path.sourceId, value: '/')];
    }
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    var current = '';
    return [
      FilePath(sourceId: path.sourceId, value: '/'),
      for (final part in parts)
        FilePath(
          sourceId: path.sourceId,
          value: current = joinWebDavPath(current, part),
        ),
    ];
  }
  if (normalized.isEmpty) return [FilePath(sourceId: path.sourceId, value: '')];
  final parts = normalized.split('/');
  var current = '';
  return [
    FilePath(sourceId: path.sourceId, value: ''),
    for (final part in parts)
      FilePath(
        sourceId: path.sourceId,
        value: current = joinRelativeFilePath(current, part),
      ),
  ];
}
