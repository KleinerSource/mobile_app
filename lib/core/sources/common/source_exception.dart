import '../../api/error_codes.dart';

class SourceException implements Exception {
  const SourceException(
    this.message, {
    this.code,
    this.statusCode,
    this.cause,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;
  final Map<String, Object?>? details;

  @override
  String toString() {
    final suffix = code == null ? '' : ' [$code]';
    return 'SourceException$suffix: $message';
  }
}

class UnsupportedSourceCapabilityException extends SourceException {
  const UnsupportedSourceCapabilityException(String capability)
    : super(
        AppErrorCode.unsupportedSourceCapability,
        code: AppErrorCode.unsupportedSourceCapability,
      );
}

class FileSourceException extends SourceException {
  const FileSourceException(
    super.message, {
    super.code,
    super.statusCode,
    super.cause,
    super.details,
  });
}

class UnsupportedFileOperationException extends FileSourceException {
  const UnsupportedFileOperationException(String operation)
    : super(
        AppErrorCode.unsupportedSourceCapability,
        code: AppErrorCode.unsupportedSourceCapability,
      );
}
