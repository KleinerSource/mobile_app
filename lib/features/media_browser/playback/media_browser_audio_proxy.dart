import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:omm/core/platform/app_log_store.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

/// MediaBrowser（Emby/Jellyfin）音频回环代理。
///
/// 播放器对本机地址的请求（含 Range）实时透传给远程直链，字节边到达
/// 边转发，实现流式在线播放与即时 seek；同时在后台把整曲落盘到本地
/// 临时文件（播放开始时若曲子尚未缓存则顺带落盘，当前曲目完成后预取
/// 下一首），已完整落盘的曲目改由本地文件应答，seek 零延迟。
class MediaBrowserAudioProxy {
  MediaBrowserAudioProxy._(this._downloader);

  final Dio _downloader;
  final List<_ProxiedTrack> _orderedTracks = <_ProxiedTrack>[];
  final Map<String, _ProxiedTrack> _tracksByPath = <String, _ProxiedTrack>{};
  final List<CancelToken> _activeDownloads = <CancelToken>[];
  HttpServer? _server;
  var _closed = false;

  static Future<MediaBrowserAudioProxy> start({Dio? downloader}) async {
    final proxy = MediaBrowserAudioProxy._(
      downloader ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              // 完整下载一首曲目可能耗时数分钟（慢速外网），不设接收超时，
              // 由播放会话关闭时统一取消。
              receiveTimeout: null,
            ),
          ),
    );
    try {
      proxy._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      appLog(
        '[MbAudioProxy] 代理已启动: ${proxy._baseUri} '
        'bind=${InternetAddress.loopbackIPv4.host}',
      );
      unawaited(proxy._serve());
      return proxy;
    } catch (_) {
      await proxy.close();
      rethrow;
    }
  }

  /// 注册曲目并返回播放器使用的本机地址。重复注册同一曲目幂等。
  String register(
    MediaBrowserItem track,
    String remoteUrl, {
    Map<String, String>? headers,
  }) {
    final path = '/${_digest(track.id)}';
    final existing = _tracksByPath[path];
    if (existing != null) return _baseUri.replace(path: path).toString();
    final proxied = _ProxiedTrack(
      track: track,
      remoteUrl: remoteUrl,
      path: path,
      headers: headers,
    );
    _orderedTracks.add(proxied);
    _tracksByPath[path] = proxied;
    return _baseUri.replace(path: path).toString();
  }

  Uri get _baseUri {
    final server = _server;
    if (server == null || _closed) {
      throw StateError('MediaBrowser 音频代理已关闭');
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: server.port,
    );
  }

  /// 已绑定的本机基址（诊断与测试用）；代理关闭后抛 StateError。
  Uri get localBaseUri => _baseUri;

  /// 关闭代理：停止接收播放器请求、取消在途下载并清理临时文件。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    for (final token in _activeDownloads.toList()) {
      token.cancel('播放器已关闭');
    }
    final files = <File>[
      for (final track in _orderedTracks)
        if (track.file != null) track.file!,
    ];
    for (final file in files) {
      await _deleteQuietly(file);
    }
    appLog('[MbAudioProxy] 代理已关闭');
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } on StateError {
      // close() 后监听流结束。
    } on SocketException {
      // 进程退出或强制关闭时 socket 报错，可忽略。
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    var responseStarted = false;
    try {
      if (_closed) {
        response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        return;
      }
      final track = _tracksByPath[request.uri.path];
      if (track == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final file = track.file;
      if (file != null) {
        responseStarted = true;
        await _serveLocalFile(request, track, file);
      } else {
        responseStarted = true;
        await _serveRemoteStream(request, track);
      }
    } catch (error, stackTrace) {
      appLog('[MbAudioProxy] 请求处理失败: ${request.uri.path} $error\n$stackTrace');
      if (!responseStarted && !_closed) {
        response.statusCode = HttpStatus.badGateway;
      }
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// 已完整落盘的曲目：由本地文件随机读取应答，任意 seek 零延迟。
  Future<void> _serveLocalFile(
    HttpRequest request,
    _ProxiedTrack track,
    File file,
  ) async {
    final response = request.response;
    final total = await file.length();
    final range = _parseRange(
      request.headers.value(HttpHeaders.rangeHeader),
      total,
    );
    if (range != null && range.invalid) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set('content-range', 'bytes */$total');
      return;
    }
    final mime = track.mimeType ?? _sniffAudioMime(file);
    track.mimeType = mime;
    response.headers.set('accept-ranges', 'bytes');
    response.headers.contentType = ContentType.parse(mime);
    if (range != null) {
      response.statusCode = HttpStatus.partialContent;
      response.contentLength = range.length;
      response.headers.set(
        'content-range',
        'bytes ${range.start}-${range.end}/$total',
      );
    } else {
      response.contentLength = total;
    }
    if (request.method == 'HEAD') return;
    await response.addStream(
      range == null
          ? file.openRead()
          : file.openRead(range.start, range.end + 1),
    );
  }

  /// 未缓存曲目：把播放器请求（含 Range）透传给远程直链，字节边到达
  /// 边转发，实现流式在线播放；从 0 开始的完整响应顺边落盘作为缓存。
  Future<void> _serveRemoteStream(
    HttpRequest request,
    _ProxiedTrack track,
  ) async {
    final response = request.response;
    final cancelToken = CancelToken();
    _activeDownloads.add(cancelToken);
    File? teeFile;
    IOSink? teeSink;
    var teeExpected = 0;
    Completer<File>? teeClaim;
    try {
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final remote = await _downloader.get<ResponseBody>(
        track.remoteUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            if (rangeHeader != null) HttpHeaders.rangeHeader: rangeHeader,
            ...?track.headers,
            'Accept-Encoding': 'identity',
          },
        ),
      );
      if (_closed) {
        cancelToken.cancel('播放器已关闭');
        response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      final status = remote.statusCode ?? HttpStatus.ok;
      response.statusCode = status;
      // Content-Type 延迟到首块：远程给的是通用类型时按文件头嗅探。
      final remoteContentType = _normalizeContentType(
        remote.headers.value(HttpHeaders.contentTypeHeader),
      );
      final acceptRanges = remote.headers.value(HttpHeaders.acceptRangesHeader);
      response.headers.set(
        HttpHeaders.acceptRangesHeader,
        acceptRanges ?? 'bytes',
      );
      final contentRange = remote.headers.value('content-range');
      if (contentRange != null) {
        response.headers.set('content-range', contentRange);
      }
      final contentLengthText = remote.headers.value(
        HttpHeaders.contentLengthHeader,
      );
      var contentLength = -1;
      if (contentLengthText != null) {
        contentLength = int.tryParse(contentLengthText) ?? -1;
        if (contentLength >= 0) response.contentLength = contentLength;
      }
      if (request.method == 'HEAD') {
        response.headers.contentType = ContentType.parse(
          remoteContentType == 'application/octet-stream'
              ? (track.mimeType ?? remoteContentType)
              : remoteContentType,
        );
        return;
      }

      // 仅从 0 开始的完整 200 响应落盘；Range/部分响应不缓存，避免半截
      // 文件被当作完整缓存。
      final fullBodyFromStart =
          status == HttpStatus.ok &&
          contentLength > 0 &&
          (rangeHeader == null || rangeHeader.contains('bytes=0-'));
      if (fullBodyFromStart && track.file == null && track.download == null) {
        try {
          teeFile = await _cacheFileFor(track);
          teeSink = teeFile.openWrite();
          teeExpected = contentLength;
          // 占位避免并发请求对同一缓存文件双写；各分支都会终结它。
          teeClaim = Completer<File>();
          teeClaim.future.ignore();
          track.download = teeClaim.future;
        } catch (_) {
          teeFile = null;
          teeSink = null;
        }
      }

      final stream = remote.data!.stream;
      var headersSent = false;
      var written = 0;
      try {
        await for (final chunk in stream) {
          final bytes = chunk;
          if (!headersSent) {
            if (remoteContentType == 'application/octet-stream' &&
                track.mimeType == null) {
              final sniffed = _sniffAudioMimeBytes(
                bytes,
                fallback: 'application/octet-stream',
              );
              if (sniffed != 'application/octet-stream') {
                track.mimeType = sniffed;
              }
            }
            response.headers.contentType = ContentType.parse(
              track.mimeType ?? remoteContentType,
            );
            headersSent = true;
          }
          response.add(bytes);
          teeSink?.add(bytes);
          written += bytes.length;
          await response.flush();
        }
        if (!headersSent) {
          response.headers.contentType = ContentType.parse(remoteContentType);
        }
        if (teeSink != null) {
          await teeSink.flush();
          await teeSink.close();
          teeSink = null;
          track.download = null;
          if (written == teeExpected && written > 0) {
            track.file = teeFile;
            teeClaim!.complete(teeFile);
            appLog('[MbAudioProxy] 流式缓存完成: ${track.track.name} size=$written');
            unawaited(_prefetchNext(track));
          } else {
            await _deleteQuietly(teeFile!);
            teeClaim!.completeError(
              StateError('流式缓存不完整: $written/$teeExpected'),
            );
          }
        }
      } catch (error) {
        // 客户端断开（如 seek 触发新 Range 请求）或网络中断：终止远程
        // 拉取并丢弃半截缓存。
        cancelToken.cancel('流式转发中断');
        if (teeSink != null) {
          try {
            await teeSink.close();
          } catch (_) {}
          await _deleteQuietly(teeFile!);
        }
        track.download = null;
        teeClaim?.completeError(error);
        rethrow;
      }
    } finally {
      _activeDownloads.remove(cancelToken);
    }
  }

  /// 确保曲目已完整落盘；并发请求共享同一次下载。
  Future<File> _ensureFile(_ProxiedTrack track) {
    final existing = track.file;
    if (existing != null) return Future<File>.value(existing);
    return track.download ??= _downloadTrack(track);
  }

  Future<File> _cacheFileFor(_ProxiedTrack track) async {
    Directory directory;
    try {
      directory = await _mediaDirectory();
    } catch (_) {
      directory = Directory.systemTemp;
    }
    return File(
      '${directory.path}${Platform.pathSeparator}'
      'mb_audio_${_digest(track.track.id)}.media',
    );
  }

  Future<File> _downloadTrack(_ProxiedTrack track) async {
    final cancelToken = CancelToken();
    _activeDownloads.add(cancelToken);
    final file = await _cacheFileFor(track);
    try {
      appLog('[MbAudioProxy] 开始下载: ${track.track.name}');
      await _downloader.download(
        track.remoteUrl,
        file.path,
        cancelToken: cancelToken,
        options: Options(headers: {'Accept-Encoding': 'identity'}),
      );
      if (await file.length() == 0) {
        throw StateError('音频下载结果为空');
      }
      track.file = file;
      appLog(
        '[MbAudioProxy] 下载完成: ${track.track.name} '
        'size=${await file.length()}',
      );
      unawaited(_prefetchNext(track));
      return file;
    } catch (error) {
      track.download = null;
      await _deleteQuietly(file);
      appLog('[MbAudioProxy] 下载失败: ${track.track.name} $error');
      rethrow;
    } finally {
      _activeDownloads.remove(cancelToken);
    }
  }

  /// 当前曲目就绪后预取队列中的下一首，缩短切歌等待。
  Future<void> _prefetchNext(_ProxiedTrack current) async {
    if (_closed) return;
    final index = _orderedTracks.indexOf(current);
    if (index < 0 || index + 1 >= _orderedTracks.length) return;
    final next = _orderedTracks[index + 1];
    if (next.file != null || next.download != null) return;
    try {
      await _ensureFile(next);
    } catch (_) {
      // 预取失败不影响当前播放；切歌时播放器会再次触发下载。
    }
  }

  Future<Directory> _mediaDirectory() async {
    Directory root;
    try {
      root = await getTemporaryDirectory();
    } catch (_) {
      // 测试环境可能未注册 path_provider，回退系统临时目录。
      root = Directory.systemTemp;
    }
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}omm_mb_audio_media',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}

class _ProxiedTrack {
  _ProxiedTrack({
    required this.track,
    required this.remoteUrl,
    required this.path,
    this.headers,
  });

  final MediaBrowserItem track;
  final String remoteUrl;
  final String path;
  final Map<String, String>? headers;
  Future<File>? download;
  File? file;
  String? mimeType;
}

class _ByteRange {
  const _ByteRange({required this.start, required this.end}) : invalid = false;

  const _ByteRange.invalid() : start = -1, end = -1, invalid = true;

  final int start;
  final int end;
  final bool invalid;

  int get length => end - start + 1;
}

_ByteRange? _parseRange(String? header, int total) {
  if (header == null) return null;
  final normalized = header.trim();
  if (!normalized.toLowerCase().startsWith('bytes=') || total <= 0) {
    return const _ByteRange.invalid();
  }
  final value = normalized.substring('bytes='.length).split(',').first.trim();
  final separator = value.indexOf('-');
  if (separator < 0) return const _ByteRange.invalid();
  final startText = value.substring(0, separator).trim();
  final endText = value.substring(separator + 1).trim();
  if (startText.isEmpty) {
    final suffixLength = int.tryParse(endText);
    if (suffixLength == null || suffixLength <= 0) {
      return const _ByteRange.invalid();
    }
    final start = total - suffixLength;
    if (start < 0) return _ByteRange(start: 0, end: total - 1);
    return _ByteRange(start: start, end: total - 1);
  }
  final start = int.tryParse(startText);
  if (start == null || start < 0 || start >= total) {
    return const _ByteRange.invalid();
  }
  final requestedEnd = endText.isEmpty ? total - 1 : int.tryParse(endText);
  if (requestedEnd == null || requestedEnd < start) {
    return const _ByteRange.invalid();
  }
  return _ByteRange(start: start, end: requestedEnd.clamp(start, total - 1));
}

/// 远程 Content-Type 透传前校验，非法值回退通用类型，避免播放器选错
/// 解码路径。
String _normalizeContentType(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return 'application/octet-stream';
  try {
    ContentType.parse(text);
    return text;
  } catch (_) {
    return 'application/octet-stream';
  }
}

/// 按文件头嗅探音频 MIME，避免依赖服务器 Content-Type（部分反代会
/// 返回通用类型导致播放器选错解码路径）。
String _sniffAudioMime(File file) {
  try {
    final head = file.openSync(mode: FileMode.read);
    try {
      final bytes = Uint8List(12);
      final read = head.readIntoSync(bytes, 0, 12);
      return _sniffAudioMimeBytes(
        Uint8List.sublistView(bytes, 0, read),
        fallback: 'application/octet-stream',
      );
    } finally {
      head.closeSync();
    }
  } catch (_) {}
  return 'application/octet-stream';
}

String _sniffAudioMimeBytes(Uint8List bytes, {String fallback = ''}) {
  if (bytes.length >= 3) {
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return 'audio/mpeg'; // ID3
    }
    if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return 'audio/mpeg'; // MPEG audio frame sync
    }
  }
  if (bytes.length >= 4) {
    const flac = [0x66, 0x4C, 0x61, 0x43]; // fLaC
    const oggs = [0x4F, 0x67, 0x67, 0x53]; // OggS
    if (_bytesEqual(bytes, flac, 4)) return 'audio/flac';
    if (_bytesEqual(bytes, oggs, 4)) return 'audio/ogg';
  }
  if (bytes.length >= 12) {
    const riff = [0x52, 0x49, 0x46, 0x46]; // RIFF
    const wave = [0x57, 0x41, 0x56, 0x45]; // WAVE
    const ftyp = [0x66, 0x74, 0x79, 0x70]; // ftyp
    if (_bytesEqual(bytes, riff, 4) && _bytesEqual(bytes, wave, 4, 8)) {
      return 'audio/wav';
    }
    if (_bytesEqual(bytes, ftyp, 4, 4)) return 'audio/mp4';
  }
  return fallback;
}

bool _bytesEqual(
  Uint8List bytes,
  List<int> expected,
  int length, [
  int offset = 0,
]) {
  for (var i = 0; i < length; i++) {
    if (bytes[offset + i] != expected[i]) return false;
  }
  return true;
}

String _digest(String value) =>
    sha256.convert(utf8.encode('mediabrowser-audio:$value')).toString();

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
