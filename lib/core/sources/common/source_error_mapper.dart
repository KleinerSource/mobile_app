import '../../api/dio_factory.dart';
import '../../api/error_codes.dart';
import 'source_exception.dart';

/// Maps existing HTTP/API errors at the adapter boundary without coupling the
/// protocol-neutral Source models to the API client implementation.
SourceException mapSourceError(
  Object error, {
  String? fallback,
  String? fallbackCode,
}) {
  if (error is SourceException) return error;
  final apiError = toApiException(error);
  final message = apiError.message.trim();
  return SourceException(
    message.isEmpty
        ? (fallback ?? fallbackCode ?? AppErrorCode.operationFailed)
        : message,
    code: apiError.code ?? (message.isEmpty ? fallbackCode : null),
    statusCode: apiError.status,
    cause: error,
    details: apiError.details,
  );
}

/// Returns a user-facing message without exposing the SourceException prefix.
String sourceErrorMessage(
  Object error, {
  String fallback = AppErrorCode.operationFailed,
}) => mapSourceError(error, fallback: fallback).message;
