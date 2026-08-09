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

  test('视频缓存使用播放缓冲策略而不是完整视频下载', () {
    final disabled = videoBufferPolicyFor(CacheSizeOption.disabled);
    expect(disabled.diskCacheEnabled, isFalse);
    expect(disabled.bufferSize, defaultVideoBufferBytes);

    final wifi = videoBufferPolicyFor(CacheSizeOption.mb500);
    expect(wifi.diskCacheEnabled, isTrue);
    expect(wifi.bufferSize, CacheSizeOption.mb500.bytes);
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
    await File('${video.path}${Platform.pathSeparator}buffer.tmp')
        .writeAsString('buffer-data');
    expect((await service.usage()).videoBytes, greaterThan(0));

    await service.clear(CacheCategory.video);
    expect((await service.usage()).videoBytes, 0);
  });

  test('缓存字节格式化使用易读单位', () {
    expect(formatCacheBytes(0), '0 B');
    expect(formatCacheBytes(1024 * 1024), '1.00 MB');
    expect(formatCacheBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
  });
}
