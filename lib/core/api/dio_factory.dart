import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../auth/auth_session.dart';
import '../auth/auth_session_repository.dart';
import '../config/server_config.dart';
import 'app_request_headers.dart';
import 'feiniu_signer.dart';
import 'api_exception.dart';
import 'envelope.dart';
import 'error_codes.dart';
import 'error_mapper.dart';
import 'server_compatibility.dart';
import 'server_connection.dart';
import '../sources/common/source_exception.dart';

Dio buildDio(
  ServerConfig config, {
  AuthSessionRepository? sessionRepository,
  void Function()? onSessionExpired,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration sendTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(seconds: 30),
  ServerProject? projectOverride,
  bool Function()? isRequestActive,
}) {
  // Emby/Jellyfin 的 REST 接口挂在根路径下，没有 OMM 的 /api 网关。
  final project = projectOverride ?? config.activeServer?.project;
  final isEmbyLike =
      project == ServerProject.emby || project == ServerProject.jellyfin;
  final isFeiniu = project == ServerProject.feiniu;
  final isStash = project == ServerProject.stash;
  final dio = Dio(
    BaseOptions(
      baseUrl: isEmbyLike || isStash
          ? config.baseUrl
          : isFeiniu
          ? '${ServerConfig.normalizeForProject(config.baseUrl, ServerProject.feiniu)}/api/v1'
          : config.apiBase,
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
    if (isRequestActive?.call() == false) return false;
    final repository = sessionRepository;
    if (repository == null) return false;
    final current = await repository.current();
    if (isRequestActive?.call() == false) return false;
    if (current == null || current.refreshToken.isEmpty) return false;

    final refreshRequest = dio.post<dynamic>(
      '/auth/refresh',
      options: Options(
        extra: const {'skipAuth': true, 'skipRefresh': true},
        headers: {'Authorization': 'Bearer ${current.refreshToken}'},
      ),
    );
    final response = await refreshRequest;
    if (isRequestActive?.call() == false) return false;
    final session = unwrapStd<AuthSession>(
      response.data,
      (data) => AuthSession.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    if (!session.isUsable) {
      if (isRequestActive?.call() != false) await repository.clear();
      return false;
    }
    if (isRequestActive?.call() == false) return false;
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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (isRequestActive?.call() == false) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: const ServerConnectionClosedException(),
            ),
          );
          return;
        }
        AuthSession? session;
        if (options.extra['skipAuth'] != true && sessionRepository != null) {
          session = await sessionRepository.current();
          if (isRequestActive?.call() == false) {
            handler.reject(_connectionClosedError(options));
            return;
          }
          final token = session?.accessToken;
          if (token != null && token.isNotEmpty) {
            if (isFeiniu) {
              options.headers['Authorization'] = token;
              final cookie = session?.cookie;
              if (cookie != null && cookie.isNotEmpty) {
                options.headers['Cookie'] = cookie;
              }
              options.headers['X-Trim-Client'] = 'web';
              options.headers['X-Trim-Client-Version'] = '616';
            } else if (project == ServerProject.jellyfin) {
              // Jellyfin 使用标准 Authorization 头携带 MediaBrowser 令牌；
              // 旧版 X-Emby-Token 头自 Jellyfin 12 起默认禁用。
              options.headers['Authorization'] = 'MediaBrowser Token="$token"';
            } else if (project == ServerProject.emby) {
              // Emby 不识别 Bearer 令牌，改用其原生的令牌头。
              options.headers['X-Emby-Token'] = token;
            } else if (!isStash) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
        }
        if (isFeiniu && options.extra['skipSigning'] != true) {
          final body = options.data is Map
              ? Map<String, dynamic>.from(options.data as Map)
              : null;
          final signed = FeiniuRequestSigner().sign(
            method: options.method,
            pathname: options.uri.path,
            body: body,
            query: options.uri.queryParameters,
          );
          if (signed.body != null) options.data = signed.body;
          options.headers['Authx'] = signed.authx;
        }
        handler.next(options);
      },
      onResponse: (resp, handler) {
        final data = _decodeBusinessData(resp);
        if (data is Map && data['success'] == false) {
          final message = envelopeMessageOrNull(data);
          final code = envelopeCodeOrNull(data);
          handler.reject(
            DioException(
              requestOptions: resp.requestOptions,
              response: resp,
              type: DioExceptionType.badResponse,
              error: ApiException(
                message ?? code ?? AppErrorCode.operationFailed,
                code:
                    code ??
                    (message == null ? AppErrorCode.operationFailed : null),
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
        if (isRequestActive?.call() == false) {
          handler.next(_connectionClosedError(error.requestOptions));
          return;
        }
        final options = error.requestOptions;
        final status =
            error.response?.statusCode ??
            (error.error is ApiException
                ? (error.error as ApiException).status
                : null);
        final canRefresh =
            sessionRepository != null &&
            project != ServerProject.dbOnline &&
            project != ServerProject.emby &&
            project != ServerProject.jellyfin &&
            project != ServerProject.feiniu &&
            status == 401 &&
            options.extra['skipRefresh'] != true &&
            options.extra['authRetried'] != true &&
            !_isAuthPath(options.path);

        if (canRefresh && await refreshOnce()) {
          if (isRequestActive?.call() == false) {
            handler.next(_connectionClosedError(options));
            return;
          }
          options.extra['authRetried'] = true;
          final token = await sessionRepository.accessToken();
          if (isRequestActive?.call() == false) {
            handler.next(_connectionClosedError(options));
            return;
          }
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

        if (isRequestActive?.call() == false) {
          handler.next(_connectionClosedError(options));
          return;
        }

        if (status == 401 &&
            sessionRepository != null &&
            options.extra['skipAuth'] != true &&
            options.extra['skipSessionExpiry'] != true &&
            !_isAuthPath(options.path)) {
          if (isRequestActive?.call() != false) {
            await sessionRepository.clear();
            if (isRequestActive?.call() != false) onSessionExpired?.call();
          }
        }
        handler.next(_withMappedError(error));
      },
    ),
  );

  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      retries: 3,
      retryDelays: const [
        Duration(milliseconds: 300),
        Duration(milliseconds: 800),
        Duration(seconds: 2),
      ],
      retryEvaluator: (error, attempt) {
        if (isRequestActive?.call() == false) return false;
        final method = error.requestOptions.method.toUpperCase();
        if (method != 'GET') return false;
        if (error.requestOptions.extra['skipRetry'] == true) return false;
        return error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;
      },
    ),
  );

  installAppUserAgentInterceptor(dio);

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
  if (error.error is ApiException ||
      error.error is ServerConnectionClosedException) {
    return error;
  }
  return DioException(
    requestOptions: error.requestOptions,
    response: error.response,
    type: error.type,
    error: mapDioError(error),
  );
}

DioException _connectionClosedError(RequestOptions options) => DioException(
  requestOptions: options,
  type: DioExceptionType.cancel,
  error: const ServerConnectionClosedException(),
);

ApiException toApiException(Object error) {
  // Riverpod 3 会把 provider 抛出的异常包装成 ProviderException，其 toString()
  // 带完整堆栈，直接展示会撑爆错误页。先剥回原始异常再归一化。
  if (error is ProviderException) return toApiException(error.exception);
  if (error is ApiException) {
    // 部分后端会把客户端错误码放在 message 而不是 code 中；补回已知
    // 错误码后，界面才能按当前语言显示对应文案。未知业务消息保持原样。
    final code = error.code ?? _knownErrorCode(error.message);
    if (code == null || code == error.code) return error;
    return ApiException(
      error.message,
      code: code,
      status: error.status,
      requestId: error.requestId,
      data: error.data,
      details: error.details,
    );
  }
  if (error is String) {
    final code = _knownErrorCode(error);
    return ApiException(error, code: code);
  }
  if (error is SourceException) {
    return ApiException(
      error.message,
      code: error.code,
      status: error.statusCode,
      details: error.details,
    );
  }
  if (error is ServerConnectionClosedException) {
    return ApiException(error.message, code: error.message);
  }
  if (error is DioException) {
    if (error.error is ApiException) return error.error as ApiException;
    if (error.error is ServerConnectionClosedException) {
      final closed = error.error as ServerConnectionClosedException;
      return ApiException(closed.message, code: closed.message);
    }
    return mapDioError(error);
  }
  if (error is TimeoutException) {
    return ApiException(
      AppErrorCode.requestTimeout,
      code: AppErrorCode.requestTimeout,
    );
  }
  if (error is FormatException) {
    return ApiException(
      error.message,
      code: _knownErrorCode(error.message) ?? AppErrorCode.validationFailed,
    );
  }
  if (error is ArgumentError) {
    final message = error.message?.toString() ?? error.toString();
    return ApiException(
      message,
      code: _knownErrorCode(message) ?? AppErrorCode.validationFailed,
    );
  }
  if (error is StateError || error is UnsupportedError) {
    final message =
        (error is StateError
            ? error.message
            : (error as UnsupportedError).message) ??
        AppErrorCode.operationFailed;
    final code = _knownErrorCode(message);
    if (code != null) return ApiException(message, code: code);
    return ApiException(message);
  }
  return ApiException(error.toString());
}

String? _knownErrorCode(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  const codes = <String>{
    AppErrorCode.operationFailed,
    AppErrorCode.responseFormatInvalid,
    AppErrorCode.responseDataMissing,
    AppErrorCode.requestTimeout,
    AppErrorCode.networkUnavailable,
    AppErrorCode.routeNotFound,
    AppErrorCode.validationFailed,
    AppErrorCode.httpError,
    AppErrorCode.authenticationRequired,
    AppErrorCode.fileTransferCanceled,
    AppErrorCode.fileSourceNotFound,
    AppErrorCode.fileTransferFailed,
    AppErrorCode.fileTargetExists,
    AppErrorCode.fileRangeUnsupported,
    AppErrorCode.updateFailed,
    AppErrorCode.connectionClosed,
    AppErrorCode.serverCompatibility,
    AppErrorCode.mediaSourceReferenceInvalid,
    AppErrorCode.mediaLibraryNotFound,
    AppErrorCode.feiniuRequestFailed,
    AppErrorCode.stashApiKeyInvalid,
    AppErrorCode.stashRequestFailed,
    AppErrorCode.stashGraphqlFailed,
    AppErrorCode.unsupportedSourceCapability,
    AppErrorCode.previewSegmentsInvalid,
    AppErrorCode.previewSegmentDurationInvalid,
    AppErrorCode.previewExcludeInvalid,
    AppErrorCode.previewPresetInvalid,
    AppErrorCode.previewSpriteIntervalInvalid,
    AppErrorCode.previewSpriteMinimumInvalid,
    AppErrorCode.previewSpriteMaximumInvalid,
    AppErrorCode.previewSpriteSizeInvalid,
    AppErrorCode.ommRequestFailed,
    AppErrorCode.ommTranscodeStatusFailed,
    AppErrorCode.ommSubtitleInvalid,
    AppErrorCode.ommSubtitleFetchFailed,
    AppErrorCode.ommResponseInvalid,
    AppErrorCode.ommLibraryResponseInvalid,
    AppErrorCode.ommFolderResponseInvalid,
    AppErrorCode.ommPathValidationResponseInvalid,
    AppErrorCode.ommScanTaskIdMissing,
    AppErrorCode.ommBatchScanResponseInvalid,
    AppErrorCode.ommLibraryIdMissing,
    AppErrorCode.ommFolderIdMissing,
    AppErrorCode.ommSourceIdInvalid,
    AppErrorCode.ommIdInvalid,
    AppErrorCode.unsupportedResourceType,
    AppErrorCode.taskResponseInvalid,
    AppErrorCode.taskIdMissing,
    AppErrorCode.previewTaskIdRequired,
    AppErrorCode.actorMappingLoadFailed,
    AppErrorCode.previewTaskCreateFailed,
    AppErrorCode.previewTaskStatusInvalid,
    AppErrorCode.avatarContentEmpty,
  };
  return codes.contains(normalized) ? normalized : null;
}
