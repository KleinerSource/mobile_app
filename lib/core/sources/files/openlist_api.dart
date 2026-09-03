import 'dart:async';

import 'package:dio/dio.dart';

/// OpenList（AList v3 兼容）连接参数。
///
/// 文件管理完全走 WebDAV：[uri] 是含内置 `/dav` 前缀的端点（如
/// `http://host:5244/dav`），REST API 仅保留「强制刷新目录缓存」一个
/// 用途。[path] 是 `/dav` 之内的根路径（对应实例内的挂载路径）。
class OpenListConnectionOptions {
  const OpenListConnectionOptions({
    required this.uri,
    required this.port,
    this.path = '/',
    this.user = '',
    this.password = '',
    this.timeoutMilliseconds = 30 * 1000,
  });

  final String uri;

  /// 仅为与其他文件源的连接参数保持一致而保留，实际端口已含在 [uri]。
  final int port;
  final String path;
  final String user;
  final String password;
  final int timeoutMilliseconds;
}

/// OpenList 业务错误（信封 code != 200）或网络层错误。
class OpenListException implements Exception {
  const OpenListException(this.message, {this.code, this.statusCode});

  final String message;

  /// OpenList 响应信封中的业务码。
  final int? code;

  /// HTTP 层状态码（网络层失败时可用）。
  final int? statusCode;

  @override
  String toString() => 'OpenListException: $message (code: $code)';
}

/// OpenList REST API 的最小客户端：登录 + 强制刷新。
///
/// 文件操作一律不经过这里；只有需要绕过服务端目录缓存（强制刷新）时
/// 才调用 [refreshDirectory]，其结果本身不使用，后续 WebDAV 列目录会
/// 读到已更新的缓存。
class OpenListClient {
  OpenListClient(OpenListConnectionOptions options)
    : _options = options,
      _baseUri = _apiBaseFromDavUri(Uri.parse(options.uri.trim())),
      _dio = Dio(
        BaseOptions(
          connectTimeout: Duration(milliseconds: options.timeoutMilliseconds),
          receiveTimeout: Duration(milliseconds: options.timeoutMilliseconds),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

  final OpenListConnectionOptions _options;
  final Uri _baseUri;
  final Dio _dio;

  String? _token;
  Future<void>? _loginFuture;

  bool get _hasCredentials => _options.user.trim().isNotEmpty;

  /// 把 WebDAV 端点还原为站点根（去掉首个 `dav` 路径段），REST API
  /// 挂在站点根下（`/api/...`）。反代子路径会保留在根之前。
  static Uri _apiBaseFromDavUri(Uri davUri) {
    final segments = davUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final index = segments.indexOf('dav');
    if (index < 0) return davUri.replace(path: '/');
    final prefix = segments.sublist(0, index);
    return davUri.replace(path: prefix.isEmpty ? '/' : '/${prefix.join('/')}');
  }

  Future<void> ensureAuthenticated() {
    if (!_hasCredentials || _token != null) return Future.value();
    return _login();
  }

  Future<void> _login() {
    return _loginFuture ??= _performLogin().whenComplete(() {
      _loginFuture = null;
    });
  }

  Future<void> _performLogin() async {
    Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        _apiUri('api/auth/login').toString(),
        data: <String, dynamic>{
          'username': _options.user,
          'password': _options.password,
        },
      );
    } on DioException catch (error) {
      throw _networkError('OpenList 登录失败', error);
    }
    final payload = response.data ?? const <String, dynamic>{};
    final code = payload['code'];
    final message = payload['message']?.toString() ?? '未知错误';
    if (code != 200) {
      throw OpenListException(
        'OpenList 登录失败：$message',
        code: code is int ? code : null,
      );
    }
    final data = payload['data'];
    final token = data is Map ? data['token']?.toString() : null;
    if (token == null || token.isEmpty) {
      throw const OpenListException('OpenList 登录响应缺少令牌');
    }
    _token = token;
  }

  /// 强制刷新目录：要求服务端绕过驱动缓存、从后端存储重读该目录。
  Future<void> refreshDirectory(String path) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      await ensureAuthenticated();
      Response<Map<String, dynamic>> response;
      try {
        response = await _dio.post<Map<String, dynamic>>(
          _apiUri('api/fs/list').toString(),
          data: <String, dynamic>{
            'path': path,
            'password': '',
            'page': 1,
            'per_page': 1,
            'refresh': true,
          },
          options: Options(
            headers: <String, String>{
              if (_token != null) 'Authorization': _token!,
            },
          ),
        );
      } on DioException catch (error) {
        throw _networkError('OpenList 刷新请求失败', error);
      }
      final payload = response.data ?? const <String, dynamic>{};
      final code = payload['code'];
      if (code == 200) return;
      final message = payload['message']?.toString() ?? '未知错误';
      if (code == 401 && attempt == 1 && _hasCredentials) {
        // 令牌过期：重新登录后重试一次。
        _token = null;
        await _login();
        continue;
      }
      throw OpenListException(
        'OpenList 强制刷新失败：$message',
        code: code is int ? code : null,
      );
    }
  }

  Future<void> dispose() async {
    _dio.close(force: true);
  }

  Uri _apiUri(String relative) {
    final prefix = _baseUri.path.replaceFirst(RegExp(r'/$'), '');
    return _baseUri.replace(path: '$prefix/$relative');
  }

  OpenListException _networkError(String context, DioException error) {
    final response = error.response;
    if (response?.data is Map) {
      final payload = Map<String, dynamic>.from(response!.data as Map);
      final code = payload['code'];
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return OpenListException(
          '$context：$message',
          code: code is int ? code : null,
          statusCode: response.statusCode,
        );
      }
    }
    final detail = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '服务器响应超时',
      DioExceptionType.connectionError => '无法连接服务器',
      DioExceptionType.cancel => '请求已取消',
      _ => error.message ?? error.type.name,
    };
    return OpenListException(
      '$context：$detail',
      statusCode: response?.statusCode,
    );
  }
}
