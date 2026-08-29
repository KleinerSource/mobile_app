import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/platform/app_log_store.dart';
import '../../core/sources/common/source_exception.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_source_repository.dart';

const _operationTimeout = Duration(seconds: 30);
const _metadataTimeout = Duration(seconds: 2);

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
      proxy._log(
        '代理已启动: ${proxy.uri} source=${path.stableKey} '
        'size=$size mime=${mimeType ?? ''} supportsRange=${repository.supportsRange}',
      );
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
      _log(
        '收到请求: ${request.method} ${request.uri} '
        'range=${request.headers.value(HttpHeaders.rangeHeader)}',
      );
      if (_closed || request.uri.path != _requestPath) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        return;
      }

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      var total = size;
      FileAccess? access;

      Future<FileAccess> loadAccess() async {
        final current = access;
        if (current != null) return current;
        _log('开始 resolveAccess: ${path.stableKey}');
        final resolved = await _access().timeout(_operationTimeout);
        access = resolved;
        _log(
          'resolveAccess 完成: size=${resolved.size} mime=${resolved.mimeType}',
        );
        return resolved;
      }

      // Range 无法在未知总大小上安全解析。先建立临时文件取得大小，
      // 之后 HEAD/Range 请求都能返回稳定的 HTTP 元数据。
      if (rangeHeader != null && total == null) {
        _log('Range 请求缺少文件大小，先落盘获取大小');
        final fallback = await _ensureFallbackFile();
        total = await fallback.length();
      }
      // HEAD 没有文件大小时才需要 stat/PROPFIND；常规视频播放不应被
      // resolveAccess 阻塞，GET 会直接进入 download/openRange。
      if (request.method == 'HEAD' && (total == null || mimeType == null)) {
        try {
          final resolved = await loadAccess().timeout(_metadataTimeout);
          total ??= resolved.size;
        } catch (error) {
          // HEAD 元数据不是播放必需条件。SMB/WebDAV 的 stat/PROPFIND
          // 失败或超时不能阻塞后续 GET，播放器会继续按流读取。
          _log('HEAD 元数据读取失败，继续返回可播放响应: $error');
        }
      }
      var range = _parseRange(rangeHeader, total);
      if (range?.invalid == true) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set('content-range', 'bytes */${total ?? '*'}');
        return;
      }

      Stream<List<int>>? stream;
      if (request.method == 'GET') {
        if (range != null) {
          try {
            _log('开始远端区间读取: offset=${range.start} length=${range.length}');
            if (!repository.supportsRange) {
              throw UnsupportedError('文件来源不支持 Range');
            }
            stream = await repository
                .openRange(path, offset: range.start, length: range.length)
                .timeout(_operationTimeout);
            _log('远端区间读取已建立');
          } catch (error) {
            if (error is! UnsupportedError && error is! TimeoutException) {
              rethrow;
            }
            _log('远端区间读取不可用（$error），退回临时文件');
            final fallbackFile = await _ensureFallbackFile();
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
          _log('开始远端完整流读取');
          stream = await _openFullStream(access: access);
          _log('远端完整流已建立');
        }
      }

      _setHeaders(
        response,
        total: total,
        range: range,
        effectiveMimeType:
            mimeType ??
            access?.mimeType ??
            _mimeTypeForExtension(_pathExtension),
      );
      responseStarted = true;
      if (request.method == 'HEAD') return;
      _log('开始向播放器发送响应: status=${response.statusCode}');
      await response.addStream(
        stream!.timeout(
          _operationTimeout,
          onTimeout: (sink) {
            _log('远端流读取超时，关闭播放器响应');
            sink.addError(TimeoutException('远端视频流读取超时'));
            sink.close();
          },
        ),
      );
      _log('播放器响应发送完成: status=${response.statusCode}');
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
    required String? effectiveMimeType,
  }) {
    response.headers.set('accept-ranges', 'bytes');
    final mime = effectiveMimeType?.trim();
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
    final normalizedHeader = header.trim();
    if (!normalizedHeader.toLowerCase().startsWith('bytes=') ||
        total == null ||
        total <= 0) {
      return const _FileByteRange.invalid();
    }
    final value = normalizedHeader
        .substring('bytes='.length)
        .split(',')
        .first
        .trim();
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

  Future<File> _ensureFallbackFile() async {
    final existingFile = _fallbackFile;
    if (existingFile != null) return existingFile;
    final current = _fallbackFileFuture;
    if (current != null) return current;
    late final Future<File> next;
    next = _spoolToTempFile();
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

  Future<File> _spoolToTempFile() async {
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
      _log('开始完整落盘: ${path.stableKey}');
      await output.addStream(await _openFullStream());
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

  Future<Stream<List<int>>> _openFullStream({FileAccess? access}) async {
    try {
      // SMB/WebDAV 的下载路径已在文件下载功能中验证可用；优先使用它，
      // 避免为了获得一个访问句柄再次触发 stat/PROPFIND。
      return repository.download(path);
    } on UnsupportedFileOperationException {
      final resolved = access ?? await _access().timeout(_operationTimeout);
      return resolved.open();
    } on UnsupportedError {
      final resolved = access ?? await _access().timeout(_operationTimeout);
      return resolved.open();
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
    appLog(
      '[FilePlaybackProxy] ${request.method} ${request.uri.path} failed: '
      '$error\n$stackTrace',
    );
  }

  void _log(String message) {
    appLog('[FilePlaybackProxy] $message');
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

String? _mimeTypeForExtension(String? extension) {
  return switch (extension) {
    'mp4' => 'video/mp4',
    'm4v' => 'video/x-m4v',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    'avi' => 'video/x-msvideo',
    'mpeg' || 'mpg' => 'video/mpeg',
    'wmv' => 'video/x-ms-wmv',
    'ogv' => 'video/ogg',
    'vob' => 'video/dvd',
    'rm' || 'rmvb' => 'application/vnd.rn-realmedia',
    'ts' || 'm2ts' => 'video/mp2t',
    '3gp' => 'video/3gpp',
    'flv' => 'video/x-flv',
    _ => null,
  };
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
