import 'dart:async';
import 'dart:io';

import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_source_repository.dart';

/// 将 SMB/WebDAV 的文件流暴露为播放器可读取的本机 HTTP 地址。
///
/// 播放器连接后立即消费远程流，不在本地落盘完整视频。代理只绑定回环
/// 地址，并且每个实例只有一个不可枚举的媒体路径。
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

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _responses.add(response);
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
      _setHeaders(response);
      final range = _parseRange(request.headers.value('range'));
      if (range?.invalid == true) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        if (size != null) {
          response.headers.set('content-range', 'bytes */$size');
        }
        return;
      }
      if (range != null) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.contentLength = range.length;
        response.headers.set(
          'content-range',
          'bytes ${range.start}-${range.end}/${size ?? '*'}',
        );
      } else if (size != null) {
        response.headers.contentLength = size!;
      }
      if (request.method == 'HEAD') return;

      final access = await repository.resolveAccess(path);
      var stream = await access.open();
      if (range != null) {
        stream = _slice(stream, skip: range.start, take: range.length);
      }
      await response.addStream(stream);
    } catch (_) {
      // 播放器断开连接或远端连接失败时直接结束本次响应；播放器会展示
      // 自己的错误态，不能再向已发送部分响应的 socket 写错误正文。
    } finally {
      _responses.remove(response);
      try {
        await response.close();
      } catch (_) {}
    }
  }

  void _setHeaders(HttpResponse response) {
    response.headers.set('accept-ranges', 'bytes');
    final mime = mimeType?.trim();
    if (mime != null && mime.isNotEmpty) {
      try {
        response.headers.contentType = ContentType.parse(mime);
      } catch (_) {}
    }
  }

  _FileByteRange? _parseRange(String? header) {
    final total = size;
    if (header == null || !header.startsWith('bytes=') || total == null) {
      return null;
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

  Stream<List<int>> _slice(
    Stream<List<int>> source, {
    int skip = 0,
    required int take,
  }) async* {
    var remainingSkip = skip;
    var remainingTake = take;
    await for (final chunk in source) {
      if (remainingTake <= 0) break;
      var start = 0;
      if (remainingSkip > 0) {
        final skipped = remainingSkip.clamp(0, chunk.length).toInt();
        remainingSkip -= skipped;
        start = skipped;
      }
      if (start >= chunk.length) continue;
      final end = (start + remainingTake).clamp(start, chunk.length).toInt();
      yield start == 0 && end == chunk.length
          ? chunk
          : chunk.sublist(start, end);
      remainingTake -= end - start;
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
