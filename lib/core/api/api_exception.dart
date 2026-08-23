class ApiException implements Exception {
  ApiException(String message, {this.status, this.requestId, this.data})
    : message = redactSensitiveText(message);

  final String message;
  final int? status;
  final String? requestId;
  final Object? data;

  @override
  String toString() => 'ApiException($status): $message';
}

final _sensitiveQueryPattern = RegExp(
  r'((?:access_token|refresh_token|token|authorization|password|api_key|apikey|secret)=)[^&\s]+',
  caseSensitive: false,
);
final _bearerPattern = RegExp(r'(Bearer\s+)[^\s,;)]*', caseSensitive: false);

String redactSensitiveText(String value) {
  return value
      .replaceAllMapped(_sensitiveQueryPattern, (match) => '${match[1]}***')
      .replaceAllMapped(_bearerPattern, (match) => '${match[1]}***');
}
