import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import '../config/server_config.dart';
import 'api_exception.dart';
import 'error_mapper.dart';

Dio buildDio(ServerConfig config) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBase,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(InterceptorsWrapper(
    onResponse: (resp, handler) {
      final data = resp.data;
      if (data is Map && data['success'] == false) {
        handler.reject(
          DioException(
            requestOptions: resp.requestOptions,
            response: resp,
            type: DioExceptionType.badResponse,
            error: ApiException(
              (data['message'] as String?) ?? '操作失败',
              status: resp.statusCode,
            ),
          ),
        );
        return;
      }
      handler.next(resp);
    },
    onError: (e, handler) {
      if (e.error is ApiException) {
        handler.next(e);
        return;
      }
      final mapped = mapDioError(e);
      handler.next(DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: mapped,
      ));
    },
  ));

  dio.interceptors.add(RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 800),
      Duration(seconds: 2),
    ],
    retryEvaluator: (error, attempt) {
      final method = error.requestOptions.method.toUpperCase();
      if (method != 'GET') return false;
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }
      return false;
    },
  ));

  return dio;
}

ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    if (error.error is ApiException) return error.error as ApiException;
    return mapDioError(error);
  }
  return ApiException(error.toString());
}
