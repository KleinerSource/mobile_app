import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:omm/features/cache/image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('清理等待在途图片与索引写入，完成后不被旧下载重新填充', () async {
    final root = await Directory.systemTemp.createTemp('image-clear-');
    final service = _FileService();
    final manager = AppImageCacheManager.forTesting(
      Config(
        'clear-test',
        fileSystem: MemoryCacheSystem(),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
        fileService: service,
      ),
    );
    try {
      final load = manager
          .getImageFile('https://test/image', key: 'old')
          .toList();
      await service.started.future;
      final clearing = manager.emptyCache();
      Timer(const Duration(milliseconds: 20), () {
        service.body.add([1, 2, 3]);
        unawaited(service.body.close());
      });
      await clearing;
      await load;
      expect(await manager.getFileFromCache('old'), isNull);
    } finally {
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });

  test('清理不等待迟到的响应头，迟到响应被丢弃且不写回缓存', () async {
    final root = await Directory.systemTemp.createTemp('image-header-clear-');
    final cancelled = Completer<void>();
    final delegate = _FileService()
      ..headers = Completer<void>()
      ..body = StreamController<List<int>>(onCancel: cancelled.complete);
    final manager = AppImageCacheManager.forTesting(
      Config(
        'header-clear-test',
        fileSystem: MemoryCacheSystem(),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
        fileService: AppImageFileService(delegate: delegate),
      ),
    );
    try {
      final load = manager.getImageFile('https://test/headers').toList();
      final failure = expectLater(load, throwsA(isA<StateError>()));
      await delegate.started.future;
      await manager.emptyCache().timeout(const Duration(seconds: 1));
      await failure;
      delegate.headers!.complete();
      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(await manager.getFileFromCache('https://test/headers'), isNull);
    } finally {
      await delegate.body.close();
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });

  test('图片清理同时移除 Flutter 图片内存缓存', () async {
    final root = await Directory.systemTemp.createTemp('image-memory-clear-');
    final manager = AppImageCacheManager.forTesting(
      Config(
        'memory-clear-test',
        fileSystem: MemoryCacheSystem(),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
      ),
    );
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.putIfAbsent(
        'pending-test',
        () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
      );
      expect(cache.pendingImageCount, greaterThan(0));
      await manager.emptyCache();
      expect(cache.pendingImageCount, 0);
    } finally {
      PaintingBinding.instance.imageCache.clear();
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });

  test('同一缩放图清理取消后可以重新下载并按比例缩放', () async {
    final root = await Directory.systemTemp.createTemp('resized-clear-');
    final delegate = _FileService();
    final manager = AppImageCacheManager.forTesting(
      Config(
        'resized-clear-test',
        fileSystem: MemoryCacheSystem(),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
        fileService: AppImageFileService(delegate: delegate),
      ),
    );
    try {
      const url = 'https://test/resized.jpg';
      final load = manager
          .getImageFile(url, maxWidth: 10, maxHeight: 10)
          .toList();
      final failure = expectLater(load, throwsA(isA<StateError>()));
      await delegate.started.future;
      await manager.emptyCache().timeout(const Duration(seconds: 1));
      await failure;
      delegate.reset();
      final fresh = manager
          .getImageFile(url, maxWidth: 10, maxHeight: 10)
          .toList();
      await delegate.started.future;
      delegate.body.add(img.encodeJpg(img.Image(width: 40, height: 20)));
      await delegate.body.close();
      final responses = await fresh.timeout(const Duration(seconds: 2));
      final image = img.decodeImage(
        await (responses.single as FileInfo).file.readAsBytes(),
      )!;
      expect(image.width, 10);
      expect(image.height, 5);
      expect(
        await manager.getFileFromCache(
          resizedImageCacheKey(url, maxWidth: 10, maxHeight: 10),
        ),
        isNotNull,
      );
    } finally {
      await delegate.body.close();
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });

  test('慢图片下载清理立即取消并能继续发起新下载', () async {
    final root = await Directory.systemTemp.createTemp('image-cancel-clear-');
    final delegate = _FileService();
    final manager = AppImageCacheManager.forTesting(
      Config(
        'cancel-clear-test',
        fileSystem: MemoryCacheSystem(),
        repo: JsonCacheInfoRepository.withFile(File('${root.path}/index.json')),
        fileService: AppImageFileService(delegate: delegate),
      ),
    );
    try {
      final load = manager.getImageFile('https://test/slow').toList();
      final failure = expectLater(load, throwsA(isA<StateError>()));
      await delegate.started.future;
      await manager.emptyCache().timeout(const Duration(seconds: 1));
      await failure;
      expect(await manager.getFileFromCache('https://test/slow'), isNull);
      expect(manager.isClearing, isFalse);
      delegate.reset();
      final fresh = manager.getImageFile('https://test/fresh').toList();
      await delegate.started.future;
      delegate.body.add([4, 5, 6]);
      await delegate.body.close();
      expect(await fresh, hasLength(1));
      expect(await manager.getFileFromCache('https://test/fresh'), isNotNull);
    } finally {
      await delegate.body.close();
      await manager.dispose();
      await root.delete(recursive: true);
    }
  });
}

class _FileService extends FileService {
  var started = Completer<void>();
  var body = StreamController<List<int>>();
  Completer<void>? headers;

  void reset() {
    unawaited(body.close());
    started = Completer<void>();
    body = StreamController<List<int>>();
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    started.complete();
    await this.headers?.future;
    return _Response(body.stream);
  }
}

class _Response implements FileServiceResponse {
  _Response(this.content);
  @override
  final Stream<List<int>> content;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => 3;
  @override
  String get fileExtension => '.jpg';
  @override
  String? get eTag => null;
  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 1));
}
