import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

@immutable
class CrashLogEntry {
  const CrashLogEntry({
    required this.timestamp,
    required this.source,
    required this.message,
    required this.stack,
    required this.context,
  });

  factory CrashLogEntry.fromJson(Map<String, dynamic> json) {
    return CrashLogEntry(
      timestamp: DateTime.tryParse('${json['timestamp']}') ?? DateTime.now(),
      source: '${json['source'] ?? 'unknown'}',
      message: '${json['message'] ?? ''}',
      stack: '${json['stack'] ?? ''}',
      context: json['context'] is Map
          ? Map<String, dynamic>.from(json['context'] as Map)
          : const <String, dynamic>{},
    );
  }

  final DateTime timestamp;
  final String source;
  final String message;
  final String stack;
  final Map<String, dynamic> context;
}

/// 持久化应用异常与播放器错误，供用户导出后反馈问题。
///
/// 日志使用 JSON Lines 格式并限制条数/大小，避免异常循环导致日志无限增长。
/// 所有写入内容都会经过敏感字段脱敏，不记录 access/refresh token。
class CrashLogService {
  CrashLogService._(this._directory);

  static const maxEntries = 200;
  static const maxBytes = 512 * 1024;
  static const _directoryName = 'md_center_diagnostics';
  static const _fileName = 'crash_logs.jsonl';

  final Directory _directory;
  Future<void> _writeQueue = Future<void>.value();

  static Future<CrashLogService> create({Directory? rootDirectory}) async {
    final base = rootDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}$_directoryName',
    );
    await directory.create(recursive: true);
    final service = CrashLogService._(directory);
    await service.logFile.create(recursive: true);
    return service;
  }

  File get logFile => File(
        '${_directory.path}${Platform.pathSeparator}$_fileName',
      );

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String source = 'unknown',
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return recordMessage(
      error.toString(),
      source: source,
      stack: stack,
      context: context,
    );
  }

  Future<void> recordMessage(
    String message, {
    String source = 'app',
    StackTrace? stack,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final result = _writeQueue.then<void>((_) async {
      final payload = <String, Object?>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'source': sanitize(source),
        'message': sanitize(message),
        'stack': stack == null ? '' : sanitize(stack.toString()),
        'context': _sanitizeValue(context),
      };
      await logFile.writeAsString(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _trim();
    });
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<List<CrashLogEntry>> readEntries() async {
    await _writeQueue;
    if (!await logFile.exists()) return const <CrashLogEntry>[];
    final entries = <CrashLogEntry>[];
    for (final line in (await logFile.readAsLines()).reversed) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) {
          entries.add(
            CrashLogEntry.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } on FormatException {
        // 忽略被进程异常中断时留下的不完整行。
      }
    }
    return entries;
  }

  Future<void> clear() {
    final result = _writeQueue.then<void>((_) async {
      if (await logFile.exists()) await logFile.delete();
      await logFile.create(recursive: true);
    });
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _trim() async {
    final lines = await logFile.readAsLines();
    if (lines.length <= maxEntries && await logFile.length() <= maxBytes) {
      return;
    }
    var kept = lines.length > maxEntries
        ? lines.sublist(lines.length - maxEntries)
        : lines;
    while (kept.length > 1 &&
        utf8.encode('${kept.join('\n')}\n').length > maxBytes) {
      kept = kept.sublist(1);
    }
    await logFile.writeAsString(
      kept.isEmpty ? '' : '${kept.join('\n')}\n',
      flush: true,
    );
  }

  static String sanitize(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAll(
      RegExp(
        r'(authorization\s*:\s*bearer\s+)[^\s,;]+',
        caseSensitive: false,
      ),
      r'$1[REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'([?&](?:access_token|refresh_token|token|api[-_]?key|apikey|password|secret)=)[^&#\s]+',
        caseSensitive: false,
      ),
      r'$1[REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'''(\b(?:access_token|refresh_token|token|api[-_]?key|apikey|password|secret)\b\s*[=:]\s*)(?:"[^"]*"|'[^']*'|[^\s,;}\]]+)''',
        caseSensitive: false,
      ),
      r'$1[REDACTED]',
    );
    return sanitized;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is String) return sanitize(value);
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          '${entry.key}': _isSensitiveKey(entry.key.toString())
              ? '[REDACTED]'
              : _sanitizeValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map<Object?>((item) => _sanitizeValue(item)).toList();
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll('-', '_');
    return normalized == 'access_token' ||
        normalized == 'refresh_token' ||
        normalized == 'token' ||
        normalized == 'api_key' ||
        normalized == 'apikey' ||
        normalized == 'password' ||
        normalized == 'secret';
  }
}

final crashLogServiceProvider = Provider<CrashLogService>((ref) {
  throw StateError('CrashLogService 未初始化');
});

final crashLogEntriesProvider = FutureProvider.autoDispose<List<CrashLogEntry>>(
  (ref) => ref.watch(crashLogServiceProvider).readEntries(),
);
