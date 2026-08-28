import 'dart:async';

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import '../common/source_lifecycle.dart';
import 'file_capabilities.dart';
import 'file_entry.dart';
import 'file_operation.dart';
import 'file_source.dart';

class WebDavConnectionOptions {
  const WebDavConnectionOptions({
    required this.uri,
    required this.port,
    this.user = '',
    this.password = '',
    this.timeoutMilliseconds = 30 * 1000,
  });

  final String uri;
  final int port;
  final String user;
  final String password;
  final int timeoutMilliseconds;
}

/// WebDAV file source backed by `webdav_client`.
class WebDavFileSource
    implements
        FileSource,
        FileBrowseCapability,
        FileTransferCapability,
        FileMutationCapability,
        FileAccessCapability,
        FileRangeAccessCapability,
        SourceLifecycle {
  WebDavFileSource._(this.client, this._sourceId, this._descriptor);

  final webdav.Client client;
  final SourceId _sourceId;
  final SourceDescriptor _descriptor;

  static Future<WebDavFileSource> connect({
    required String id,
    required String name,
    required WebDavConnectionOptions options,
    String? serverId,
  }) async {
    final client = webdav.newClient(
      options.uri,
      user: options.user,
      password: options.password,
    );
    client.setConnectTimeout(options.timeoutMilliseconds);
    client.setSendTimeout(options.timeoutMilliseconds);
    client.setReceiveTimeout(options.timeoutMilliseconds);
    await client.ping();
    final sourceId = SourceId.of(id);
    return WebDavFileSource._(
      client,
      sourceId,
      SourceDescriptor(
        id: sourceId,
        kind: SourceKind.webDav,
        name: name,
        serverId: serverId,
        endpoint: options.uri,
      ),
    );
  }

  @override
  SourceDescriptor get descriptor => _descriptor;

  @override
  Set<FileCapability> get capabilities => const {
    FileCapability.browse,
    FileCapability.transfer,
    FileCapability.mutation,
    FileCapability.access,
  };

  @override
  bool supports(FileCapability capability) => capabilities.contains(capability);

  @override
  Future<DirectoryListing> listDirectory(FilePath path) async {
    final value = _checkPath(path);
    try {
      final files = await client.readDir(value);
      return DirectoryListing(
        currentPath: FilePath(sourceId: _sourceId, value: value),
        parentPath: value == '/'
            ? null
            : FilePath(sourceId: _sourceId, value: _parentWebDavPath(value)),
        breadcrumbs: buildBreadcrumbs(
          FilePath(sourceId: _sourceId, value: value),
          webDav: true,
        ),
        entries: files
            .map(
              (file) => _entry(
                joinWebDavPath(value, file.name ?? ''),
                file.name ?? '',
                file,
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      throw _error('WebDAV 目录读取失败', error);
    }
  }

  @override
  Future<FileEntry> stat(FilePath path) async {
    final value = _checkPath(path);
    try {
      final file = await client.readProps(value);
      return _entry(value, file.name ?? _webDavName(value), file);
    } catch (error) {
      throw _error('WebDAV 文件信息读取失败', error);
    }
  }

  @override
  Future<bool> exists(FilePath path) async {
    try {
      await stat(path);
      return true;
    } catch (error) {
      if (error is FileSourceException && error.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<FileEntry> validatePath(FilePath path) => stat(path);

  @override
  Stream<List<int>> download(
    FilePath path, {
    FileTransferOptions options = const FileTransferOptions(),
  }) async* {
    final value = _checkPath(path);
    if (options.cancellation?.isCancelled == true) {
      throw const FileSourceException('下载已取消', code: 'canceled');
    }
    final cancelToken = CancelToken();
    final cancellation = options.cancellation;
    if (cancellation != null) {
      unawaited(
        cancellation.whenCancelled.then((reason) {
          if (!cancelToken.isCancelled) cancelToken.cancel(reason);
        }),
      );
    }
    try {
      final response = await client.c.req<ResponseBody>(
        client,
        'GET',
        value,
        optionsHandler: (request) => request.responseType = ResponseType.stream,
        onReceiveProgress: (received, total) => options.onProgress?.call(
          FileTransferProgress(
            transferred: received,
            total: total > 0 ? total : null,
          ),
        ),
        cancelToken: cancelToken,
      );
      if ((response.statusCode ?? 500) >= 400) {
        response.data?.close();
        throw FileSourceException(
          'WebDAV 下载失败',
          statusCode: response.statusCode,
        );
      }
      final body = response.data;
      if (body == null) return;
      yield* _streamResponseBody(body);
    } catch (error) {
      if (cancelToken.isCancelled) {
        throw const FileSourceException('下载已取消', code: 'canceled');
      }
      if (error is FileSourceException) rethrow;
      throw _error('WebDAV 文件下载失败', error);
    }
  }

  @override
  Future<Stream<List<int>>> openRange(
    FilePath path, {
    required int offset,
    required int length,
    FileTransferOptions options = const FileTransferOptions(),
  }) async {
    if (offset < 0 || length < 0) {
      throw ArgumentError('WebDAV 区间读取参数无效');
    }
    if (length == 0) return const Stream<List<int>>.empty();
    final value = _checkPath(path);
    if (options.cancellation?.isCancelled == true) {
      throw const FileSourceException('下载已取消', code: 'canceled');
    }
    final cancelToken = CancelToken();
    final cancellation = options.cancellation;
    if (cancellation != null) {
      unawaited(
        cancellation.whenCancelled.then((reason) {
          if (!cancelToken.isCancelled) cancelToken.cancel(reason);
        }),
      );
    }
    final end = offset + length - 1;
    try {
      final response = await client.c.req<ResponseBody>(
        client,
        'GET',
        value,
        optionsHandler: (request) {
          request.responseType = ResponseType.stream;
          request.headers?['Range'] = 'bytes=$offset-$end';
        },
        onReceiveProgress: (received, total) => options.onProgress?.call(
          FileTransferProgress(
            transferred: received,
            total: total > 0 ? total : length,
          ),
        ),
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 500;
      if (status == 200) {
        // Some WebDAV servers ignore Range. Let the playback proxy spool a
        // complete local copy instead of silently returning the wrong bytes.
        response.data?.close();
        throw UnsupportedError('WebDAV 服务不支持 Range');
      }
      if (status == 416) {
        response.data?.close();
        throw const FileSourceException(
          'WebDAV 区间超出文件范围',
          statusCode: 416,
        );
      }
      if (status != 206 || status >= 400) {
        response.data?.close();
        throw FileSourceException('WebDAV 区间读取失败', statusCode: status);
      }
      final body = response.data;
      if (body == null) {
        throw const FileSourceException('WebDAV 区间响应缺少数据');
      }
      final contentRange = response.headers.value('content-range');
      if (!_matchesRange(contentRange, offset: offset, end: end)) {
        body.close();
        throw const FileSourceException('WebDAV 未返回请求的 Content-Range');
      }
      final contentLength = response.headers.value('content-length');
      final declaredLength = int.tryParse(contentLength ?? '');
      if (declaredLength != null && declaredLength != length) {
        body.close();
        throw const FileSourceException('WebDAV Content-Length 与区间不一致');
      }
      return _streamResponseBody(body, expectedLength: length);
    } catch (error) {
      if (cancelToken.isCancelled) {
        throw const FileSourceException('下载已取消', code: 'canceled');
      }
      if (error is UnsupportedError || error is FileSourceException) rethrow;
      throw _error('WebDAV 区间读取失败', error);
    }
  }

  @override
  Future<void> upload(FileUploadRequest request) async {
    final path = _checkPath(request.destination);
    final options = request.options;
    if (!options.overwrite && await exists(request.destination)) {
      throw const FileSourceException('目标文件已存在', code: 'already_exists');
    }
    if (options.cancellation?.isCancelled == true) {
      throw const FileSourceException('上传已取消', code: 'canceled');
    }
    final cancelToken = CancelToken();
    if (options.cancellation != null) {
      unawaited(
        options.cancellation!.whenCancelled.then((reason) {
          if (!cancelToken.isCancelled) cancelToken.cancel(reason);
        }),
      );
    }
    try {
      await client.c.wdWriteWithStream(
        client,
        path,
        request.data,
        request.length,
        onProgress: (received, total) => options.onProgress?.call(
          FileTransferProgress(
            transferred: received,
            total: total > 0 ? total : request.length,
          ),
        ),
        cancelToken: cancelToken,
      );
    } catch (error) {
      if (cancelToken.isCancelled) {
        throw const FileSourceException('上传已取消', code: 'canceled');
      }
      throw _error('WebDAV 文件上传失败', error);
    }
  }

  @override
  Future<FilePath> createDirectory(FilePath parent, String name) async {
    final parentPath = _checkPath(parent);
    final destination = joinWebDavPath(parentPath, normalizeFileName(name));
    try {
      await client.mkdir(destination);
      return FilePath(sourceId: _sourceId, value: destination);
    } catch (error) {
      throw _error('WebDAV 创建目录失败', error);
    }
  }

  @override
  Future<void> delete(
    FilePath path, {
    FileDeleteOptions options = const FileDeleteOptions(),
  }) async {
    final value = _checkPath(path);
    try {
      final entry = await stat(path);
      if (entry.isDirectory && options.recursive) {
        final listing = await listDirectory(path);
        for (final child in listing.entries) {
          await delete(child.path, options: options);
        }
      }
      await client.remove(entry.isDirectory ? '$value/' : value);
    } catch (error) {
      throw _error('WebDAV 删除失败', error);
    }
  }

  @override
  Future<void> move(
    FilePath source,
    FilePath destination, {
    bool overwrite = false,
  }) async {
    final oldPath = _checkPath(source);
    final newPath = _checkPath(destination);
    try {
      if (!overwrite && await exists(destination)) {
        throw const FileSourceException('目标路径已存在', code: 'already_exists');
      }
      await client.rename(oldPath, newPath, overwrite);
    } catch (error) {
      if (error is FileSourceException) rethrow;
      throw _error('WebDAV 移动失败', error);
    }
  }

  @override
  Future<void> rename(
    FilePath source,
    String newName, {
    bool overwrite = false,
  }) {
    final value = _checkPath(source);
    final normalizedName = normalizeFileName(newName);
    final parent = _parentWebDavPath(value);
    return move(
      source,
      FilePath(
        sourceId: _sourceId,
        value: joinWebDavPath(parent, normalizedName),
      ),
      overwrite: overwrite,
    );
  }

  @override
  Future<FileAccess> resolveAccess(FilePath path) async {
    final entry = await stat(path);
    if (!entry.isFile) {
      throw const FileSourceException('目录不能作为文件访问');
    }
    return FileAccess(
      size: entry.size,
      mimeType: entry.mimeType,
      openStream: () => download(path),
    );
  }

  @override
  Future<void> dispose() async {
    client.c.close(force: true);
  }

  String _checkPath(FilePath path) {
    if (path.sourceId != _sourceId) {
      throw FileSourceException('路径不属于当前 WebDAV 来源：${path.sourceId.value}');
    }
    return normalizeWebDavPath(path.value);
  }

  FileEntry _entry(String value, String name, webdav.File file) => FileEntry(
    path: FilePath(sourceId: _sourceId, value: value),
    name: name,
    type: file.isDir == true ? FileEntryType.directory : FileEntryType.file,
    size: file.size,
    modifiedAt: file.mTime,
    createdAt: file.cTime,
    mimeType: file.mimeType,
    attributes: {'etag': file.eTag},
  );

  FileSourceException _error(String message, Object error) {
    if (error is FileSourceException) return error;
    if (error is DioException) {
      return FileSourceException(
        message,
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
    return FileSourceException(message, cause: error);
  }

  Stream<List<int>> _streamResponseBody(
    ResponseBody body, {
    int? expectedLength,
  }) async* {
    var received = 0;
    try {
      await for (final chunk in body.stream) {
        received += chunk.length;
        if (expectedLength != null && received > expectedLength) {
          throw const FileSourceException('WebDAV 返回的区间数据过长');
        }
        yield chunk;
      }
      if (expectedLength != null && received != expectedLength) {
        throw const FileSourceException('WebDAV 返回的区间数据不完整');
      }
    } finally {
      body.close();
    }
  }

  bool _matchesRange(
    String? value, {
    required int offset,
    required int end,
  }) {
    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
      caseSensitive: false,
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return false;
    return int.tryParse(match.group(1)!) == offset &&
        int.tryParse(match.group(2)!) == end;
  }
}

String _parentWebDavPath(String value) {
  final path = normalizeWebDavPath(value);
  if (path == '/') return '/';
  final withoutTrailing = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final separator = withoutTrailing.lastIndexOf('/');
  return separator <= 0 ? '/' : withoutTrailing.substring(0, separator);
}

String _webDavName(String value) {
  final path = normalizeWebDavPath(value);
  if (path == '/') return '/';
  final withoutTrailing = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return withoutTrailing.substring(withoutTrailing.lastIndexOf('/') + 1);
}
