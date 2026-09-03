import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/cache/disk_cache.dart';

void main() {
  test('缓存服务能统计并清理其他缓存目录', () async {
    final root = await Directory.systemTemp.createTemp(
      'oh-my-media-cache-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    final service = DiskCacheService(rootDirectory: root);
    final other = Directory(
      '${root.path}${Platform.pathSeparator}omm_cache${Platform.pathSeparator}other',
    );
    await other.create(recursive: true);
    await File(
      '${other.path}${Platform.pathSeparator}data.bin',
    ).writeAsString('cache-data');

    expect((await service.usage()).otherBytes, greaterThan(0));

    await service.clear(CacheCategory.other);
    expect((await service.usage()).otherBytes, 0);
  });

  test('缓存字节格式化使用易读单位', () {
    expect(formatCacheBytes(0), '0 B');
    expect(formatCacheBytes(1024 * 1024), '1.00 MB');
    expect(formatCacheBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
  });
}
