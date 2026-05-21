class ApiException implements Exception {
  ApiException(this.message, {this.status, this.requestId});

  final String message;
  final int? status;
  final String? requestId;

  @override
  String toString() => 'ApiException($status): $message';
}
