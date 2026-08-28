import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/sources/common/source_exception.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_source_repository.dart';

/// 将 SMB/WebDAV 的文件流暴露为播放器可读取的本机 HTTP 地址。
///
/// 播放器连接后按需消费远程流。支持 Range 的来源会直接读取对应区间；
/// 不支持随机读取的来源则退回到临时文件，避免播放器为了读取尾部索引
/// 而从远端文件开头重复扫描。
class FilePlaybackProxy {
  FilePlaybackProxy._({
    required this.repository,
    required this.path,
    this.size,
    this.mimeType,
    String? pathExtension,
  }) : _pathExtension = _normalizePathExtension(pathExtension);

  final FileSourceRepository repository;
  final FilePath path;
  final int? size;
  final String? mimeType;
  final String? _pathExtension;
  final String _token =
      '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
  final Set<HttpResponse> _responses = <HttpResponse>{};
  Future<FileAccess>? _accessFuture;
  Future<File>? _fallbackFileFuture;
  File? _fallbackFile;
  HttpServer? _server;
  var _closed = false;

  static Future<FilePlaybackProxy> start({
    required FileSourceRepository repository,
    required FilePath path,
    int? size,
    String? mimeType,
    String? pathExtension,
  }) async {
    final proxy = FilePlaybackProxy._(
      repository: repository,
      path: path,
      size: size,
      mimeType: mimeType,
      pathExtension: pathExtension,
    );
    try {
      proxy._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(proxy._serve());
      return proxy;
    } catch (_) {
      await proxy.close();
      rethrow;
    }
  }

  Uri get uri {
    final server = _server;
    if (server == null || _closed) {
      throw StateError('视频流代理已关闭');
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
      path: _requestPath,
    );
  }

  String get _requestPath =>
      '/$_token${_pathExtension == null ? '' : '.$_pathExtension'}';

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } on StateError {
      // close() 后 HttpServer 的监听流会结束或抛出 StateError。
    } on SocketException {
      // 进程退出或强制关闭服务器时，监听流可能报告 socket 错误。
    }
  }

  Future<FileAccess> _access() {
    final current = _accessFuture;
    if (current != null) return current;
    final next = repository.resolveAccess(path);
    _accessFuture = next;
    return next;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _responses.add(response);
    var responseStarted = false;
    try {
      if (_closed || request.uri.path != _requestPath) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        return;
      }

      final access = await _access();
      var total = size ?? access.size;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      // Range 无法在未知总大小上安全解析。先建立临时文件取得大小，
      // 之后 HEAD/Range 请求都能返回稳定的 HTTP 元数据。
      if (rangeHeader != null && total == null) {
        final fallback = await _ensureFallbackFile(access);
        total = await fallback.length();
      }
      var range = _parseRange(rangeHeader, total);
      if (range?.invalid == true) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          'content-range',
          'bytes */${total ?? '*'}',
        );
        return;
      }

      Stream<List<int>>? stream;
      File? fallbackFile;
      if (request.method == 'GET') {
        if (range != null) {
          try {
            if (!repository.supportsRange) {
              throw UnsupportedError('文件来源不支持 Range');
            }
            stream = await repository.openRange(
              path,
              offset: range.start,
              length: range.length,
            );
          } on UnsupportedError {
            fallbackFile = await _ensureFallbackFile(access);
            total ??= await fallbackFile.length();
            range = _parseRange(rangeHeader, total);
            if (range?.invalid == true || range == null) {
              throw const FileSourceException(
                '文件区间无效',
                statusCode: HttpStatus.requestedRangeNotSatisfiable,
              );
            }
            stream = fallbackFile.openRead(range.start, range.end + 1);
          }
        } else {
          stream = await access.open();
        }
      }

      _setHeaders(response, total: total, range: range);
      responseStarted = true;
      if (request.method == 'HEAD') return;
      await response.addStream(stream!);
    } catch (error, stackTrace) {
      _logError(request, error, stackTrace);
      if (!responseStarted) {
        response.statusCode = _statusCode(error);
        response.write('视频流读取失败');
      }
    } finally {
      _responses.remove(response);
      try {
        await response.close();
      } catch (_) {}
    }
  }

  void _setHeaders(
    HttpResponse response, {
    required int? total,
    required _FileByteRange? range,
  }) {
    response.headers.set('accept-ranges', 'bytes');
    final mime = mimeType?.trim();
    if (mime != null && mime.isNotEmpty) {
      try {
        response.headers.contentType = ContentType.parse(mime);
      } catch (_) {}
    }
    if (range != null) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentLength = range.length;
      response.headers.set(
        'content-range',
        'bytes ${range.start}-${range.end}/${total ?? '*'}',
      );
    } else if (total != null) {
      response.headers.contentLength = total;
    }
  }

  _FileByteRange? _parseRange(String? header, int? total) {
    if (header == null) return null;
    if (!header.startsWith('bytes=') || total == null || total <= 0) {
      return const _FileByteRange.invalid();
    }
    final value = header.substring('bytes='.length).split(',').first.trim();
    final separator = value.indexOf('-');
    if (separator < 0) return const _FileByteRange.invalid();
    final startText = value.substring(0, separator).trim();
    final endText = value.substring(separator + 1).trim();
    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) {
        return const _FileByteRange.invalid();
      }
      final start = total - suffixLength;
      if (start < 0) return _FileByteRange(start: 0, end: total - 1);
      return _FileByteRange(start: start, end: total - 1);
    }
    final start = int.tryParse(startText);
    if (start == null || start < 0 || start >= total) {
      return const _FileByteRange.invalid();
    }
    final requestedEnd = endText.isEmpty ? total - 1 : int.tryParse(endText);
    if (requestedEnd == null || requestedEnd < start) {
      return const _FileByteRange.invalid();
    }
    return _FileByteRange(
      start: start,
      end: requestedEnd.clamp(start, total - 1).toInt(),
    );
  }

  Future<File> _ensureFallbackFile(FileAccess access) async {
    final existingFile = _fallbackFile;
    if (existingFile != null) return existingFile;
    final current = _fallbackFileFuture;
    if (current != null) return current;
    late final Future<File> next;
    next = _spoolToTempFile(access);
    _fallbackFileFuture = next;
    try {
      final file = await next;
      _fallbackFile = file;
      return file;
    } catch (_) {
      if (identical(_fallbackFileFuture, next)) _fallbackFileFuture = null;
      rethrow;
    }
  }

  Future<File> _spoolToTempFile(FileAccess access) async {
    late final Directory directory;
    try {
      directory = await getTemporaryDirectory();
    } catch (_) {
      // Unit tests and headless callers may not have a Flutter path-provider
      // binding. The process temp directory is a safe compatibility fallback.
      directory = Directory.systemTemp;
    }
    final file = File(
      '${directory.path}${Platform.pathSeparator}omm-playback-$_token.tmp',
    );
    final output = file.openWrite();
    try {
      await output.addStream(await access.open());
      await output.close();
      if (_closed) throw StateError('视频流代理已关闭');
      return file;
    } catch (_) {
      try {
        await output.close();
      } catch (_) {}
      await _deleteQuietly(file);
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final server = _server;
    _server = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
    for (final response in _responses.toList()) {
      try {
        await response.close();
      } catch (_) {}
    }
    _responses.clear();
    final fallback = _fallbackFile;
    if (fallback != null) {
      await _deleteQuietly(fallback);
    }
    final pending = _fallbackFileFuture;
    if (pending != null) {
      unawaited(pending.then(_deleteQuietly, onError: (_, __) {}));
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _logError(HttpRequest request, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint(
      '[FilePlaybackProxy] ${request.method} ${request.uri.path} failed: '
      '$error\n$stackTrace',
    );
  }

  int _statusCode(Object error) {
    final status = error is FileSourceException ? error.statusCode : null;
    if (status != null && status >= 400 && status <= 599) return status;
    return HttpStatus.badGateway;
  }
}

String? _normalizePathExtension(String? value) {
  final extension = value?.trim().toLowerCase().replaceFirst('.', '');
  if (extension == null || extension.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9]+$').hasMatch(extension)) return null;
  return extension;
}

class _FileByteRange {
  const _FileByteRange({required this.start, required this.end})
    : invalid = false;

  const _FileByteRange.invalid() : start = 0, end = -1, invalid = true;

  final int start;
  final int end;
  final bool invalid;

  int get length => end - start + 1;
}
