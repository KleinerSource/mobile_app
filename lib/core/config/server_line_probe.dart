import 'dart:async';

import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import '../api/dio_factory.dart';
import '../api/server_compatibility.dart';
import 'server_config.dart';

typedef ServerLineProbe =
    Future<ServerLineProbeResult> Function(ServerLine line);

class ServerLineProbeResult {
  const ServerLineProbeResult._({
    required this.line,
    required this.success,
    required this.latencyMs,
    required this.message,
    required this.incompatible,
    required this.requiresAuthentication,
    required this.versionInfo,
  });

  const ServerLineProbeResult.success(
    ServerLine line,
    int latencyMs, {
    ServerVersionInfo? versionInfo,
  }) : this._(
         line: line,
         success: true,
         latencyMs: latencyMs,
         message: '',
         incompatible: false,
         requiresAuthentication: false,
         versionInfo: versionInfo,
       );

  const ServerLineProbeResult.failure(
    ServerLine line,
    String message, {
    bool incompatible = false,
    bool requiresAuthentication = false,
    ServerVersionInfo? versionInfo,
  }) : this._(
         line: line,
         success: false,
         latencyMs: 0,
         message: message,
         incompatible: incompatible,
         requiresAuthentication: requiresAuthentication,
         versionInfo: versionInfo,
       );

  final ServerLine line;
  final bool success;
  final int latencyMs;
  final String message;
  final bool incompatible;
  final bool requiresAuthentication;
  final ServerVersionInfo? versionInfo;
}

class ServerLineProbeBatch {
  const ServerLineProbeBatch({
    required this.firstAvailable,
    required this.completed,
  });

  final Future<ServerLineProbeResult?> firstAvailable;
  final Future<List<ServerLineProbeResult>> completed;
}

class ServerLineSelection {
  const ServerLineSelection({required this.selected, required this.results});

  final ServerLineProbeResult? selected;
  final List<ServerLineProbeResult> results;
}

class ServerLineProbeCoordinator {
  ServerLineProbeCoordinator({
    ServerLineProbe? probe,
    this.fallbackDelay = const Duration(milliseconds: 250),
  }) : _probe = probe ?? probeServerLine;

  final ServerLineProbe _probe;
  final Duration fallbackDelay;

  /// 探测单条线路，供添加服务器等需要在保存前验证的流程复用统一逻辑。
  Future<ServerLineProbeResult> probe(
    ServerLine line, {
    String? expectedProjectName,
  }) {
    return _safeProbe(line, expectedProjectName: expectedProjectName);
  }

  ServerLineProbeBatch probeAll(
    Iterable<ServerLine> lines, {
    void Function(ServerLineProbeResult result)? onResult,
    String? expectedProjectName,
  }) {
    final candidates = List<ServerLine>.of(lines);
    final firstAvailable = Completer<ServerLineProbeResult?>();
    var remaining = candidates.length;

    if (remaining == 0) {
      firstAvailable.complete(null);
      return ServerLineProbeBatch(
        firstAvailable: firstAvailable.future,
        completed: Future.value(const []),
      );
    }

    final futures = candidates.map((line) async {
      final result = await _safeProbe(
        line,
        expectedProjectName: expectedProjectName,
      );
      onResult?.call(result);
      if (result.success && !firstAvailable.isCompleted) {
        firstAvailable.complete(result);
      }
      remaining--;
      if (remaining == 0 && !firstAvailable.isCompleted) {
        firstAvailable.complete(null);
      }
      return result;
    }).toList();

    return ServerLineProbeBatch(
      firstAvailable: firstAvailable.future,
      completed: Future.wait(futures),
    );
  }

  /// 当前线路获得一个很短的优先窗口；未及时响应时立即并发探测备用线路。
  Future<ServerLineSelection> selectPreferred({
    required ServerLine current,
    Iterable<ServerLine> alternatives = const [],
    String? expectedProjectName,
  }) async {
    final fallbackLines = List<ServerLine>.of(alternatives);
    final completed = Completer<ServerLineSelection>();
    final results = <ServerLineProbeResult>[];
    Timer? fallbackTimer;
    var pending = 1;
    var fallbacksStarted = false;

    void finishIfUnavailable() {
      if (!completed.isCompleted && fallbacksStarted && pending == 0) {
        completed.complete(
          ServerLineSelection(selected: null, results: List.of(results)),
        );
      }
    }

    void record(ServerLineProbeResult result) {
      results.add(result);
      pending--;
      if (result.success && !completed.isCompleted) {
        fallbackTimer?.cancel();
        completed.complete(
          ServerLineSelection(selected: result, results: List.of(results)),
        );
        return;
      }
      finishIfUnavailable();
    }

    void startFallbacks() {
      if (fallbacksStarted || completed.isCompleted) return;
      fallbacksStarted = true;
      fallbackTimer?.cancel();
      pending += fallbackLines.length;
      for (final line in fallbackLines) {
        unawaited(
          _safeProbe(
            line,
            expectedProjectName: expectedProjectName,
          ).then(record),
        );
      }
      finishIfUnavailable();
    }

    fallbackTimer = Timer(fallbackDelay, startFallbacks);
    unawaited(
      _safeProbe(current, expectedProjectName: expectedProjectName).then((
        result,
      ) {
        record(result);
        if (!result.success) startFallbacks();
      }),
    );

    return completed.future.whenComplete(() => fallbackTimer?.cancel());
  }

  Future<ServerLineProbeResult> _safeProbe(
    ServerLine line, {
    String? expectedProjectName,
  }) async {
    try {
      final result = await _probe(line);
      final expected = expectedProjectName?.trim().toLowerCase();
      final actual = result.versionInfo?.projectName.trim().toLowerCase();
      if (result.success &&
          expected != null &&
          expected.isNotEmpty &&
          actual != expected) {
        return ServerLineProbeResult.failure(
          line,
          '线路项目不匹配，需要 $expectedProjectName，实际为 ${result.versionInfo?.projectName ?? '未知'}',
          incompatible: true,
          versionInfo: result.versionInfo,
        );
      }
      return result;
    } catch (error) {
      final exception = toApiException(error);
      return ServerLineProbeResult.failure(
        line,
        exception.message,
        requiresAuthentication: _isAuthenticationFailure(exception),
      );
    }
  }
}

Future<ServerLineProbeResult> probeServerLine(ServerLine line) async {
  final stopwatch = Stopwatch()..start();
  try {
    final preferFeiniu = _looksLikeFeiniuBasePath(line.baseUrl);
    if (preferFeiniu) {
      final feiniuInfo = await _probeFeiniuVersion(line);
      if (feiniuInfo != null) {
        stopwatch.stop();
        return ServerLineProbeResult.success(
          line,
          stopwatch.elapsedMilliseconds,
          versionInfo: feiniuInfo,
        );
      }
    }

    final versionInfo = await _probeOmmVersion(line);
    if (versionInfo != null) {
      if (versionInfo.project == ServerProject.dbOnline) {
        final dio = buildDio(
          ServerConfig(baseUrl: line.baseUrl),
          connectTimeout: const Duration(milliseconds: 1200),
          sendTimeout: const Duration(milliseconds: 1200),
          receiveTimeout: const Duration(milliseconds: 2200),
        );
        final healthResponse = await dio.get<dynamic>(
          '/health',
          options: Options(
            extra: const {
              'skipAuth': true,
              'skipRefresh': true,
              'skipRetry': true,
            },
          ),
        );
        _requireHealthyServer(healthResponse.data);
      }
      stopwatch.stop();
      return ServerLineProbeResult.success(
        line,
        stopwatch.elapsedMilliseconds,
        versionInfo: versionInfo,
      );
    }

    final openListInfo = _looksLikeOpenListDavEndpoint(line.baseUrl)
        ? await _probeOpenListVersion(line)
        : null;
    if (openListInfo != null) {
      stopwatch.stop();
      return ServerLineProbeResult.success(
        line,
        stopwatch.elapsedMilliseconds,
        versionInfo: openListInfo,
      );
    }

    // OMM 协议不通时回退尝试 Emby/Jellyfin：System/Info/Public 是免鉴权
    // 的标准入口，OMM/DBO 服务器对其返回 404，不会误判。
    final mediaServerInfo = await _probeEmbyLikeVersion(line);
    if (mediaServerInfo != null) {
      stopwatch.stop();
      return ServerLineProbeResult.success(
        line,
        stopwatch.elapsedMilliseconds,
        versionInfo: mediaServerInfo,
      );
    }

    if (!preferFeiniu) {
      final feiniuInfo = await _probeFeiniuVersion(line);
      if (feiniuInfo != null) {
        stopwatch.stop();
        return ServerLineProbeResult.success(
          line,
          stopwatch.elapsedMilliseconds,
          versionInfo: feiniuInfo,
        );
      }
    }

    if (!_looksLikeOpenListDavEndpoint(line.baseUrl)) {
      final openListInfo = await _probeOpenListVersion(line);
      if (openListInfo != null) {
        stopwatch.stop();
        return ServerLineProbeResult.success(
          line,
          stopwatch.elapsedMilliseconds,
          versionInfo: openListInfo,
        );
      }
    }

    throw ApiException('服务器版本检测失败');
  } catch (error) {
    stopwatch.stop();
    final exception = toApiException(error);
    return ServerLineProbeResult.failure(
      line,
      exception.message,
      incompatible:
          error is ServerCompatibilityException || exception.status == 404,
      requiresAuthentication: _isAuthenticationFailure(exception),
    );
  }
}

bool _isAuthenticationFailure(ApiException exception) {
  return exception.status == 401 || exception.status == 403;
}

/// 飞牛影视的版本接口挂在服务器的 /v/api/v1 下，响应为 code/msg/data
/// 信封；版本接口免登录，可用于服务器线路识别。
Future<ServerVersionInfo?> _probeFeiniuVersion(ServerLine line) async {
  final dio = buildDio(
    ServerConfig(baseUrl: line.baseUrl),
    projectOverride: ServerProject.feiniu,
    connectTimeout: const Duration(milliseconds: 1200),
    sendTimeout: const Duration(milliseconds: 1200),
    receiveTimeout: const Duration(milliseconds: 2200),
  );
  try {
    final response = await dio.get<dynamic>(
      '/sys/version',
      options: Options(
        extra: const {'skipAuth': true, 'skipRefresh': true, 'skipRetry': true},
      ),
    );
    final raw = response.data;
    if (raw is! Map || raw['code'] != 0 || raw['data'] is! Map) return null;
    final data = Map<String, dynamic>.from(raw['data'] as Map);
    final version = data['version']?.toString().trim() ?? '';
    if (!isSupportedServerVersion(
      version,
      ServerProject.feiniu.minimumVersion,
    )) {
      throw ServerCompatibilityException(
        '服务器版本不满足要求，需要 ${ServerProject.feiniu.projectName} >= '
        '${ServerProject.feiniu.minimumVersion}，当前版本为 ${version.isEmpty ? '未知' : version}',
      );
    }
    return ServerVersionInfo(
      projectName: ServerProject.feiniu.projectName,
      version: version,
      buildTime: data['mediasrvVersion']?.toString().trim() ?? '',
    );
  } on DioException catch (error) {
    final exception = toApiException(error);
    if (exception.status == 404 || exception.status == 405) return null;
    rethrow;
  }
}

/// 读取 OpenList/AList 的公开站点设置；两个项目都通过
/// `/api/public/settings` 返回 `data.version`，无需登录。
Future<ServerVersionInfo?> _probeOpenListVersion(ServerLine line) async {
  final siteBaseUrl = _openListSiteBaseUrl(line.baseUrl);
  final dio = buildDio(
    ServerConfig(baseUrl: siteBaseUrl),
    connectTimeout: const Duration(milliseconds: 1200),
    sendTimeout: const Duration(milliseconds: 1200),
    receiveTimeout: const Duration(milliseconds: 2200),
  );
  try {
    final response = await dio.get<dynamic>(
      '$siteBaseUrl/api/public/settings',
      options: Options(
        extra: const {'skipAuth': true, 'skipRefresh': true, 'skipRetry': true},
      ),
    );
    final raw = response.data;
    if (raw is! Map || raw['code'] != 200 || raw['data'] is! Map) {
      return null;
    }
    final settings = Map<String, dynamic>.from(raw['data'] as Map);
    final version = normalizeServerVersion(
      settings['version']?.toString() ?? '',
    );
    if (version == null) return null;
    return ServerVersionInfo(
      projectName: ServerProject.openList.projectName,
      version: version,
    );
  } on DioException catch (error) {
    final exception = toApiException(error);
    if (exception.status == 404 || exception.status == 405) return null;
    rethrow;
  }
}

String _openListSiteBaseUrl(String raw) {
  final normalized = ServerConfig.normalize(raw);
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) return normalized;

  final segments = uri.pathSegments;
  final davIndex = segments.indexWhere(
    (segment) => segment.toLowerCase() == 'dav',
  );
  if (davIndex < 0) return normalized;
  final prefix = segments.take(davIndex).toList(growable: false);
  return ServerConfig.normalize(
    uri.replace(path: prefix.isEmpty ? '/' : '/${prefix.join('/')}').toString(),
  );
}

bool _looksLikeOpenListDavEndpoint(String raw) {
  final uri = Uri.tryParse(ServerConfig.normalize(raw));
  if (uri == null) return false;
  return uri.pathSegments.any((segment) => segment.toLowerCase() == 'dav');
}

bool _looksLikeFeiniuBasePath(String raw) {
  final uri = Uri.tryParse(ServerConfig.normalize(raw));
  if (uri == null) return false;
  var path = uri.path.toLowerCase();
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path == '/v' || path.endsWith('/v');
}

/// 读取 OMM/DBO 的 /api/version；响应不是兼容信封时返回 null，交由
/// Emby 回退探测继续判断。
Future<ServerVersionInfo?> _probeOmmVersion(ServerLine line) async {
  final dio = buildDio(
    ServerConfig(baseUrl: line.baseUrl),
    connectTimeout: const Duration(milliseconds: 1200),
    sendTimeout: const Duration(milliseconds: 1200),
    receiveTimeout: const Duration(milliseconds: 2200),
  );
  final Response<dynamic> response;
  try {
    response = await dio.get<dynamic>(
      '/version',
      options: Options(
        extra: const {'skipAuth': true, 'skipRefresh': true, 'skipRetry': true},
      ),
    );
  } on DioException catch (error) {
    final exception = toApiException(error);
    if (exception.status == 404 || exception.status == 405) {
      return null;
    }
    rethrow;
  }
  final data = response.data;
  if (data is! Map || data['success'] is! bool) {
    return null;
  }
  return requireCompatibleServerVersion(data);
}

/// 读取 Emby/Jellyfin 的 System/Info/Public；非该系列服务器（404/格式
/// 不符）返回 null。
///
/// 两个项目接口同源，靠响应里的 ProductName 区分：Jellyfin 返回
/// "Jellyfin Server"，Emby 无该字段。根路径探测覆盖 Jellyfin 全系
/// （/emby 前缀自 10.11 起移除）与部分 Emby，404 时回退 /emby 前缀。
Future<ServerVersionInfo?> _probeEmbyLikeVersion(ServerLine line) async {
  final dio = buildDio(
    ServerConfig(baseUrl: line.baseUrl),
    connectTimeout: const Duration(milliseconds: 1200),
    sendTimeout: const Duration(milliseconds: 1200),
    receiveTimeout: const Duration(milliseconds: 2200),
  );
  // 探测用 dio 的 baseUrl 带 OMM 的 /api 前缀，Emby 系接口在根路径下，
  // 必须用绝对地址绕开。
  final base = ServerConfig.normalize(line.baseUrl);
  final data =
      await _fetchPublicSystemInfo(dio, '$base/System/Info/Public') ??
      await _fetchPublicSystemInfo(dio, '$base/emby/System/Info/Public');
  if (data == null) return null;
  final version = data['Version'].toString().trim();
  final productName = data['ProductName']?.toString().trim() ?? '';
  final project = productName == 'Jellyfin Server'
      ? ServerProject.jellyfin
      : ServerProject.emby;
  if (!isSupportedServerVersion(version, project.minimumVersion)) {
    throw ServerCompatibilityException(
      '服务器版本不满足要求，需要 ${project.projectName} >= '
      '${project.minimumVersion}，当前版本为 ${version.isEmpty ? '未知' : version}',
    );
  }
  return ServerVersionInfo(
    projectName: project.projectName,
    version: version,
    buildTime: data['BuildTime']?.toString().trim() ?? '',
  );
}

Future<Map<String, dynamic>?> _fetchPublicSystemInfo(
  Dio dio,
  String probeUrl,
) async {
  final Response<dynamic> response;
  try {
    response = await dio.get<dynamic>(
      probeUrl,
      options: Options(
        responseType: ResponseType.json,
        extra: const {'skipAuth': true, 'skipRefresh': true, 'skipRetry': true},
      ),
    );
  } on DioException catch (error) {
    final exception = toApiException(error);
    if (exception.status == 404 || exception.status == 405) {
      return null;
    }
    rethrow;
  }
  final data = response.data;
  if (data is! Map || data['Version'] == null) {
    return null;
  }
  return Map<String, dynamic>.from(data);
}

void _requireHealthyServer(Object? raw) {
  if (raw is! Map) {
    throw ApiException('服务器健康检查响应格式异常');
  }
  final envelope = Map<String, dynamic>.from(raw);
  if (envelope['success'] == false) {
    throw ApiException(
      envelope['message']?.toString() ??
          envelope['error']?.toString() ??
          '服务器健康检查未通过',
    );
  }

  final payload = envelope['data'] is Map
      ? Map<String, dynamic>.from(envelope['data'] as Map)
      : envelope;
  if (payload['status']?.toString().trim().toLowerCase() != 'healthy') {
    throw ApiException('服务器健康检查未通过');
  }
}
