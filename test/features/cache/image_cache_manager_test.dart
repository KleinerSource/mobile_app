import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/features/cache/image_cache_manager.dart';

class _RecordingFileService extends FileService {
  Map<String, String>? requestHeaders;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    requestHeaders = headers;
    return _FakeFileServiceResponse();
  }
}

class _FakeFileServiceResponse implements FileServiceResponse {
  @override
  Stream<List<int>> get content => Stream.value(const <int>[0xFF, 0xD8]);

  @override
  int? get contentLength => 2;

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '.jpg';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 1));
}

Future<FileInfo> _fileInfo(String name) async {
  final file = await MemoryCacheSystem().createFile(name);
  return FileInfo(
    file,
    FileSource.Online,
    DateTime.now().add(const Duration(days: 1)),
    'https://example.test/$name',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('图片文件服务覆盖 UA 并保留鉴权头', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Oh My Media',
      packageName: 'com.ohmymedia.omm',
      version: '0.92.10',
      buildNumber: '745',
      buildSignature: '',
    );
    resetAppVersionCache();

    final delegate = _RecordingFileService();
    final service = AppImageFileService(delegate: delegate);
    await service.get(
      'https://example.test/cover.jpg',
      headers: const {
        'Authorization': 'Bearer token',
        'uSeR-aGeNt': 'legacy-image/1.0',
      },
    );

    expect(delegate.requestHeaders, {
      'Authorization': 'Bearer token',
      'User-Agent': 'omm/0.92.10',
    });
  });

  test('resized 缓存键与上游规则一致', () {
    expect(
      resizedImageCacheKey('https://a/b.jpg', maxWidth: 1080),
      'resized_w1080_https://a/b.jpg',
    );
    expect(
      resizedImageCacheKey('k', maxWidth: 10, maxHeight: 20),
      'resized_w10_h20_k',
    );
  });

  group('SharedFileResponseLoads', () {
    test('源流已产出文件但尚未结束时加入的订阅者也能拿到文件', () async {
      final loads = SharedFileResponseLoads();
      final source = StreamController<FileResponse>();
      var starts = 0;
      Stream<FileResponse> start() {
        starts++;
        return source.stream;
      }

      final first = loads.share('k', start).toList();
      final info = await _fileInfo('a.jpg');
      source.add(info);
      await Future<void>.delayed(Duration.zero);

      final second = loads.share('k', start).toList();
      await source.close();

      expect(starts, 1);
      expect(await first, [info]);
      expect(await second, [info]);
      expect(loads.isLoading('k'), isFalse);
    });

    test('加载结束后再次请求会重新发起', () async {
      final loads = SharedFileResponseLoads();
      final info = await _fileInfo('a.jpg');
      var starts = 0;
      Stream<FileResponse> start() {
        starts++;
        return Stream<FileResponse>.value(info);
      }

      expect(await loads.share('k', start).toList(), [info]);
      expect(await loads.share('k', start).toList(), [info]);
      expect(starts, 2);
    });

    test('源流没有产出文件就结束时报错而不是静默完成', () async {
      final loads = SharedFileResponseLoads();
      await expectLater(
        loads.share('k', () => const Stream<FileResponse>.empty()),
        emitsError(isA<StateError>()),
      );
      expect(loads.isLoading('k'), isFalse);
    });

    test('源流错误转发给所有订阅者', () async {
      final loads = SharedFileResponseLoads();
      final source = StreamController<FileResponse>();
      final first = loads.share('k', () => source.stream);
      final second = loads.share('k', () => source.stream);
      const error = HttpExceptionWithStatus(404, 'missing');
      source.addError(error);

      await expectLater(first, emitsError(error));
      await expectLater(second, emitsError(error));
      expect(loads.isLoading('k'), isFalse);
      await source.close();
    });
  });

  group('stableImageCacheKey', () {
    test('去掉 token 并保留其它查询参数', () {
      expect(
        stableImageCacheKey(
          'https://h/api/fanart/1.jpg?token=abc&_mdc_image_revision=2',
        ),
        'https://h/api/fanart/1.jpg?_mdc_image_revision=2',
      );
      expect(
        stableImageCacheKey('https://h/api/fanart/1.jpg?token=abc'),
        'https://h/api/fanart/1.jpg',
      );
    });

    test('没有 token 时原样返回', () {
      const url = 'https://h/api/images/1?x=1';
      expect(stableImageCacheKey(url), url);
    });
  });

  group('selectImageCacheEntriesOverBudget', () {
    final now = DateTime(2026, 10, 4, 12);
    CacheObject entry(int id, {required Duration age, int length = 100}) {
      return CacheObject(
        'https://h/$id',
        key: 'k$id',
        relativePath: '$id.jpg',
        validTill: now,
        id: id,
        length: length,
        touched: now.subtract(age),
      );
    }

    test('未超出上限时不删除', () {
      final objects = [entry(1, age: const Duration(days: 3))];
      expect(
        selectImageCacheEntriesOverBudget(
          objects,
          maxBytes: 100,
          sizeOf: (o) => o.length!,
          now: now,
        ),
        isEmpty,
      );
    });

    test('按最久未访问优先删到上限以内', () {
      final objects = [
        entry(1, age: const Duration(days: 1)),
        entry(2, age: const Duration(days: 5)),
        entry(3, age: const Duration(days: 3)),
      ];
      final victims = selectImageCacheEntriesOverBudget(
        objects,
        maxBytes: 150,
        sizeOf: (o) => o.length!,
        now: now,
      );
      expect(victims.map((o) => o.id), [2, 3]);
    });

    test('最近访问的条目即使超限也保留', () {
      final objects = [
        entry(1, age: const Duration(minutes: 1)),
        entry(2, age: const Duration(minutes: 2)),
        entry(3, age: const Duration(days: 2)),
      ];
      final victims = selectImageCacheEntriesOverBudget(
        objects,
        maxBytes: 100,
        sizeOf: (o) => o.length!,
        now: now,
      );
      expect(victims.map((o) => o.id), [3]);
    });
  });
}
