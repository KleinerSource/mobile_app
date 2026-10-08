import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/features/cache/image_cache_manager.dart';
import 'temporary_cache.dart';

enum CacheCategory { image, other }

extension CacheCategoryX on CacheCategory {
  String label(AppL10n l) => switch (this) {
    CacheCategory.image => l.cacheCategoryImage,
    CacheCategory.other => l.cacheCategoryOther,
  };
}

@immutable
class CacheUsage {
  const CacheUsage({required this.imageBytes, required this.otherBytes});

  final int imageBytes;
  final int otherBytes;

  int get totalBytes => imageBytes + otherBytes;

  int bytesFor(CacheCategory category) => switch (category) {
    CacheCategory.image => imageBytes,
    CacheCategory.other => otherBytes,
  };
}

String formatCacheBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

class DiskCacheService {
  DiskCacheService({
    Directory? rootDirectory,
    AppImageCacheManager? imageCache,
    TemporaryCacheService? temporaryCache,
  }) : _rootOverride = rootDirectory,
       _imageCacheOverride = imageCache,
       _temporaryCache =
           temporaryCache ??
           (rootDirectory == null
               ? TemporaryCacheService.instance
               : TemporaryCacheService(rootDirectory: rootDirectory));

  static const _rootName = 'omm_cache';

  final Directory? _rootOverride;
  final AppImageCacheManager? _imageCacheOverride;
  AppImageCacheManager get _imageCache =>
      _imageCacheOverride ?? AppImageCacheManager.instance;
  final TemporaryCacheService _temporaryCache;
  Directory? _root;
  Future<void> _operationQueue = Future<void>.value();

  Future<Directory> _rootDirectory() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = await _cacheBaseDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}$_rootName',
    );
    await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<Directory> _cacheBaseDirectory() {
    final override = _rootOverride;
    return override == null
        ? getApplicationSupportDirectory()
        : Future.value(override);
  }

  Future<CacheUsage> usage() async {
    await _operationQueue;
    final root = await _rootDirectory();
    // 图片缓存(AppImageCacheManager)复用 DefaultCacheManager 的目录与
    // 索引，统计路径不变。
    final imageBase = _rootOverride ?? await getTemporaryDirectory();
    final image = Directory(
      '${imageBase.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    return CacheUsage(
      imageBytes:
          await _directorySize(image) +
          await _temporaryCache.usage(TemporaryCacheKind.image),
      // 包含旧版本遗留的视频目录，统计与一键清理范围一致。
      otherBytes:
          await _directorySize(root) +
          await _temporaryCache.usage(TemporaryCacheKind.other),
    );
  }

  Future<void> clear(CacheCategory category) {
    return _enqueue(() async {
      if (category == CacheCategory.image) {
        await _imageCache.emptyCache();
        await _temporaryCache.clear(TemporaryCacheKind.image);
        return;
      }
      final directory = await _rootDirectory();
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
      await _temporaryCache.clear(TemporaryCacheKind.other);
    });
  }

  Future<void> clearAll() {
    return _enqueue(() async {
      await _imageCache.emptyCache();
      await _temporaryCache.clear(TemporaryCacheKind.image);
      await _temporaryCache.clear(TemporaryCacheKind.other);
      // 整棵删除可以顺带清掉旧版本持久化视频缓存留下的文件。
      final root = await _rootDirectory();
      if (await root.exists()) await root.delete(recursive: true);
      await root.create(recursive: true);
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationQueue.then((_) => action());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on PathNotFoundException {
          // 图片自动淘汰或播放会话释放与统计并发。
        }
      }
    }
    return total;
  }
}

final diskCacheServiceProvider = Provider<DiskCacheService>(
  (ref) => DiskCacheService(),
);

final cacheUsageProvider = FutureProvider.autoDispose<CacheUsage>((ref) {
  return ref.watch(diskCacheServiceProvider).usage();
});
