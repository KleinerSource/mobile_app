import 'dart:async';
import 'dart:typed_data';

import '../../api/server_compatibility.dart';
import '../../platform/app_log_store.dart';
import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import '../common/source_lifecycle.dart';
import 'file_capabilities.dart';
import 'file_entry.dart';
import 'file_operation.dart';
import 'file_source.dart';
import 'smb2_api.dart';

class SmbPath {
  const SmbPath({required this.share, required this.relativePath});

  final String share;
  final String relativePath;

  bool get isServerRoot => share.isEmpty;

  String get normalizedPath => isServerRoot
      ? '/'
      : relativePath.isEmpty
      ? share
      : '$share/$relativePath';
}

SmbPath parseSmbPath(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    throw ArgumentError.value(value, 'value', 'SMB 路径不能为空');
  }

  final uri = Uri.tryParse(raw);
  List<String> parts;
  if (uri?.scheme.toLowerCase() == 'smb') {
    parts = uri!.pathSegments;
  } else {
    var normalized = raw.replaceAll('\\', '/');
    final unc = normalized.startsWith('//');
    if (unc) normalized = normalized.substring(2);
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    parts = normalized.split('/');
    if (unc) {
      if (parts.length == 1) {
        return const SmbPath(share: '', relativePath: '');
      }
      parts = parts.sublist(1);
    }
  }

  final normalizedParts = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      throw ArgumentError.value(value, 'value', 'SMB 路径不能包含 ..');
    }
    normalizedParts.add(part);
  }
  if (normalizedParts.isEmpty) {
    return const SmbPath(share: '', relativePath: '');
  }
  return SmbPath(
    share: normalizedParts.first,
    relativePath: normalizedParts.skip(1).join('/'),
  );
}

class SmbConnectionOptions {
  const SmbConnectionOptions({
    required this.host,
    this.port = defaultSmbPort,
    required this.path,
    this.user,
    this.password,
    this.domain,
    this.workers = 2,
    this.timeoutSeconds = 30,
    this.seal = false,
    this.signing = false,
    this.version = Smb2Version.any,
  });

  final String host;
  final int port;
  final String path;
  final String? user;
  final String? password;
  final String? domain;
  final int workers;
  final int timeoutSeconds;
  final bool seal;
  final bool signing;
  final Smb2Version version;
}

class _SmbTarget {
  const _SmbTarget({
    required this.share,
    required this.pool,
    required this.path,
  });

  final String share;
  final Smb2Pool pool;
  final String path;
}

/// SMB2/3 file source backed by [Smb2Pool].
class SmbFileSource
    implements
        FileSource,
        FileBrowseCapability,
        FileTransferCapability,
        FileMutationCapability,
        FileAccessCapability,
        FileRangeAccessCapability,
        SourceLifecycle {
  SmbFileSource._(
    this.pool,
    this._sourceId,
    this._descriptor,
    this._share,
    this._rootPath,
    this._options,
  ) {
    final share = _share;
    final connectedPool = pool;
    if (share != null && connectedPool != null) {
      _sharePools[share] = Future<Smb2Pool>.value(connectedPool);
    }
  }

  final Smb2Pool? pool;
  final SourceId _sourceId;
  final SourceDescriptor _descriptor;
  final String? _share;
  final String _rootPath;
  final SmbConnectionOptions _options;
  final Map<String, Future<Smb2Pool>> _sharePools =
      <String, Future<Smb2Pool>>{};
  Future<List<Smb2ShareInfo>>? _serverSharesFuture;

  static Future<SmbFileSource> connect({
    required String id,
    required String name,
    required SmbConnectionOptions options,
    String? serverId,
  }) async {
    final smbPath = parseSmbPath(options.path);
    final pool = smbPath.isServerRoot
        ? null
        : await Smb2Pool.connect(
            host: _smbHost(options.host, options.port),
            share: smbPath.share,
            user: options.user,
            password: options.password,
            domain: options.domain,
            workers: options.workers,
            timeoutSeconds: options.timeoutSeconds,
            seal: options.seal,
            signing: options.signing,
            version: options.version,
          );
    final sourceId = SourceId.of(id);
    final source = SmbFileSource._(
      pool,
      sourceId,
      SourceDescriptor(
        id: sourceId,
        kind: SourceKind.smb,
        name: name,
        serverId: serverId,
        endpoint: _smbEndpoint(
          options.host,
          options.port,
          smbPath.normalizedPath,
        ),
      ),
      smbPath.isServerRoot ? null : smbPath.share,
      smbPath.relativePath,
      options,
    );
    if (smbPath.isServerRoot) await source._listServerShares();
    return source;
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
      if (_share == null && value.isEmpty) {
        final shares = await _listServerShares();
        return DirectoryListing(
          currentPath: FilePath(sourceId: _sourceId, value: value),
          parentPath: null,
          breadcrumbs: buildBreadcrumbs(
            FilePath(sourceId: _sourceId, value: value),
            webDav: false,
          ),
          entries: shares
              .where((share) => share.isDisk && share.name.isNotEmpty)
              .map(_shareEntry)
              .toList(growable: false),
        );
      }
      final target = await _target(value);
      final entries = await target.pool.listDirectory(target.path);
      return DirectoryListing(
        currentPath: FilePath(sourceId: _sourceId, value: value),
        parentPath: value.isEmpty
            ? null
            : FilePath(
                sourceId: _sourceId,
                value: value.contains('/')
                    ? value.substring(0, value.lastIndexOf('/'))
                    : '',
              ),
        breadcrumbs: buildBreadcrumbs(
          FilePath(sourceId: _sourceId, value: value),
          webDav: false,
        ),
        entries: entries
            .map(
              (entry) => _entry(
                joinRelativeFilePath(value, entry.name),
                entry.name,
                entry.stat,
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      throw _error('SMB 目录读取失败', error);
    }
  }

  @override
  Future<FileEntry> stat(FilePath path) async {
    final value = _checkPath(path);
    try {
      if (_share == null && value.isEmpty) {
        return FileEntry(
          path: FilePath(sourceId: _sourceId, value: value),
          name: '/',
          type: FileEntryType.directory,
        );
      }
      final target = await _target(value);
      final stat = await target.pool.stat(target.path);
      return _entry(value, _fileName(value), stat);
    } catch (error) {
      throw _error('SMB 文件信息读取失败', error);
    }
  }

  @override
  Future<bool> exists(FilePath path) async {
    final value = _checkPath(path);
    try {
      if (_share == null && value.isEmpty) return true;
      final target = await _target(value);
      return await target.pool.exists(target.path);
    } catch (error) {
      throw _error('SMB 路径检查失败', error);
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
    final target = await _target(value);
    appLog(
      '[SmbFileSource] 开始完整流: path=${path.stableKey} '
      'remote=${target.share}/${target.path}',
    );
    yield* target.pool
        .streamFile(
          target.path,
          onProgress: (received, total) => options.onProgress?.call(
            FileTransferProgress(
              transferred: received,
              total: total > 0 ? total : null,
            ),
          ),
          isCanceled: () => options.cancellation?.isCancelled ?? false,
        )
        .cast<List<int>>();
  }

  @override
  Future<Stream<List<int>>> openRange(
    FilePath path, {
    required int offset,
    required int length,
    FileTransferOptions options = const FileTransferOptions(),
  }) async {
    if (offset < 0 || length < 0) {
      throw ArgumentError('SMB 区间读取参数无效');
    }
    if (length == 0) return const Stream<List<int>>.empty();
    final value = _checkPath(path);
    final target = await _target(value);
    appLog(
      '[SmbFileSource] 建立区间流: path=${path.stableKey} '
      'remote=${target.share}/${target.path} offset=$offset length=$length',
    );
    return _readRange(
      target.pool,
      target.path,
      offset: offset,
      length: length,
      cancellation: options.cancellation,
      onProgress: options.onProgress,
    );
  }

  Stream<List<int>> _readRange(
    Smb2Pool pool,
    String path, {
    required int offset,
    required int length,
    FileCancellationToken? cancellation,
    FileProgressCallback? onProgress,
  }) async* {
    const chunkSize = 1024 * 1024;
    var current = offset;
    var remaining = length;
    var transferred = 0;
    while (remaining > 0) {
      if (cancellation?.isCancelled == true) {
        throw const FileSourceException('下载已取消', code: 'canceled');
      }
      final requested = remaining < chunkSize ? remaining : chunkSize;
      final chunk = await pool.readFileRange(
        path,
        offset: current,
        length: requested,
      );
      if (chunk.isEmpty) {
        throw const FileSourceException('SMB 区间读取返回空数据');
      }
      appLog(
        '[SmbFileSource] 区间读取完成: remote=$path '
        'offset=$current length=${chunk.length}',
      );
      current += chunk.length;
      remaining -= chunk.length;
      transferred += chunk.length;
      onProgress?.call(
        FileTransferProgress(transferred: transferred, total: length),
      );
      yield chunk;
    }
  }

  @override
  Future<void> upload(FileUploadRequest request) async {
    final path = _checkPath(request.destination);
    final options = request.options;
    if (!options.overwrite && await exists(request.destination)) {
      throw const FileSourceException('目标文件已存在', code: 'already_exists');
    }
    var transferred = 0;
    final chunks = request.data.map((chunk) {
      if (options.cancellation?.isCancelled == true) {
        throw const FileSourceException('上传已取消', code: 'canceled');
      }
      final bytes = Uint8List.fromList(chunk);
      transferred += bytes.length;
      options.onProgress?.call(
        FileTransferProgress(transferred: transferred, total: request.length),
      );
      return bytes;
    });
    try {
      final target = await _target(path);
      await target.pool.streamWrite(target.path, chunks);
    } catch (error) {
      throw _error('SMB 文件上传失败', error);
    }
  }

  @override
  Future<FilePath> createDirectory(FilePath parent, String name) async {
    final parentPath = _checkPath(parent);
    if (_share == null && parentPath.isEmpty) {
      throw const FileSourceException('不能在 SMB 服务器根目录创建共享');
    }
    final destination = joinRelativeFilePath(
      parentPath,
      normalizeFileName(name),
    );
    try {
      final target = await _target(destination);
      await target.pool.mkdir(target.path);
      return FilePath(sourceId: _sourceId, value: destination);
    } catch (error) {
      throw _error('SMB 创建目录失败', error);
    }
  }

  @override
  Future<void> delete(
    FilePath path, {
    FileDeleteOptions options = const FileDeleteOptions(),
  }) async {
    final value = _checkPath(path);
    try {
      if (_share == null && value.isEmpty) {
        throw const FileSourceException('不能删除 SMB 服务器根目录');
      }
      final target = await _target(value);
      final info = await target.pool.stat(target.path);
      if (!info.isDirectory) {
        await target.pool.deleteFile(target.path);
        return;
      }
      if (options.recursive) {
        for (final child in await target.pool.listDirectory(target.path)) {
          await delete(
            FilePath(
              sourceId: _sourceId,
              value: joinRelativeFilePath(value, child.name),
            ),
            options: options,
          );
        }
      }
      await target.pool.rmdir(target.path);
    } catch (error) {
      throw _error('SMB 删除失败', error);
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
      final oldTarget = await _target(oldPath);
      final newTarget = await _target(newPath);
      if (oldTarget.share != newTarget.share) {
        throw const FileSourceException('SMB 不支持跨共享移动文件');
      }
      if (!overwrite && await exists(destination)) {
        throw const FileSourceException('目标路径已存在', code: 'already_exists');
      }
      if (overwrite && await exists(destination)) {
        await delete(
          destination,
          options: const FileDeleteOptions(recursive: true),
        );
      }
      await oldTarget.pool.rename(oldTarget.path, newTarget.path);
    } catch (error) {
      if (error is FileSourceException) rethrow;
      throw _error('SMB 移动失败', error);
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
    final separator = value.lastIndexOf('/');
    final parent = separator < 0 ? '' : value.substring(0, separator);
    return move(
      source,
      FilePath(
        sourceId: _sourceId,
        value: joinRelativeFilePath(parent, normalizedName),
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
    final pools = _sharePools.values.toList(growable: false);
    _sharePools.clear();
    for (final poolFuture in pools) {
      try {
        await (await poolFuture).disconnect();
      } catch (_) {
        // 连接失败的共享没有需要释放的连接，继续释放其余共享。
      }
    }
  }

  Future<List<Smb2ShareInfo>> _listServerShares() async {
    final cached = _serverSharesFuture;
    if (cached != null) return cached;
    final future = Smb2Pool.listSharesOn(
      host: _smbHost(_options.host, _options.port),
      user: _options.user,
      password: _options.password,
      domain: _options.domain,
      timeoutSeconds: _options.timeoutSeconds,
    );
    _serverSharesFuture = future;
    try {
      return await future;
    } catch (_) {
      if (identical(_serverSharesFuture, future)) _serverSharesFuture = null;
      rethrow;
    }
  }

  Future<Smb2Pool> _poolForShare(String share) {
    final cached = _sharePools[share];
    if (cached != null) return cached;
    late final Future<Smb2Pool> future;
    future = Smb2Pool.connect(
      host: _smbHost(_options.host, _options.port),
      share: share,
      user: _options.user,
      password: _options.password,
      domain: _options.domain,
      workers: _options.workers,
      timeoutSeconds: _options.timeoutSeconds,
      seal: _options.seal,
      signing: _options.signing,
      version: _options.version,
    );
    _sharePools[share] = future;
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_sharePools[share], future)) _sharePools.remove(share);
      },
    );
    return future;
  }

  Future<_SmbTarget> _target(String value) async {
    final normalized = normalizeRelativeFilePath(value);
    final configuredShare = _share;
    if (configuredShare != null) {
      return _SmbTarget(
        share: configuredShare,
        pool: await _poolForShare(configuredShare),
        path: _remotePath(normalized),
      );
    }
    if (normalized.isEmpty) {
      throw const FileSourceException('SMB 服务器根目录没有对应的共享');
    }
    final parts = normalized.split('/');
    final shareName = parts.first;
    return _SmbTarget(
      share: shareName,
      pool: await _poolForShare(shareName),
      path: parts.skip(1).join('/'),
    );
  }

  String _checkPath(FilePath path) {
    if (path.sourceId != _sourceId) {
      throw FileSourceException('路径不属于当前 SMB 来源：${path.sourceId.value}');
    }
    return normalizeRelativeFilePath(path.value);
  }

  FileEntry _shareEntry(Smb2ShareInfo share) => FileEntry(
    path: FilePath(sourceId: _sourceId, value: share.name),
    name: share.name,
    type: FileEntryType.directory,
  );

  String _remotePath(String value) {
    final normalized = normalizeRelativeFilePath(value);
    if (_rootPath.isEmpty || normalized.isEmpty) {
      return _rootPath.isEmpty ? normalized : _rootPath;
    }
    return normalizeRelativeFilePath('$_rootPath/$normalized');
  }

  FileEntry _entry(String value, String name, Smb2Stat stat) => FileEntry(
    path: FilePath(sourceId: _sourceId, value: value),
    name: name,
    type: stat.isDirectory ? FileEntryType.directory : FileEntryType.file,
    size: stat.size,
    modifiedAt: stat.modified,
    createdAt: stat.created,
  );

  FileSourceException _error(String message, Object error) {
    if (error is FileSourceException) return error;
    return FileSourceException(message, cause: error);
  }
}

String _smbHost(String host, int port) {
  if (port == 445) return host;
  if (host.contains(':') && !host.startsWith('[')) {
    return '[$host]:$port';
  }
  return '$host:$port';
}

String _smbEndpoint(String host, int port, String path) {
  final normalized = path == '/' ? '' : path;
  return 'smb://${_smbHost(host, port)}/$normalized';
}

String _fileName(String value) {
  final normalized = normalizeRelativeFilePath(value);
  final separator = normalized.lastIndexOf('/');
  return separator < 0 ? normalized : normalized.substring(separator + 1);
}
