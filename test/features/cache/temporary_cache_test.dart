import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/cache/disk_cache.dart';
import 'package:omm/features/cache/image_cache_manager.dart';
import 'package:omm/features/cache/music_cache.dart';
import 'package:omm/features/cache/temporary_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('分类统计、清理覆盖临时文件与旧目录，并保留配置和未知文件', () async {
    final root = await Directory.systemTemp.createTemp('temporary-cache-');
    addTearDown(() => root.delete(recursive: true));
    final temporary = TemporaryCacheService(rootDirectory: root);
    final manager = AppImageCacheManager.forTesting(
      Config(
        'temp-clear-test',
        fileSystem: MemoryCacheSystem(),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
      ),
    );
    addTearDown(manager.dispose);
    final disk = DiskCacheService(
      rootDirectory: root,
      imageCache: manager,
      temporaryCache: temporary,
    );
    final music = MusicCacheService(
      rootDirectory: root,
      temporaryCache: temporary,
    );
    final paths = {
      'omm_cache/other/data.bin': 1,
      'omm_cache/video/legacy.bin': 2,
      'omm_mb_audio_media/song.media': 3,
      'omm_mb_audio_art/cover.jpg': 4,
      'omm_audio_metadata/omm_audio_audio_song.mp3': 5,
      'omm_audio_metadata/omm_audio_art_song.jpg': 6,
      'omm-playback-file.tmp': 7,
      'mdc-subtitle-file.vtt': 8,
      'omm_update_app.apk': 9,
      'preferences.json': 10,
      'unknown/file.bin': 11,
    };
    for (final entry in paths.entries) {
      final file = File('${root.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(entry.value, 1));
    }
    final usage = await disk.usage();
    expect(usage.imageBytes, 10);
    expect(usage.otherBytes, 27);
    expect(await music.usage(), 8);
    await disk.clear(CacheCategory.other);
    expect((await disk.usage()).otherBytes, 0);
    expect(await music.usage(), 8);
    await disk.clearAll();
    expect((await disk.usage()).totalBytes, 0);
    expect(await music.usage(), 8);
    await music.clear();
    expect(await music.usage(), 0);
    expect(await File('${root.path}/preferences.json').length(), 10);
    expect(await File('${root.path}/unknown/file.bin').length(), 11);
  });

  test('清理保护正在使用与尚未落盘的文件，最后一个持有者释放后删除', () async {
    final root = await Directory.systemTemp.createTemp('retained-cache-');
    addTearDown(() => root.delete(recursive: true));
    final service = TemporaryCacheService(rootDirectory: root);
    final file = File('${root.path}/omm-playback-active.tmp');
    final secondOwner = File(file.path);
    service.retain(file);
    service.retain(secondOwner);
    await service.clear(TemporaryCacheKind.other);
    expect(service.isPendingDeletion(file.path), isTrue);
    await file.writeAsBytes([1, 2]);
    await service.release(file);
    expect(await file.exists(), isTrue);
    expect(await service.usage(TemporaryCacheKind.other), 2);
    await service.release(secondOwner);
    expect(await file.exists(), isFalse);
    expect(service.isPendingDeletion(file.path), isFalse);
    final slashPath = File(
      '${root.path.replaceAll('\\', '/')}/omm-playback-slashes.tmp',
    );
    service.retain(slashPath);
    await slashPath.writeAsBytes([4]);
    await service.clear(TemporaryCacheKind.other);
    expect(await slashPath.exists(), isTrue);
    await service.release(slashPath);
    expect(await slashPath.exists(), isFalse);
    final next = File('${root.path}/omm-playback-new.tmp');
    service.retain(next);
    await next.writeAsBytes([3]);
    await service.release(next);
    expect(await next.exists(), isTrue);
  });

  test('图片清理移除没有索引的失败下载残留并可重新写入', () async {
    final root = await Directory.systemTemp.createTemp('orphan-image-cache-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    final manager = AppImageCacheManager.forTesting(
      Config(
        'orphan-test',
        fileSystem: IOFileSystem('orphan-test'),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
      ),
    );
    try {
      final orphan = await manager.config.fileSystem.createFile('orphan.jpg');
      await orphan.writeAsBytes([1, 2]);
      await manager.emptyCache();
      expect(await orphan.exists(), isFalse);
      await manager.putGeneratedImage(
        'new',
        Uint8List.fromList([3]),
        epoch: 1,
        isCurrent: () => true,
      );
      expect(await manager.getFileFromCache('new'), isNotNull);
      final cachedFile = (await manager.getFileFromCache('new'))!.file;
      await manager.removeEntriesWhere((key) => key == 'new');
      expect(await cachedFile.exists(), isFalse);
    } finally {
      await manager.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    }
  });
}
