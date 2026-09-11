import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'envelope.dart';
import 'error_codes.dart';

ApiException mapDioError(DioException e) {
  final reqId = e.response?.headers.value('x-request-id');

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return ApiException(
      AppErrorCode.requestTimeout,
      code: AppErrorCode.requestTimeout,
      requestId: reqId,
    );
  }
  if (e.response == null) {
    return ApiException(
      AppErrorCode.networkUnavailable,
      code: AppErrorCode.networkUnavailable,
      requestId: reqId,
    );
  }

  final status = e.response?.statusCode;
  final data = _decodeJsonBody(e.response?.data);
  Map<String, Object?>? routeDetails(String message) {
    if (status != 404 || message.trim().toLowerCase() != 'not found') {
      return null;
    }
    final method = e.requestOptions.method.trim().toUpperCase();
    final uri = e.requestOptions.uri;
    final target = uri.scheme == 'http' || uri.scheme == 'https'
        ? '${uri.origin}${uri.path}'
        : uri.path;
    return {'method': method, 'target': target};
  }

  ApiException messageException(
    String message, {
    Object? responseData,
    String? code,
  }) {
    final details = routeDetails(message);
    if (details != null) {
      return ApiException(
        AppErrorCode.routeNotFound,
        code: AppErrorCode.routeNotFound,
        status: status,
        requestId: reqId,
        data: responseData,
        details: details,
      );
    }
    return ApiException(
      message,
      code: code,
      status: status,
      requestId: reqId,
      data: responseData,
    );
  }

  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) {
      return messageException(
        detail,
        responseData: data['data'],
        code: envelopeCodeOrNull(data),
      );
    }
    if (detail is List) {
      final parts = detail
          .map((item) {
            if (item is Map) {
              final msg = item['msg'] ?? item['message'];
              return msg?.toString().trim() ?? '';
            }
            return '';
          })
          .where((message) => message.isNotEmpty)
          .toList();
      if (parts.isEmpty) {
        return ApiException(
          AppErrorCode.validationFailed,
          code: AppErrorCode.validationFailed,
          status: status,
          requestId: reqId,
          data: data['data'],
        );
      }
      return ApiException(
        parts.join('; '),
        code: envelopeCodeOrNull(data),
        status: status,
        requestId: reqId,
        data: data['data'],
      );
    }
    if (detail is Map && detail['message'] != null) {
      return ApiException(
        detail['message'].toString(),
        code: envelopeCodeOrNull(data),
        status: status,
        requestId: reqId,
        data: data['data'],
      );
    }
    final msg = envelopeMessageOrNull(data);
    if (msg != null) {
      return messageException(
        msg,
        responseData: data['data'],
        code: envelopeCodeOrNull(data),
      );
    }
  }

  return ApiException(
    AppErrorCode.httpError,
    code: AppErrorCode.httpError,
    status: status,
    requestId: reqId,
    data: data is Map ? data['data'] : null,
    details: {'statusMessage': e.response?.statusMessage ?? ''},
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
