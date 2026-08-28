import 'dart:async';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';

import '../../api/server_compatibility.dart';
import '../common/source_descriptor.dart';
import '../common/source_exception.dart';
import '../common/source_id.dart';
import '../common/source_lifecycle.dart';
import 'file_capabilities.dart';
import 'file_entry.dart';
import 'file_operation.dart';
import 'file_source.dart';

class SmbPath {
  const SmbPath({required this.share, required this.relativePath});

  final String share;
  final String relativePath;

  String get normalizedPath =>
      relativePath.isEmpty ? share : '$share/$relativePath';
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
      if (parts.length < 2) {
        throw ArgumentError.value(value, 'value', 'SMB UNC 路径缺少共享名');
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
    throw ArgumentError.value(value, 'value', 'SMB 路径缺少共享名');
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

/// SMB2/3 file source backed by [Smb2Pool].
class SmbFileSource
    implements
        FileSource,
        FileBrowseCapability,
        FileTransferCapability,
        FileMutationCapability,
        FileAccessCapability,
        SourceLifecycle {
  SmbFileSource._(this.pool, this._sourceId, this._descriptor, this._rootPath);

  final Smb2Pool pool;
  final SourceId _sourceId;
  final SourceDescriptor _descriptor;
  final String _rootPath;

  static Future<SmbFileSource> connect({
    required String id,
    required String name,
    required SmbConnectionOptions options,
    String? serverId,
  }) async {
    final smbPath = parseSmbPath(options.path);
    final pool = await Smb2Pool.connect(
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
    return SmbFileSource._(
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
      smbPath.relativePath,
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
      final entries = await pool.listDirectory(_remotePath(value));
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
      final stat = await pool.stat(_remotePath(value));
      return _entry(value, _fileName(value), stat);
    } catch (error) {
      throw _error('SMB 文件信息读取失败', error);
    }
  }

  @override
  Future<bool> exists(FilePath path) async {
    final value = _checkPath(path);
    try {
      return await pool.exists(_remotePath(value));
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
  }) {
    final value = _checkPath(path);
    return pool
        .streamFile(
          _remotePath(value),
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
      await pool.streamWrite(_remotePath(path), chunks);
    } catch (error) {
      throw _error('SMB 文件上传失败', error);
    }
  }

  @override
  Future<FilePath> createDirectory(FilePath parent, String name) async {
    final parentPath = _checkPath(parent);
    final destination = joinRelativeFilePath(
      parentPath,
      normalizeFileName(name),
    );
    try {
      await pool.mkdir(_remotePath(destination));
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
      final remoteValue = _remotePath(value);
      final info = await pool.stat(remoteValue);
      if (!info.isDirectory) {
        await pool.deleteFile(remoteValue);
        return;
      }
      if (options.recursive) {
        for (final child in await pool.listDirectory(remoteValue)) {
          await delete(
            FilePath(
              sourceId: _sourceId,
              value: joinRelativeFilePath(value, child.name),
            ),
            options: options,
          );
        }
      }
      await pool.rmdir(remoteValue);
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
      if (!overwrite && await exists(destination)) {
        throw const FileSourceException('目标路径已存在', code: 'already_exists');
      }
      if (overwrite && await exists(destination)) {
        await delete(
          destination,
          options: const FileDeleteOptions(recursive: true),
        );
      }
      await pool.rename(_remotePath(oldPath), _remotePath(newPath));
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
  Future<void> dispose() => pool.disconnect();

  String _checkPath(FilePath path) {
    if (path.sourceId != _sourceId) {
      throw FileSourceException('路径不属于当前 SMB 来源：${path.sourceId.value}');
    }
    return normalizeRelativeFilePath(path.value);
  }

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

String _smbEndpoint(String host, int port, String share) =>
    'smb://${_smbHost(host, port)}/$share';

String _fileName(String value) {
  final normalized = normalizeRelativeFilePath(value);
  final separator = normalized.lastIndexOf('/');
  return separator < 0 ? normalized : normalized.substring(separator + 1);
}
