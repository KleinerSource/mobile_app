import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/app_log_store.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_source_repository.dart';

/// A reference to a music cache download. Releasing the last reference cancels
/// an unfinished download, while completed files remain available for reuse.
class MusicCacheLease {
  MusicCacheLease._({required this.file, required void Function() release})
    : _release = release;

  final Future<File> file;
  final void Function() _release;
  var _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

class MusicCacheService {
  MusicCacheService({Directory? rootDirectory}) : _rootOverride = rootDirectory;

  static const _rootName = 'omm_music_cache';
  static const _filePrefix = 'music_';

  final Directory? _rootOverride;
  final Map<String, _MusicCacheTask> _tasks = {};
  final Map<String, int> _protectedPaths = {};
  Future<void> _operationQueue = Future<void>.value();

  /// Acquires a shared cache download for one exact source version.
  ///
  /// The key includes source, path, size and modification time. Therefore a
  /// changed remote file gets a new cache file instead of silently reusing an
  /// old one. Callers must release the returned lease when no longer needed.
  MusicCacheLease acquire({
    required FileSourceRepository repository,
    required FilePath path,
    int? size,
    DateTime? modifiedAt,
    String? pathExtension,
  }) {
    final key = _cacheKey(
      repository: repository,
      path: path,
      size: size,
      modifiedAt: modifiedAt,
      pathExtension: pathExtension,
    );
    final task = _tasks[key] ??= _MusicCacheTask();
    task.users++;
    if (!task.started) {
      task.started = true;
      task.future = _download(
        task,
        key: key,
        repository: repository,
        path: path,
        expectedSize: size,
        pathExtension: pathExtension,
      );
      unawaited(
        task.future.then<void>(
          (_) => _finishTask(key, task),
          onError: (Object error, StackTrace stackTrace) {
            _finishTask(key, task);
          },
        ),
      );
    }
    return MusicCacheLease._(
      file: task.future,
      release: () => _release(key, task),
    );
  }

  Future<int> usage() async {
    final directory = await _cacheDirectory();
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Cleans partial files left by a process that exited during a download.
  Future<void> cleanupStaleCache({
    Duration maxAge = const Duration(hours: 12),
  }) async {
    try {
      final directory = await _cacheDirectory();
      if (!await directory.exists()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.part')) continue;
        if (_protectedPaths.containsKey(entity.path)) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (error) {
          _log('过期 part 清理失败: ${entity.path} $error');
        }
      }
    } catch (error, stackTrace) {
      _log('过期音乐缓存清理失败: $error\n$stackTrace');
    }
  }

  /// Removes completed music cache files, but never removes a file currently
  /// held by a player or metadata reader.
  Future<void> clear() {
    return _enqueue(() async {
      final directory = await _cacheDirectory();
      if (!await directory.exists()) return;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || _protectedPaths.containsKey(entity.path)) {
          continue;
        }
        await _deleteQuietly(entity);
      }
    });
  }

  Future<File> _download(
    _MusicCacheTask task, {
    required String key,
    required FileSourceRepository repository,
    required FilePath path,
    required int? expectedSize,
    required String? pathExtension,
  }) async {
    final directory = await _cacheDirectory();
    final extension = _normalizeExtension(pathExtension);
    final digest = sha256.convert(utf8.encode(key)).toString();
    final finalFile = File(
      '${directory.path}${Platform.pathSeparator}$_filePrefix$digest.$extension',
    );
    final partialFile = File('${finalFile.path}.part');
    task.finalPath = finalFile.path;
    task.partialPath = partialFile.path;
    _protect(finalFile.path);
    _protect(partialFile.path);

    IOSink? sink;
    try {
      if (await finalFile.exists() &&
          (expectedSize == null || await finalFile.length() == expectedSize)) {
        _log('音乐缓存命中: ${path.stableKey}');
        return finalFile;
      }
      await _deleteQuietly(finalFile);
      await _deleteQuietly(partialFile);
      _log('开始音乐缓存: ${path.stableKey}');
      sink = partialFile.openWrite();
      await for (final chunk in repository.download(
        path,
        options: FileTransferOptions(cancellation: task.cancellation),
      )) {
        sink.add(chunk);
      }
      await sink.close();
      sink = null;
      if (task.cancellation.isCancelled) {
        throw StateError('音乐缓存下载已取消');
      }
      if (expectedSize != null && await partialFile.length() != expectedSize) {
        throw StateError('音乐缓存大小校验失败');
      }
      await partialFile.rename(finalFile.path);
      _log('音乐缓存完成: ${path.stableKey}');
      return finalFile;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      await _deleteQuietly(partialFile);
      rethrow;
    } finally {
      _unprotect(partialFile.path);
    }
  }

  Future<Directory> _cacheDirectory() async {
    final base = _rootOverride ?? await _applicationSupportDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}$_rootName',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _applicationSupportDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  String _cacheKey({
    required FileSourceRepository repository,
    required FilePath path,
    required int? size,
    required DateTime? modifiedAt,
    required String? pathExtension,
  }) {
    final modified = modifiedAt?.toUtc().toIso8601String() ?? '';
    final source = repository.source.descriptor;
    return [
      source.kind.name,
      source.id.value,
      path.stableKey,
      size?.toString() ?? '',
      modified,
      _normalizeExtension(pathExtension),
    ].join('\u0000');
  }

  String _normalizeExtension(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('.', '');
    if (normalized == null || normalized.isEmpty) return 'bin';
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    return safe.isEmpty ? 'bin' : safe;
  }

  void _finishTask(String key, _MusicCacheTask task) {
    task.completed = true;
    if (identical(_tasks[key], task)) _tasks.remove(key);
    if (task.users == 0) {
      final finalPath = task.finalPath;
      if (finalPath != null) _unprotect(finalPath);
    }
  }

  void _release(String key, _MusicCacheTask task) {
    if (task.users > 0) task.users--;
    if (task.users != 0) return;
    if (!task.completed) {
      task.cancellation.cancel('音乐缓存已无使用者');
      if (identical(_tasks[key], task)) _tasks.remove(key);
      return;
    }
    final finalPath = task.finalPath;
    if (finalPath != null) _unprotect(finalPath);
    if (identical(_tasks[key], task)) _tasks.remove(key);
  }

  void _protect(String path) {
    _protectedPaths[path] = (_protectedPaths[path] ?? 0) + 1;
  }

  void _unprotect(String path) {
    final count = _protectedPaths[path];
    if (count == null || count <= 1) {
      _protectedPaths.remove(path);
    } else {
      _protectedPaths[path] = count - 1;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationQueue.then((_) => action());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  void _log(String message) => appLog('[MusicCache] $message');

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

class _MusicCacheTask {
  late Future<File> future;
  final FileCancellationToken cancellation = FileCancellationToken();
  String? finalPath;
  String? partialPath;
  var started = false;
  var completed = false;
  var users = 0;
}

final musicCacheServiceProvider = Provider<MusicCacheService>(
  (ref) => MusicCacheService(),
);

final musicCacheUsageProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(musicCacheServiceProvider).usage();
});
