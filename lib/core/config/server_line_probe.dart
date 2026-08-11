import 'dart:async';

import 'package:dio/dio.dart';

import '../api/dio_factory.dart';
import '../api/server_compatibility.dart';
import 'server_config.dart';

typedef ServerLineProbe = Future<ServerLineProbeResult> Function(
  ServerLine line,
);

class ServerLineProbeResult {
  const ServerLineProbeResult._({
    required this.line,
    required this.success,
    required this.latencyMs,
    required this.message,
    required this.incompatible,
  });

  const ServerLineProbeResult.success(ServerLine line, int latencyMs)
      : this._(
          line: line,
          success: true,
          latencyMs: latencyMs,
          message: '',
          incompatible: false,
        );

  const ServerLineProbeResult.failure(
    ServerLine line,
    String message, {
    bool incompatible = false,
  }) : this._(
          line: line,
          success: false,
          latencyMs: 0,
          message: message,
          incompatible: incompatible,
        );

  final ServerLine line;
  final bool success;
  final int latencyMs;
  final String message;
  final bool incompatible;
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

  ServerLineProbeBatch probeAll(
    Iterable<ServerLine> lines, {
    void Function(ServerLineProbeResult result)? onResult,
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
      final result = await _safeProbe(line);
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
        unawaited(_safeProbe(line).then(record));
      }
      finishIfUnavailable();
    }

    fallbackTimer = Timer(fallbackDelay, startFallbacks);
    unawaited(
      _safeProbe(current).then((result) {
        record(result);
        if (!result.success) startFallbacks();
      }),
    );

    return completed.future.whenComplete(() => fallbackTimer?.cancel());
  }

  Future<ServerLineProbeResult> _safeProbe(ServerLine line) async {
    try {
      return await _probe(line);
    } catch (error) {
      return ServerLineProbeResult.failure(line, error.toString());
    }
  }
}

Future<ServerLineProbeResult> probeServerLine(ServerLine line) async {
  final stopwatch = Stopwatch()..start();
  try {
    final dio = buildDio(
      ServerConfig(baseUrl: line.baseUrl),
      connectTimeout: const Duration(milliseconds: 1200),
      sendTimeout: const Duration(milliseconds: 1200),
      receiveTimeout: const Duration(milliseconds: 2200),
    );
    final response = await dio.get<dynamic>(
      '/version',
      options: Options(extra: const {
        'skipAuth': true,
        'skipRefresh': true,
        'skipRetry': true,
      }),
    );
    requireCompatibleServerVersion(response.data);
    stopwatch.stop();
    return ServerLineProbeResult.success(line, stopwatch.elapsedMilliseconds);
  } catch (error) {
    stopwatch.stop();
    final exception = toApiException(error);
    return ServerLineProbeResult.failure(
      line,
      exception.message,
      incompatible: error is ServerCompatibilityException ||
          exception.status == 401 ||
          exception.status == 404,
    );
  }
}
