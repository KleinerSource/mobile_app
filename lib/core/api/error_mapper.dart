import 'package:dio/dio.dart';

import 'api_exception.dart';

ApiException mapDioError(DioException e) {
  final reqId = e.response?.headers.value('x-request-id');

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return ApiException('请求超时，请稍后重试', requestId: reqId);
  }
  if (e.response == null) {
    return ApiException('网络连接失败，请检查网络连接', requestId: reqId);
  }

  final status = e.response?.statusCode;
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) {
      return ApiException(detail, status: status, requestId: reqId);
    }
    if (detail is List) {
      final parts = detail.map((item) {
        if (item is Map) {
          final msg = item['msg'] ?? item['message'];
          return msg?.toString() ?? '验证错误';
        }
        return '验证错误';
      }).toList();
      return ApiException(parts.join('; '), status: status, requestId: reqId);
    }
    if (detail is Map && detail['message'] != null) {
      return ApiException(detail['message'].toString(),
          status: status, requestId: reqId);
    }
    final msg = data['message'];
    if (msg is String && msg.isNotEmpty) {
      return ApiException(msg, status: status, requestId: reqId);
    }
  }

  return ApiException(
    'HTTP $status: ${e.response?.statusMessage ?? ''}'.trim(),
    status: status,
    requestId: reqId,
  );
}
