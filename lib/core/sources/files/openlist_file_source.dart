import 'dart:async';

import 'package:dio/dio.dart';

import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import '../common/source_lifecycle.dart';
import 'file_capabilities.dart';
import 'file_entry.dart';
import 'file_operation.dart';
import 'file_source.dart';
import 'openlist_api.dart';

/// OpenList（AList v3 兼容）文件源。
///
/// 路径语义与 WebDAV 一致（以 `/` 开头的绝对路径）；浏览、传输、
/// 变更和直连访问全部通过 OpenList REST API 完成。
class OpenListFileSource
    implements
        FileSource,
        FileBrowseCapability,
        FileTransferCapability,
        FileMutationCapability,
        FileAccessCapability,
        FileRangeAccessCapability,
        SourceLifecycle {
  OpenListFileSource._(this.client, this._sourceId, this._descriptor);

  final OpenListClient client;
  final SourceId _sourceId;
  final SourceDescriptor _descriptor;

  static Future<OpenListFileSource> connect({
    required String id,
    required String name,
    required OpenListConnectionOptions options,
    String? serverId,
  }) async {
    final root = normalizeWebDavPath(options.path);
    final client = OpenListClient(options);
    try {
      await client.ensureAuthenticated();
      final rootInfo = await client.get(root);
      if (!rootInfo.isDir) {
        throw const FileSourceException('OpenList 根路径必须是目录');
      }
    } catch (error) {
      await client.dispose();
      if (error is SourceException) rethrow;
      throw _error('OpenList 连接失败', error);
    }
    final sourceId = SourceId.of(id);
    return OpenListFileSource._(
      client,
      sourceId,
      SourceDescriptor(
        id: sourceId,
        kind: SourceKind.openList,
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
  Future<DirectoryListing> listDirectory(
    FilePath path, {
    bool refresh = false,
  }) async {
    final value = _checkPath(path);
    try {
      if (refresh) {
        client.clearDirectAccessCache();
      }
      final entries = await client.listDirectory(value, refresh: refresh);
      return DirectoryListing(
        currentPath: FilePath(sourceId: _sourceId, value: value),
        parentPath: value == '/'
            ? null
            : FilePath(sourceId: _sourceId, value: _parentPath(value)),
        breadcrumbs: buildBreadcrumbs(
          FilePath(sourceId: _sourceId, value: value),
          webDav: true,
        ),
        entries: [
          for (final entry in entries)
            if (_isValidEntryName(entry.name)) _entry(value, entry),
        ],
      );
    } catch (error) {
      throw _error('OpenList 目录读取失败', error);
    }
  }

  @override
  Future<FileEntry> stat(FilePath path) async {
    final value = _checkPath(path);
    try {
      final file = await client.get(value);
      return _statEntry(file, value);
    } catch (error) {
      throw _error('OpenList 文件信息读取失败', error);
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
      final response = await _openStreamWithRetry(
        value,
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 500;
      if (status >= 400) {
        await _cancelResponseStream(response.data);
        throw FileSourceException('OpenList 下载失败', statusCode: status);
      }
      final body = response.data;
      if (body == null) return;
      final total = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      yield* _streamResponseBody(
        body,
        total: total,
        onProgress: options.onProgress,
      );
    } catch (error) {
      if (cancelToken.isCancelled) {
        throw const FileSourceException('下载已取消', code: 'canceled');
      }
      if (error is FileSourceException) rethrow;
      throw _error('OpenList 文件下载失败', error);
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
      throw ArgumentError('OpenList 区间读取参数无效');
    }
    if (length == 0) return Future.value(const Stream<List<int>>.empty());
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
      final response = await _openStreamWithRetry(
        value,
        rangeStart: offset,
        rangeEnd: end + 1,
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 500;
      if (status == 200) {
        // 部分网盘忽略 Range。让播放代理回落到完整落地，而不是悄悄
        // 返回错误的字节区间。
        await _cancelResponseStream(response.data);
        throw UnsupportedError('OpenList 服务不支持 Range');
      }
      if (status == 416) {
        await _cancelResponseStream(response.data);
        throw const FileSourceException(
          'OpenList 区间超出文件范围',
          statusCode: 416,
        );
      }
      if (status != 206) {
        await _cancelResponseStream(response.data);
        throw FileSourceException('OpenList 区间读取失败', statusCode: status);
      }
      final body = response.data;
      if (body == null) {
        throw UnsupportedError('OpenList 区间响应缺少数据');
      }
      final contentRange = response.headers.value('content-range');
      if (!_matchesRange(contentRange, offset: offset, end: end)) {
        await _cancelResponseStream(body);
        throw UnsupportedError('OpenList 未返回可靠的 Content-Range');
      }
      final contentLength = response.headers.value('content-length');
      final declaredLength = int.tryParse(contentLength ?? '');
      if (declaredLength != null && declaredLength != length) {
        await _cancelResponseStream(body);
        throw UnsupportedError('OpenList Content-Length 与区间不一致');
      }
      return _streamResponseBody(body, expectedLength: length);
    } catch (error) {
      if (cancelToken.isCancelled) {
        throw const FileSourceException('下载已取消', code: 'canceled');
      }
      if (error is UnsupportedError || error is FileSourceException) rethrow;
      throw _error('OpenList 区间读取失败', error);
    }
  }

  @override
  Future<void> upload(FileUploadRequest request) async {
    final value = _checkPath(request.destination);
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
      await client.upload(
        value,
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
      throw _error('OpenList 文件上传失败', error);
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
      throw _error('OpenList 创建目录失败', error);
    }
  }

  @override
  Future<void> delete(
    FilePath path, {
    FileDeleteOptions options = const FileDeleteOptions(),
  }) async {
    final value = _checkPath(path);
    if (value == '/') {
      throw const FileSourceException('不能删除 OpenList 根目录');
    }
    try {
      await client.remove(_parentPath(value), [_lastName(value)]);
    } catch (error) {
      throw _error('OpenList 删除失败', error);
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
    if (oldPath == newPath) return;
    try {
      if (!overwrite && await exists(destination)) {
        throw const FileSourceException('目标路径已存在', code: 'already_exists');
      }
      await client.move(_parentPath(oldPath), _parentPath(newPath), [
        _lastName(oldPath),
      ]);
    } catch (error) {
      if (error is FileSourceException) rethrow;
      throw _error('OpenList 移动失败', error);
    }
  }

  @override
  Future<void> rename(
    FilePath source,
    String newName, {
    bool overwrite = false,
  }) async {
    final value = _checkPath(source);
    final normalizedName = normalizeFileName(newName);
    try {
      if (!overwrite &&
          await exists(
            FilePath(
              sourceId: _sourceId,
              value: joinWebDavPath(_parentPath(value), normalizedName),
            ),
          )) {
        throw const FileSourceException('目标文件已存在', code: 'already_exists');
      }
      await client.rename(value, normalizedName);
    } catch (error) {
      if (error is FileSourceException) rethrow;
      throw _error('OpenList 重命名失败', error);
    }
  }

  @override
  Future<FileAccess> resolveAccess(FilePath path) async {
    final value = _checkPath(path);
    final entry = await stat(path);
    if (!entry.isFile) {
      throw const FileSourceException('目录不能作为文件访问');
    }
    final access = await client.resolveDirectAccess(value);
    return FileAccess(
      uri: access.uri,
      size: entry.size,
      mimeType: entry.mimeType,
      headers: access.headers,
      openStream: () => download(path),
    );
  }

  @override
  Future<void> dispose() => client.dispose();

  /// 云盘直链可能过期；首次失败时清空 fs/get 缓存后重试一次。
  Future<Response<ResponseBody>> _openStreamWithRetry(
    String value, {
    int? rangeStart,
    int? rangeEnd,
    CancelToken? cancelToken,
  }) async {
    var response = await client.openStream(
      value,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      cancelToken: cancelToken,
    );
    if ((response.statusCode ?? 500) >= 400) {
      await _cancelResponseStream(response.data);
      client.clearDirectAccessCache();
      response = await client.openStream(
        value,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        cancelToken: cancelToken,
      );
    }
    return response;
  }

  String _checkPath(FilePath path) {
    if (path.sourceId != _sourceId) {
      throw FileSourceException(
        '路径不属于当前 OpenList 来源：${path.sourceId.value}',
      );
    }
    return normalizeWebDavPath(path.value);
  }

  bool _isValidEntryName(String name) {
    return name.isNotEmpty && name != '.' && name != '..' && !name.contains('/');
  }

  FileEntry _entry(String dirPath, OpenListEntry entry) => FileEntry(
    path: FilePath(sourceId: _sourceId, value: joinWebDavPath(dirPath, entry.name)),
    name: entry.name,
    type: entry.isDir ? FileEntryType.directory : FileEntryType.file,
    size: entry.size,
    modifiedAt: entry.modified,
    isHidden: entry.name.startsWith('.'),
    attributes: entry.sign.isEmpty
        ? const <String, Object?>{}
        : <String, Object?>{'etag': entry.sign},
  );

  FileEntry _statEntry(OpenListFile file, String value) => FileEntry(
    path: FilePath(sourceId: _sourceId, value: value),
    name: file.name.isNotEmpty ? file.name : _lastName(value),
    type: file.isDir ? FileEntryType.directory : FileEntryType.file,
    size: file.size,
    modifiedAt: file.modified,
    isHidden: _lastName(value).startsWith('.'),
    attributes: file.sign.isEmpty
        ? const <String, Object?>{}
        : <String, Object?>{'etag': file.sign},
  );

  static FileSourceException _error(String message, Object error) {
    if (error is FileSourceException) return error;
    if (error is OpenListException) {
      return FileSourceException(
        '$message：${error.message}',
        statusCode: _statusCodeOf(error),
        cause: error,
      );
    }
    if (error is DioException) {
      return FileSourceException(
        message,
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
    return FileSourceException(message, cause: error);
  }

  static int? _statusCodeOf(OpenListException error) {
    if (error.isUnauthorized) return 401;
    if (error.isNotFound) return 404;
    final code = error.code;
    if (code == null || code == 200) return error.statusCode;
    return code;
  }

  Stream<List<int>> _streamResponseBody(
    ResponseBody body, {
    int? expectedLength,
    int? total,
    FileProgressCallback? onProgress,
  }) async* {
    var received = 0;
    await for (final chunk in body.stream) {
      received += chunk.length;
      if (expectedLength != null && received > expectedLength) {
        throw const FileSourceException('OpenList 返回的区间数据过长');
      }
      yield chunk;
      onProgress?.call(
        FileTransferProgress(transferred: received, total: total ?? expectedLength),
      );
    }
    if (expectedLength != null && received != expectedLength) {
      throw const FileSourceException('OpenList 返回的区间数据不完整');
    }
  }

  Future<void> _cancelResponseStream(ResponseBody? body) async {
    if (body == null) return;
    try {
      await body.stream.listen((_) {}).cancel();
    } catch (_) {
      // 连接可能已经关闭。
    }
  }

  bool _matchesRange(String? value, {required int offset, required int end}) {
    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
      caseSensitive: false,
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return false;
    return int.tryParse(match.group(1)!) == offset &&
        int.tryParse(match.group(2)!) == end;
  }
}

String _parentPath(String value) {
  final path = normalizeWebDavPath(value);
  if (path == '/') return '/';
  final withoutTrailing = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final separator = withoutTrailing.lastIndexOf('/');
  return separator <= 0 ? '/' : withoutTrailing.substring(0, separator);
}

String _lastName(String value) {
  final path = normalizeWebDavPath(value);
  if (path == '/') return '/';
  final withoutTrailing = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return withoutTrailing.substring(withoutTrailing.lastIndexOf('/') + 1);
}
