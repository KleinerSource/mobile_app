class SourceException implements Exception {
  const SourceException(this.message, {this.code, this.statusCode, this.cause});

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final suffix = code == null ? '' : ' [$code]';
    return 'SourceException$suffix: $message';
  }
}

class UnsupportedSourceCapabilityException extends SourceException {
  const UnsupportedSourceCapabilityException(String capability)
    : super('来源不支持能力：$capability', code: 'unsupported_capability');
}

class FileSourceException extends SourceException {
  const FileSourceException(
    super.message, {
    super.code,
    super.statusCode,
    super.cause,
  });
}

class UnsupportedFileOperationException extends FileSourceException {
  const UnsupportedFileOperationException(String operation)
    : super('文件来源不支持操作：$operation', code: 'unsupported_operation');
}
