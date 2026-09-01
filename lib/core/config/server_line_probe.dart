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
         versionInfo: versionInfo,
       );

  const ServerLineProbeResult.failure(
    ServerLine line,
    String message, {
    bool incompatible = false,
    ServerVersionInfo? versionInfo,
  }) : this._(
         line: line,
         success: false,
         latencyMs: 0,
         message: message,
         incompatible: incompatible,
         versionInfo: versionInfo,
       );

  final ServerLine line;
  final bool success;
  final int latencyMs;
  final String message;
  final bool incompatible;
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
      return ServerLineProbeResult.failure(line, error.toString());
    }
  }
}

Future<ServerLineProbeResult> probeServerLine(ServerLine line) async {
  final stopwatch = Stopwatch()..start();
  try {
    final versionInfo = await _probeOmmVersion(line);
    if (versionInfo == null) {
      // OMM 协议不通时回退尝试 Emby：/emby/System/Info/Public 是免鉴权的
      // 标准入口，OMM/DBO 服务器对其返回 404，不会误判。
      final embyInfo = await _probeEmbyVersion(line);
      if (embyInfo == null) {
        throw ApiException('服务器版本检测失败');
      }
      stopwatch.stop();
      return ServerLineProbeResult.success(
        line,
        stopwatch.elapsedMilliseconds,
        versionInfo: embyInfo,
      );
    }
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
  } catch (error) {
    stopwatch.stop();
    final exception = toApiException(error);
    return ServerLineProbeResult.failure(
      line,
      exception.message,
      incompatible:
          error is ServerCompatibilityException ||
          exception.status == 401 ||
          exception.status == 404,
    );
  }
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

/// 读取 Emby 的 /emby/System/Info/Public；非 Emby 服务器（404/格式不符）
/// 返回 null。
Future<ServerVersionInfo?> _probeEmbyVersion(ServerLine line) async {
  final dio = buildDio(
    ServerConfig(baseUrl: line.baseUrl),
    connectTimeout: const Duration(milliseconds: 1200),
    sendTimeout: const Duration(milliseconds: 1200),
    receiveTimeout: const Duration(milliseconds: 2200),
  );
  // 探测用 dio 的 baseUrl 带 OMM 的 /api 前缀，Emby 接口在根路径下，
  // 必须用绝对地址绕开。
  final probeUrl =
      '${ServerConfig.normalize(line.baseUrl)}/emby/System/Info/Public';
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
  final version = data['Version'].toString().trim();
  final project = ServerProject.emby;
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
