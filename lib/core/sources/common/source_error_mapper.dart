import '../../api/dio_factory.dart';
import 'source_exception.dart';

/// Maps existing HTTP/API errors at the adapter boundary without coupling the
/// protocol-neutral Source models to the API client implementation.
SourceException mapSourceError(Object error, {required String fallback}) {
  if (error is SourceException) return error;
  final apiError = toApiException(error);
  final message = apiError.message.trim();
  return SourceException(
    message.isEmpty ? fallback : message,
    statusCode: apiError.status,
    cause: error,
  );
}
