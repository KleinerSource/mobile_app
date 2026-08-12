import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import '../auth/auth_session.dart';
import '../auth/auth_session_repository.dart';
import '../config/server_config.dart';
import 'api_exception.dart';
import 'envelope.dart';
import 'error_mapper.dart';

Dio buildDio(
  ServerConfig config, {
  AuthSessionRepository? sessionRepository,
  void Function()? onSessionExpired,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration sendTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(seconds: 30),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBase,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: const {
        'Content-Type': 'application/json',
        // 标识移动客户端来源，便于服务端区分 App 登录与 Web 登录（登录日志）。
        'X-Client-Type': 'app',
      },
      responseType: ResponseType.json,
    ),
  );

  Future<bool>? refreshInFlight;

  Future<bool> refreshAccessToken() async {
    final repository = sessionRepository;
    if (repository == null) return false;
    final current = await repository.current();
    if (current == null || current.refreshToken.isEmpty) return false;

    final refreshRequest = dio.post<dynamic>(
      '/auth/refresh',
      options: Options(
        extra: const {'skipAuth': true, 'skipRefresh': true},
        headers: {'Authorization': 'Bearer ${current.refreshToken}'},
      ),
    );
    final response = await refreshRequest;
    final session = unwrapStd<AuthSession>(
      response.data,
      (data) => AuthSession.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    if (!session.isUsable) {
      await repository.clear();
      return false;
    }
    await repository.save(session);
    return true;
  }

  Future<bool> refreshOnce() {
    final existing = refreshInFlight;
    if (existing != null) return existing;
    final future = refreshAccessToken().catchError((_) => false);
    refreshInFlight = future;
    return future.whenComplete(() {
      refreshInFlight = null;
    });
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (options.extra['skipAuth'] != true && sessionRepository != null) {
        final token = await sessionRepository.accessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    },
    onResponse: (resp, handler) {
      final data = _decodeBusinessData(resp);
      if (data is Map && data['success'] == false) {
        handler.reject(
          DioException(
            requestOptions: resp.requestOptions,
            response: resp,
            type: DioExceptionType.badResponse,
            error: ApiException(
              (data['message'] as String?) ?? '操作失败',
              status: resp.statusCode,
              data: data['data'],
              requestId: resp.headers.value('x-request-id'),
            ),
          ),
        );
        return;
      }
      handler.next(resp);
    },
    onError: (error, handler) async {
      final options = error.requestOptions;
      final status = error.response?.statusCode ??
          (error.error is ApiException
              ? (error.error as ApiException).status
              : null);
      final canRefresh = sessionRepository != null &&
          status == 401 &&
          options.extra['skipRefresh'] != true &&
          options.extra['authRetried'] != true &&
          !_isAuthPath(options.path);

      if (canRefresh && await refreshOnce()) {
        options.extra['authRetried'] = true;
        final token = await sessionRepository.accessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        try {
          final response = await dio.fetch<dynamic>(options);
          handler.resolve(response);
          return;
        } on DioException catch (retryError) {
          handler.next(_withMappedError(retryError));
          return;
        }
      }

      if (status == 401 &&
          sessionRepository != null &&
          !_isAuthPath(options.path)) {
        await sessionRepository.clear();
        onSessionExpired?.call();
      }
      handler.next(_withMappedError(error));
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
      if (error.requestOptions.extra['skipRetry'] == true) return false;
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
    },
  ));

  return dio;
}

Object? _decodeBusinessData(Response<dynamic> response) {
  final data = response.data;
  if (data is! List<int>) return data;
  final contentType =
      response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
  if (!contentType.contains('json')) return data;
  try {
    return jsonDecode(utf8.decode(data));
  } catch (_) {
    return data;
  }
}

bool _isAuthPath(String path) {
  final normalized = path.toLowerCase();
  return normalized.contains('/auth/login') ||
      normalized.contains('/auth/refresh') ||
      normalized.contains('/auth/status') ||
      normalized.contains('/auth/verify');
}

DioException _withMappedError(DioException error) {
  if (error.error is ApiException) return error;
  return DioException(
    requestOptions: error.requestOptions,
    response: error.response,
    type: error.type,
    error: mapDioError(error),
  );
}

ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    if (error.error is ApiException) return error.error as ApiException;
    return mapDioError(error);
  }
  return ApiException(error.toString());
}
