import 'dart:convert';

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
  final data = _decodeJsonBody(e.response?.data);
  String withRouteContext(String message) {
    if (status != 404 || message.trim().toLowerCase() != 'not found') {
      return message;
    }
    final method = e.requestOptions.method.trim().toUpperCase();
    final uri = e.requestOptions.uri;
    final target = uri.scheme == 'http' || uri.scheme == 'https'
        ? '${uri.origin}${uri.path}'
        : uri.path;
    return '接口不存在（$method $target）';
  }

  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) {
      return ApiException(
        withRouteContext(detail),
        status: status,
        requestId: reqId,
        data: data['data'],
      );
    }
    if (detail is List) {
      final parts = detail.map((item) {
        if (item is Map) {
          final msg = item['msg'] ?? item['message'];
          return msg?.toString() ?? '验证错误';
        }
        return '验证错误';
      }).toList();
      return ApiException(
        parts.join('; '),
        status: status,
        requestId: reqId,
        data: data['data'],
      );
    }
    if (detail is Map && detail['message'] != null) {
      return ApiException(
        detail['message'].toString(),
        status: status,
        requestId: reqId,
        data: data['data'],
      );
    }
    final msg = data['message'] ?? data['error'];
    if (msg is String && msg.isNotEmpty) {
      return ApiException(
        withRouteContext(msg),
        status: status,
        requestId: reqId,
        data: data['data'],
      );
    }
  }

  return ApiException(
    'HTTP $status: ${e.response?.statusMessage ?? ''}'.trim(),
    status: status,
    requestId: reqId,
    data: data is Map ? data['data'] : null,
  );
}

Object? _decodeJsonBody(Object? body) {
  if (body is List<int>) {
    try {
      return jsonDecode(utf8.decode(body));
    } catch (_) {
      return body;
    }
  }
  return body;
}
