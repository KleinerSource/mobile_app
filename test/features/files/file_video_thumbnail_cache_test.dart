import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:omm/features/cache/image_cache_manager.dart';
import 'package:omm/features/files/file_video_thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生成图写入现有缓存，重建缓存实例可读取，损坏缓存失效', () async {
    final root = await Directory.systemTemp.createTemp('omm-thumbnail-cache-');
    final fs = MemoryCacheSystem();
    AppImageCacheManager create() => AppImageCacheManager.forTesting(
      Config(
        'thumbnail-test',
        fileSystem: fs,
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
      ),
    );
    var manager = create();
    var cache = AppFileVideoThumbnailCache(cache: manager);
    final bytes = img.encodeJpg(img.Image(width: 200, height: 100));
    try {
      await cache.write('good', bytes, 0, () => true);
      await manager.dispose();
      manager = create();
      cache = AppFileVideoThumbnailCache(cache: manager);
      expect(await cache.read('good'), bytes);
      final file = (await manager.getFileFromCache('good'))!.file;
      await file.writeAsBytes([1, 2]);
      expect(await cache.read('good'), isNull);
      expect(await manager.getFileFromCache('good'), isNull);
    } finally {
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });

  test('清理开始即取消旧代际，进行中的写入完成后仍被清掉', () async {
    final root = await Directory.systemTemp.createTemp('omm-thumbnail-clear-');
    final repository = _DelayedRepository(File('${root.path}/index.json'));
    final manager = AppImageCacheManager.forTesting(
      Config(
        'thumbnail-test',
        fileSystem: MemoryCacheSystem(),
        repo: repository,
      ),
    );
    final bytes = img.encodeJpg(img.Image(width: 20, height: 10));
    try {
      final writing = manager.putGeneratedImage(
        'late',
        bytes,
        epoch: 0,
        isCurrent: () => true,
      );
      await repository.inserting.future;
      final clearing = manager.emptyCache();
      expect(manager.generatedImageEpoch.value, 1);
      expect(manager.isClearing, isTrue);
      repository.proceed.complete();
      await writing;
      await clearing;
      expect(await manager.getFileFromCache('late'), isNull);
      await manager.putGeneratedImage(
        'stale',
        bytes,
        epoch: 0,
        isCurrent: () => true,
      );
      expect(await manager.getFileFromCache('stale'), isNull);
      await manager.putGeneratedImage(
        'fresh',
        bytes,
        epoch: 1,
        isCurrent: () => true,
      );
      expect(await manager.getFileFromCache('fresh'), isNotNull);
    } finally {
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });
}

class _DelayedRepository extends JsonCacheInfoRepository {
  _DelayedRepository(super.file) : super.withFile();
  final inserting = Completer<void>();
  final proceed = Completer<void>();
  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    if (!inserting.isCompleted) inserting.complete();
    await proceed.future;
    return super.insert(cacheObject, setTouchedToNow: setTouchedToNow);
  }
}
