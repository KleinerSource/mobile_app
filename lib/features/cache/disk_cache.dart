import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum CacheCategory { image, other }

extension CacheCategoryX on CacheCategory {
  String get label => switch (this) {
    CacheCategory.image => '图片缓存',
    CacheCategory.other => '其他缓存',
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
  DiskCacheService({Directory? rootDirectory}) : _rootOverride = rootDirectory;

  static const _rootName = 'md_center_cache';
  static const _otherDirName = 'other';

  final Directory? _rootOverride;
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

  Future<Directory> _categoryDirectory(String name) async {
    final root = await _rootDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}$name');
    await directory.create(recursive: true);
    return directory;
  }

  Future<CacheUsage> usage() async {
    final root = await _rootDirectory();
    // DefaultCacheManager 仍使用临时目录，图片统计要跟随它的实际位置。
    final imageBase = _rootOverride ?? await getTemporaryDirectory();
    final image = Directory(
      '${imageBase.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    return CacheUsage(
      imageBytes: await _directorySize(image),
      otherBytes: await _directorySize(
        Directory('${root.path}${Platform.pathSeparator}$_otherDirName'),
      ),
    );
  }

  Future<void> clear(CacheCategory category) {
    return _enqueue(() async {
      if (category == CacheCategory.image) {
        await DefaultCacheManager().emptyCache();
        return;
      }
      final directory = await _categoryDirectory(_otherDirName);
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
    });
  }

  Future<void> clearAll() {
    return _enqueue(() async {
      await DefaultCacheManager().emptyCache();
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
      if (entity is File) total += await entity.length();
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
