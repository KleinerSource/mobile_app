import 'package:flutter/foundation.dart';

import 'file_entry.dart';

enum FileOperationKind {
  createDirectory,
  upload,
  download,
  delete,
  move,
  rename,
  resolveAccess,
}

enum FileOperationStatus { pending, running, completed, canceled, failed }

@immutable
class FileOperation {
  const FileOperation({
    required this.id,
    required this.kind,
    required this.status,
    this.source,
    this.destination,
    this.progress,
    this.message,
  });

  final String id;
  final FileOperationKind kind;
  final FileOperationStatus status;
  final FilePath? source;
  final FilePath? destination;
  final FileTransferProgress? progress;
  final String? message;
}

class FileDeleteOptions {
  const FileDeleteOptions({this.recursive = false});

  final bool recursive;
}

class FileUploadRequest {
  const FileUploadRequest({
    required this.destination,
    required this.data,
    required this.length,
    this.options = const FileTransferOptions(),
  });

  final FilePath destination;
  final Stream<List<int>> data;
  final int length;
  final FileTransferOptions options;
}
