import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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

  test('缓存服务使用临时文件下载并能读取、清理视频缓存', () async {
    final root = await Directory.systemTemp.createTemp('md-center-cache-test-');
    addTearDown(() => root.delete(recursive: true));
    final dio = Dio()..httpClientAdapter = _VideoAdapter('video-data');
    final service = DiskCacheService(
      downloadClient: dio,
      rootDirectory: root,
    );

    final result = await service.cacheMovie(
      movieId: 7,
      sourceUrl: 'https://example.com/movie.mp4',
      maxBytes: 1024,
    );

    expect(result.fromCache, isFalse);
    expect(await File(result.path).readAsString(), 'video-data');
    expect(await service.cachedMovieFile(7), result.path);
    expect((await service.usage()).videoBytes, greaterThan(0));

    final cached = await service.cacheMovie(
      movieId: 7,
      sourceUrl: 'https://example.com/movie.mp4',
      maxBytes: 1024,
    );
    expect(cached.fromCache, isTrue);

    await service.clear(CacheCategory.video);
    expect(await service.cachedMovieFile(7), isNull);
  });

  test('超过缓存上限时不会留下半成品', () async {
    final root = await Directory.systemTemp.createTemp('md-center-cache-test-');
    addTearDown(() => root.delete(recursive: true));
    final dio = Dio()..httpClientAdapter = _VideoAdapter('too-large');
    final service = DiskCacheService(
      downloadClient: dio,
      rootDirectory: root,
    );

    await expectLater(
      service.cacheMovie(
        movieId: 8,
        sourceUrl: 'https://example.com/movie.mkv',
        maxBytes: 3,
      ),
      throwsA(isA<CacheLimitExceededException>()),
    );
    expect(await service.cachedMovieFile(8), isNull);
  });

  test('缓存字节格式化使用易读单位', () {
    expect(formatCacheBytes(0), '0 B');
    expect(formatCacheBytes(1024 * 1024), '1.00 MB');
    expect(formatCacheBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
  });
}

class _VideoAdapter implements HttpClientAdapter {
  _VideoAdapter(this.body);

  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['video/mp4'],
        Headers.contentLengthHeader: [body.length.toString()],
      },
    );
  }
}
