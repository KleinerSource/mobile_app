import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/cache/disk_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('缓存大小选项包含全部预设额度', () {
    expect(cacheSizeOptions, CacheSizeOption.values);
    expect(CacheSizeOption.mb300.bytes, 300 * 1024 * 1024);
    expect(CacheSizeOption.gb4.label, '4GB');
  });

  test('视频缓存按设置启用磁盘缓冲和持久化上限', () {
    final disabled = videoBufferPolicyFor(CacheSizeOption.disabled);
    expect(disabled.diskCacheEnabled, isFalse);
    expect(disabled.bufferSize, defaultVideoBufferBytes);
    expect(disabled.diskCacheLimitBytes, 0);

    final wifi = videoBufferPolicyFor(CacheSizeOption.mb500);
    expect(wifi.diskCacheEnabled, isTrue);
    expect(wifi.bufferSize, defaultVideoBufferBytes);
    expect(wifi.diskCacheLimitBytes, CacheSizeOption.mb500.bytes);

    final large = videoBufferPolicyFor(CacheSizeOption.gb4);
    expect(large.bufferSize, defaultVideoBufferBytes);
    expect(large.diskCacheLimitBytes, CacheSizeOption.gb4.bytes);
  });

  test('15% 预载按码率估算但限制 native 内存上限', () {
    final disabled = videoBufferBytesForPrefetch(
      diskCacheEnabled: false,
      durationSeconds: 3600,
      bitRate: 20 * 1000 * 1000,
    );
    expect(disabled, defaultVideoBufferBytes);

    expect(
      videoBufferBytesForPrefetch(diskCacheEnabled: true, durationSeconds: 0),
      maxVideoPrefetchBufferBytes,
    );

    final estimated = videoBufferBytesForPrefetch(
      diskCacheEnabled: true,
      durationSeconds: 3600,
      bitRate: 4 * 1000 * 1000,
    );
    expect(estimated, greaterThan(defaultVideoBufferBytes));
    expect(estimated, lessThanOrEqualTo(maxVideoPrefetchBufferBytes));

    final capped = videoBufferBytesForPrefetch(
      diskCacheEnabled: true,
      durationSeconds: 7200,
      bitRate: 50 * 1000 * 1000,
    );
    expect(capped, maxVideoPrefetchBufferBytes);
  });

  test('预缓存设置可以持久化并恢复', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = DiskPrecacheSettingsRepository(prefs);
    const expected = DiskPrecacheSettings(
      wifiLimit: CacheSizeOption.gb2,
      mobileLimit: CacheSizeOption.mb500,
    );

    await repository.save(expected);

    expect(repository.load().wifiLimit, CacheSizeOption.gb2);
    expect(repository.load().mobileLimit, CacheSizeOption.mb500);
  });

  test('缓存服务能统计并清理播放器缓冲目录', () async {
    final root = await Directory.systemTemp.createTemp('md-center-cache-test-');
    addTearDown(() => root.delete(recursive: true));
    final service = DiskCacheService(rootDirectory: root);
    final video = await service.videoBufferDirectory();
    await File(
      '${video.path}${Platform.pathSeparator}buffer.tmp',
    ).writeAsString('buffer-data');
    expect((await service.usage()).videoBytes, greaterThan(0));

    await service.clear(CacheCategory.video);
    expect((await service.usage()).videoBytes, 0);
  });

  test('视频持久化缓存会保留到清理或超限淘汰', () async {
    final root = await Directory.systemTemp.createTemp('md-center-cache-file-');
    addTearDown(() => root.delete(recursive: true));
    final service = DiskCacheService(rootDirectory: root);
    final file = await service.videoCacheFile(movieId: 8, quality: 'original');
    expect(file.path, endsWith('movie-8-original.mkv'));
    final hlsFile = await service.videoCacheFile(
      movieId: 8,
      quality: '720p',
      extension: '.ts',
    );
    expect(hlsFile.path, endsWith('movie-8-720p.ts'));
    await file.writeAsString('cached-video');
    await hlsFile.writeAsString('cached-hls');

    expect(await file.exists(), isTrue);
    expect((await service.usage()).videoBytes, greaterThan(10));

    await service.pruneVideoCache(maxBytes: 12);
    expect((await service.usage()).videoBytes, lessThanOrEqualTo(12));

    await service.clear(CacheCategory.video);
    expect(await file.exists(), isFalse);
  });

  test('视频缓存查找优先使用指定容器且忽略空文件', () async {
    final root = await Directory.systemTemp.createTemp('md-center-cache-find-');
    addTearDown(() => root.delete(recursive: true));
    final service = DiskCacheService(rootDirectory: root);
    final empty = await service.videoCacheFile(
      movieId: 12,
      quality: 'original',
      extension: '.webm',
    );
    final fallback = await service.videoCacheFile(
      movieId: 12,
      quality: 'original',
      extension: '.mkv',
    );
    final preferred = await service.videoCacheFile(
      movieId: 12,
      quality: 'original',
      extension: '.mp4',
    );
    await empty.writeAsString('');
    await fallback.writeAsString('cached-mkv');
    await preferred.writeAsString('cached-mp4');

    final found = await service.findVideoCacheFile(
      movieId: 12,
      quality: 'original',
      preferredExtension: '.mp4',
    );
    expect(found?.path, preferred.path);
  });

  test('缓存字节格式化使用易读单位', () {
    expect(formatCacheBytes(0), '0 B');
    expect(formatCacheBytes(1024 * 1024), '1.00 MB');
    expect(formatCacheBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
  });
}
