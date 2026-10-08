import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/api/server_connection.dart';
import '../../core/sources/files/file_entry.dart';
import '../../core/sources/files/file_source_repository.dart';
import '../cache/image_cache_manager.dart';
import 'file_entry_icons.dart';
import 'file_playback_proxy.dart';
import 'file_video_thumbnail_decoder.dart';

String fileVideoThumbnailKey(String sourceIdentity, FileEntry entry) =>
    'file-video-v1:${sha256.convert(utf8.encode(jsonEncode([sourceIdentity, entry.path.sourceId.value, normalizeRelativeFilePath(entry.path.value), entry.size, entry.modifiedAt?.toUtc().toIso8601String(), entry.attributes['etag'], 0.1, 320, 80])))}';

abstract interface class FileVideoThumbnailCache {
  ValueListenable<int> get epoch;
  bool get isClearing;
  Future<Uint8List?> read(String key);
  Future<void> write(
    String key,
    Uint8List bytes,
    int epoch,
    bool Function() valid,
  );
}

class AppFileVideoThumbnailCache implements FileVideoThumbnailCache {
  AppFileVideoThumbnailCache({AppImageCacheManager? cache})
    : _cache = cache ?? AppImageCacheManager.instance;
  final AppImageCacheManager _cache;
  @override
  ValueListenable<int> get epoch => _cache.generatedImageEpoch;
  @override
  bool get isClearing => _cache.isClearing;
  @override
  Future<Uint8List?> read(String key) async {
    final file = await _cache.getFileFromCache(key);
    if (file == null) return null;
    try {
      final bytes = await file.file.readAsBytes();
      if (file.validTill.isAfter(DateTime.now()) &&
          img.decodeJpg(bytes) != null) {
        return bytes;
      }
    } catch (_) {
      /* 缺失或损坏的生成图重新抽帧。 */
    }
    await _cache.removeFile(key);
    return null;
  }

  @override
  Future<void> write(
    String key,
    Uint8List bytes,
    int epoch,
    bool Function() valid,
  ) async {
    await _cache.putGeneratedImage(key, bytes, epoch: epoch, isCurrent: valid);
    if (valid()) await _cache.trimToMaxBytes();
  }
}

typedef FileVideoThumbnailGenerate =
    Future<Uint8List?> Function(
      FileSourceRepository repository,
      FileEntry entry,
      FileCancellationToken cancellation,
    );

Future<Uint8List?> _generate(
  FileSourceRepository repository,
  FileEntry entry,
  FileCancellationToken cancellation,
) async {
  if (cancellation.isCancelled) return null;
  if (fileExtensionFor(entry.name) == 'm3u8' ||
      (entry.mimeType?.toLowerCase().contains('mpegurl') ?? false)) {
    return null;
  }
  final proxy = await FilePlaybackProxy.start(
    repository: repository,
    path: entry.path,
    size: entry.size,
    mimeType: entry.mimeType,
    pathExtension: fileExtensionFor(entry.name),
    thumbnailPolicy: const FileThumbnailReadPolicy(),
  );
  unawaited(cancellation.whenCancelled.then((_) => proxy.close()));
  try {
    if (cancellation.isCancelled) return null;
    return await decodeFileVideoThumbnail(proxy.uri, cancellation);
  } finally {
    await proxy.close();
  }
}

/// 应用级单并发队列；每个订阅可单独释放，最后一个离开才取消共享任务。
class FileVideoThumbnailService {
  FileVideoThumbnailService({
    required this.cache,
    FileVideoThumbnailGenerate? generate,
    this.timeout = const Duration(seconds: 30),
  }) : _generateFrame = generate ?? _generate {
    cache.epoch.addListener(cancelAll);
  }
  final FileVideoThumbnailCache cache;
  final FileVideoThumbnailGenerate _generateFrame;
  final Duration timeout;
  final _jobs = <String, _VideoJob>{};
  final Queue<_VideoJob> _pending = Queue();
  bool _running = false;
  bool _disposed = false;

  FileVideoThumbnailRequest load({
    required String key,
    required FileSourceRepository repository,
    required FileEntry entry,
    required ServerConnectionLease lease,
  }) {
    // 连接代际仅隔离进行中的任务；不进入持久缓存键。
    final jobKey = '$key:${identityHashCode(lease)}';
    var job = _jobs[jobKey];
    if (job == null) {
      job = _VideoJob(jobKey, key, repository, entry, lease, cache.epoch.value);
      _jobs[jobKey] = job;
      final captured = job;
      job.unregister = lease.register(() => _cancel(captured));
      _pending.add(job);
    }
    job.users++;
    if (_disposed || cache.isClearing || !lease.isActive) _cancel(job);
    _pump();
    return FileVideoThumbnailRequest._(job.result.future, () {
      if (--job!.users == 0) _cancel(job);
    });
  }

  void _cancel(_VideoJob job) {
    job.cancellation.cancel();
    if (!job.result.isCompleted) job.result.complete(null);
    _pending.remove(job);
    if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
    job.unregister?.call();
  }

  void cancelAll() {
    for (final job in _jobs.values.toList()) {
      _cancel(job);
    }
  }

  void dispose() {
    _disposed = true;
    cache.epoch.removeListener(cancelAll);
    cancelAll();
  }

  void _pump() {
    if (_running || _disposed || _pending.isEmpty) return;
    _running = true;
    unawaited(_run(_pending.removeFirst()));
  }

  Future<void> _run(_VideoJob job) async {
    final timer = Timer(timeout, () => _cancel(job));
    bool valid() =>
        !job.cancellation.isCancelled &&
        job.lease.isActive &&
        cache.epoch.value == job.epoch &&
        !cache.isClearing &&
        !_disposed;
    try {
      Uint8List? bytes;
      try {
        bytes = await cache.read(job.key).timeout(timeout);
      } catch (_) {}
      if (!valid()) return;
      if (bytes == null) {
        bytes = await _generateFrame(
          job.repository,
          job.entry,
          job.cancellation,
        );
        if (bytes != null && bytes.isNotEmpty && valid()) {
          try {
            await cache.write(job.key, bytes, job.epoch, valid);
          } catch (_) {
            /* 缓存不可写时仍可显示本次结果。 */
          }
        }
      }
      if (valid() && !job.result.isCompleted) job.result.complete(bytes);
    } catch (_) {
      // 列表中的抽帧失败保持占位，不影响点击播放，也不弹出错误提示。
    } finally {
      timer.cancel();
      if (!job.result.isCompleted) job.result.complete(null);
      if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
      job.unregister?.call();
      _running = false;
      _pump();
    }
  }
}

class FileVideoThumbnailRequest {
  FileVideoThumbnailRequest._(this.bytes, this._release);
  final Future<Uint8List?> bytes;
  final VoidCallback _release;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

class _VideoJob {
  _VideoJob(
    this.id,
    this.key,
    this.repository,
    this.entry,
    this.lease,
    this.epoch,
  );
  final String id;
  final String key;
  final FileSourceRepository repository;
  final FileEntry entry;
  final ServerConnectionLease lease;
  final int epoch;
  final cancellation = FileCancellationToken();
  final result = Completer<Uint8List?>();
  VoidCallback? unregister;
  int users = 0;
}
