import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// OpenList（AList v3 兼容）REST API 连接参数。
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

  /// 仅为与 [WebDavConnectionOptions] 等其他来源保持一致而保留，
  /// 实际端口信息已包含在 [uri] 中。
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

  bool get isUnauthorized => code == 401 || statusCode == 401;

  bool get isNotFound =>
      code == 404 ||
      RegExp(
        'object not found|failed get object',
        caseSensitive: false,
      ).hasMatch(message);

  @override
  String toString() => 'OpenListException: $message (code: $code)';
}

class OpenListEntry {
  const OpenListEntry({
    required this.name,
    required this.isDir,
    this.size,
    this.modified,
    this.sign = '',
    this.thumb = '',
  });

  factory OpenListEntry.fromJson(Map<String, dynamic> json) {
    return OpenListEntry(
      name: json['name']?.toString() ?? '',
      isDir: json['is_dir'] == true,
      size: json['size'] is int ? json['size'] as int : null,
      modified: DateTime.tryParse(json['modified']?.toString() ?? ''),
      sign: json['sign']?.toString() ?? '',
      thumb: json['thumb']?.toString() ?? '',
    );
  }

  final String name;
  final bool isDir;
  final int? size;
  final DateTime? modified;
  final String sign;
  final String thumb;
}

class OpenListFile {
  const OpenListFile({
    required this.name,
    required this.isDir,
    this.size,
    this.modified,
    this.sign = '',
    this.rawUrl = '',
    this.headers = const <String, String>{},
    this.provider = '',
  });

  factory OpenListFile.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['header'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final value = entry.value?.toString() ?? '';
        if (value.isNotEmpty) {
          headers[entry.key.toString()] = value;
        }
      }
    }
    return OpenListFile(
      name: json['name']?.toString() ?? '',
      isDir: json['is_dir'] == true,
      size: json['size'] is int ? json['size'] as int : null,
      modified: DateTime.tryParse(json['modified']?.toString() ?? ''),
      sign: json['sign']?.toString() ?? '',
      rawUrl: json['raw_url']?.toString() ?? '',
      headers: headers,
      provider: json['provider']?.toString() ?? '',
    );
  }

  final String name;
  final bool isDir;
  final int? size;
  final DateTime? modified;
  final String sign;
  final String rawUrl;
  final Map<String, String> headers;
  final String provider;
}

/// 直连下载地址及其访问头。
class OpenListDirectAccess {
  const OpenListDirectAccess({required this.uri, required this.headers});

  final Uri uri;
  final Map<String, String> headers;
}

/// OpenList REST API 客户端（dio 实现，原生与 Web 均可用）。
class OpenListClient {
  OpenListClient(OpenListConnectionOptions options)
    : _options = options,
      _baseUri = Uri.parse(options.uri.trim()),
      _dio = Dio(
        BaseOptions(
          connectTimeout: Duration(milliseconds: options.timeoutMilliseconds),
          receiveTimeout: Duration(milliseconds: options.timeoutMilliseconds),
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

  static const _perPage = 500;
  static const _maxPages = 200;

  final OpenListConnectionOptions _options;
  final Uri _baseUri;
  final Dio _dio;

  String? _token;
  Future<void>? _loginFuture;
  final Map<String, OpenListDirectAccess> _directAccessCache =
      <String, OpenListDirectAccess>{};

  bool get _hasCredentials => _options.user.trim().isNotEmpty;

  /// 清空 fs/get 结果的内存缓存（sign/raw_url），强制刷新或写操作后调用。
  void clearDirectAccessCache() => _directAccessCache.clear();

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

  /// 目录列表。服务端按目录粒度缓存驱动返回的结果，[refresh] 为 true 时
  /// 要求服务端绕过缓存重新读取后端存储（仅第一页请求携带）。
  Future<List<OpenListEntry>> listDirectory(
    String path, {
    bool refresh = false,
  }) async {
    final entries = <OpenListEntry>[];
    var page = 1;
    while (true) {
      final data = await _postJson('api/fs/list', <String, dynamic>{
        'path': path,
        'password': '',
        'page': page,
        'per_page': _perPage,
        'refresh': refresh && page == 1,
      });
      final content = data['content'];
      if (content is List) {
        for (final item in content) {
          if (item is Map) {
            entries.add(
              OpenListEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      final total = data['total'];
      final totalInt = total is int ? total : null;
      final hasMoreField = data['has_more'];
      if (hasMoreField is bool) {
        if (!hasMoreField) break;
      } else {
        // 旧版服务端没有 has_more：短页即末页。
        final pageSize = content is List ? content.length : 0;
        if (pageSize < _perPage) break;
        if (totalInt != null && entries.length >= totalInt) break;
      }
      if (totalInt != null && entries.length >= totalInt) break;
      page += 1;
      if (page > _maxPages) break;
    }
    return entries;
  }

  /// 获取文件/目录信息（含 raw_url、sign 与直连所需的附加头）。
  Future<OpenListFile> get(String path, {bool refresh = false}) async {
    final data = await _postJson('api/fs/get', <String, dynamic>{
      'path': path,
      'password': '',
      'refresh': refresh,
    });
    return OpenListFile.fromJson(data);
  }

  Future<void> mkdir(String path) async {
    await _postJson('api/fs/mkdir', <String, dynamic>{'path': path});
    clearDirectAccessCache();
  }

  Future<void> rename(String path, String newName) async {
    await _postJson('api/fs/rename', <String, dynamic>{
      'path': path,
      'name': newName,
    });
    clearDirectAccessCache();
  }

  Future<void> move(String srcDir, String dstDir, List<String> names) async {
    await _postJson('api/fs/move', <String, dynamic>{
      'src_dir': srcDir,
      'dst_dir': dstDir,
      'names': names,
    });
    clearDirectAccessCache();
  }

  Future<void> copy(String srcDir, String dstDir, List<String> names) async {
    await _postJson('api/fs/copy', <String, dynamic>{
      'src_dir': srcDir,
      'dst_dir': dstDir,
      'names': names,
    });
    clearDirectAccessCache();
  }

  Future<void> remove(String dir, List<String> names) async {
    await _postJson('api/fs/remove', <String, dynamic>{
      'dir': dir,
      'names': names,
    });
    clearDirectAccessCache();
  }

  /// 流式上传（PUT /api/fs/put，File-Path 头为 URL 编码的完整路径）。
  Future<void> upload(
    String path,
    Stream<List<int>> data,
    int length, {
    void Function(int transferred, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await ensureAuthenticated();
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        _apiUri('api/fs/put').toString(),
        data: data.map((chunk) {
          if (chunk is Uint8List) return chunk;
          if (chunk.isEmpty) return Uint8List(0);
          return Uint8List.fromList(chunk);
        }),
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            if (_token != null) 'Authorization': _token!,
            'File-Path': Uri.encodeComponent(path),
            'Content-Length': length.toString(),
            'Content-Type': 'application/octet-stream',
          },
        ),
        onSendProgress: onProgress,
      );
      final payload = response.data;
      if (payload != null && payload['code'] is int && payload['code'] != 200) {
        throw OpenListException(
          'OpenList 上传失败：${payload['message'] ?? '未知错误'}',
          code: payload['code'] as int,
        );
      }
      clearDirectAccessCache();
    } on DioException catch (error) {
      if (cancelToken?.isCancelled == true) rethrow;
      throw _networkError('OpenList 上传失败', error);
    }
  }

  /// 解析直连下载地址。结果按路径缓存，播放器反复 seek 不必重复 fs/get。
  Future<OpenListDirectAccess> resolveDirectAccess(String path) async {
    final cached = _directAccessCache[path];
    if (cached != null) return cached;
    final file = await get(path);
    final access = _buildDirectAccess(path, file);
    _directAccessCache[path] = access;
    return access;
  }

  OpenListDirectAccess _buildDirectAccess(String path, OpenListFile file) {
    final rawUrl = file.rawUrl.trim();
    Uri? direct;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      direct = Uri.tryParse(rawUrl);
    } else if (rawUrl.startsWith('/')) {
      direct = _baseUri.resolve(rawUrl);
    }
    direct ??= _downloadUri(path, sign: file.sign);

    final headers = <String, String>{...file.headers};
    final sameHost =
        direct.host == _baseUri.host && direct.port == _baseUri.port;
    if (sameHost && _token != null) {
      // 只对同源地址附带令牌，避免泄漏给云盘直链。
      headers['Authorization'] = _token!;
    }
    return OpenListDirectAccess(uri: direct, headers: headers);
  }

  /// 打开下载流（可选 HTTP Range）。走 /d/ 直链或 fs/get 的 raw_url。
  Future<Response<ResponseBody>> openStream(
    String path, {
    int? rangeStart,
    int? rangeEnd,
    CancelToken? cancelToken,
  }) async {
    final access = await resolveDirectAccess(path);
    final headers = <String, String>{...access.headers};
    if (rangeStart != null && rangeEnd != null) {
      headers['Range'] = 'bytes=$rangeStart-${rangeEnd - 1}';
    }
    try {
      return await _dio.get<ResponseBody>(
        access.uri.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );
    } on DioException catch (error) {
      if (cancelToken?.isCancelled == true) rethrow;
      throw _networkError('OpenList 下载请求失败', error);
    }
  }

  Future<void> dispose() async {
    _directAccessCache.clear();
    _dio.close(force: true);
  }

  Future<Map<String, dynamic>> _postJson(
    String apiPath,
    Map<String, dynamic> body,
  ) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      await ensureAuthenticated();
      Response<Map<String, dynamic>> response;
      try {
        response = await _dio.post<Map<String, dynamic>>(
          _apiUri(apiPath).toString(),
          data: body,
          options: Options(
            headers: <String, String>{
              if (_token != null) 'Authorization': _token!,
            },
          ),
        );
      } on DioException catch (error) {
        if (attempt == 1 && error.response?.statusCode == 401) {
          // HTTP 层 401 同样尝试重新登录一次。
          await _retryLogin();
          continue;
        }
        throw _networkError('OpenList 请求失败', error);
      }
      final payload = response.data ?? const <String, dynamic>{};
      final code = payload['code'];
      if (code == 200) {
        final data = payload['data'];
        return data is Map<String, dynamic>
            ? data
            : const <String, dynamic>{};
      }
      final message = payload['message']?.toString() ?? '未知错误';
      if (code == 401 && attempt == 1 && _hasCredentials) {
        // 令牌过期（信封 401）：重新登录后重试一次。
        _token = null;
        await _login();
        continue;
      }
      throw OpenListException(
        message,
        code: code is int ? code : null,
      );
    }
  }

  Future<void> _retryLogin() async {
    if (!_hasCredentials) {
      throw const OpenListException('OpenList 访问被拒绝（未登录）', code: 401);
    }
    _token = null;
    await _login();
  }

  Uri _apiUri(String relative) {
    final prefix = _baseUri.path.replaceFirst(RegExp(r'/$'), '');
    return _baseUri.replace(path: '$prefix/$relative');
  }

  Uri _downloadUri(String path, {String? sign}) {
    final prefix = _baseUri.path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final hasSign = sign != null && sign.isNotEmpty;
    return _baseUri.replace(
      pathSegments: <String>[...prefix, 'd', ...segments],
      query: hasSign ? 'sign=${Uri.encodeQueryComponent(sign)}' : null,
    );
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
