import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// CacheStore 没有公开导出；锁定版本的自定义 store 用于修复未等待入库的竞态。
// ignore: implementation_imports
import 'package:flutter_cache_manager/src/cache_store.dart';

import '../../core/api/app_request_headers.dart';

class AppImageFileService extends FileService {
  AppImageFileService({FileService? delegate})
    : _delegate = delegate ?? HttpFileService();

  final FileService _delegate;
  final _active = <Completer<void>>{};
  bool _paused = false;

  void pause() {
    _paused = true;
    for (final request in _active.toList()) {
      if (!request.isCompleted) request.complete();
    }
  }

  void resume() => _paused = false;

  @override
  int get concurrentFetches => _delegate.concurrentFetches;

  @override
  set concurrentFetches(int value) => _delegate.concurrentFetches = value;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    if (_paused) throw StateError('图片缓存正在清理');
    final cancellation = Completer<void>();
    _active.add(cancellation);
    try {
      final requestHeaders = await mergeAppRequestHeaders(headers);
      if (_paused || cancellation.isCompleted) throw StateError('图片缓存正在清理');
      final response = await Future.any([
        _delegate
            .get(url, headers: requestHeaders)
            .then((response) async {
              if (cancellation.isCompleted) {
                await response.content.listen((_) {}).cancel();
                throw StateError('图片请求已取消');
              }
              return response;
            })
            .timeout(const Duration(seconds: 30)),
        cancellation.future.then<FileServiceResponse>(
          (_) => throw StateError('图片请求已取消'),
        ),
      ]);
      if (response.statusCode != 200 && response.statusCode != 202) {
        _active.remove(cancellation);
        await response.content.listen((_) {}).cancel();
      }
      return _TimedImageResponse(
        response,
        cancellation.future,
        () => _active.remove(cancellation),
      );
    } catch (_) {
      if (!cancellation.isCompleted) cancellation.complete();
      _active.remove(cancellation);
      rethrow;
    }
  }
}

class _TimedImageResponse implements FileServiceResponse {
  _TimedImageResponse(this.response, this.cancellation, this.onFinished);
  final FileServiceResponse response;
  final Future<void> cancellation;
  final VoidCallback onFinished;
  @override
  Stream<List<int>> get content {
    StreamSubscription<List<int>>? source;
    var finished = false;
    late final StreamController<List<int>> controller;
    void finish() {
      if (finished) return;
      finished = true;
      onFinished();
      unawaited(controller.close());
    }

    controller = StreamController<List<int>>(
      onListen: () {
        source = response.content
            .timeout(
              const Duration(seconds: 30),
              onTimeout: (sink) {
                sink.addError(TimeoutException('图片下载超时'));
                sink.close();
              },
            )
            .listen(
              controller.add,
              onError: controller.addError,
              onDone: finish,
            );
        unawaited(
          cancellation.then((_) async {
            if (finished) return;
            await source?.cancel();
            if (finished) return;
            controller.addError(StateError('图片请求已取消'));
            finish();
          }),
        );
      },
      onCancel: () async {
        await source?.cancel();
        finish();
      },
    );
    return controller.stream;
  }

  @override
  int? get contentLength => response.contentLength;
  @override
  String? get eTag => response.eTag;
  @override
  String get fileExtension => response.fileExtension;
  @override
  int get statusCode => response.statusCode;
  @override
  DateTime get validTill => response.validTill;
}

/// 应用图片专用 CacheManager。
///
/// 与 [DefaultCacheManager] 共用同一份缓存目录和索引（key 相同，设置页的
/// 统计与清空因此继续生效），仅把对象上限从默认的 200 放大：带
/// `maxWidthDiskCache` 的图片每张会写两条缓存（原图 + resized），200 条
/// 上限实际只够缓存约一百张封面，媒体库一次浏览就会触发容量清洗，把
/// 首页和网格的封面条目整批删光，下次启动全部重新下载（表现为封面逐个
/// 占位加载）。所有 [CachedNetworkImage] 必须统一传本实例——库里只要还
/// 有 DefaultCacheManager 实例在跑，它仍会按 200 的上限清洗这份共享索引。
///
/// 另外覆盖了带尺寸的 [getImageFile]：上游用 `asBroadcastStream` 共享同一
/// resized key 的进行中任务，广播流不重放已发出的事件，而条目要等首个
/// 订阅者解码完才移除。这个窗口里同一封面的第二次请求（例如布局宽度
/// 变化导致 memCacheWidth 不同）只会收到 done，图片既不出现也不报错，
/// 并且挂起的 completer 会一直留在 ImageCache 里，表现为个别封面永久
/// 空白。原图宽度小于上限时 resized 条目永远不会写入，所以每次加载都会
/// 经过这条共享路径。这里改为可重放的共享加载，保证同一 key 同一时刻
/// 只有一个上游调用。
///
/// 上游的自动清洗只按条数与 [Config.stalePeriod] 删除，且一天内访问过的
/// 条目不计入条数上限，没有任何字节上限；[removeEntriesWhere] 与
/// [trimToMaxBytes] 补上按 key 精确清理和按体积兜底清理。
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  AppImageCacheManager._()
    : this._withConfig(
        Config(
          DefaultCacheManager.key,
          stalePeriod: appImageCacheStalePeriod,
          maxNrOfCacheObjects: 3000,
          fileService: AppImageFileService(),
        ),
      );

  static final AppImageCacheManager instance = AppImageCacheManager._();

  @visibleForTesting
  AppImageCacheManager.forTesting(Config config) : this._withConfig(config);

  // 上游公开此构造器用于自定义 CacheStore，索引写入必须与清理串行。
  AppImageCacheManager._withConfig(super.config)
    // ignore: invalid_use_of_visible_for_testing_member
    : super.custom(cacheStore: _ImageCacheStore(config));

  final SharedFileResponseLoads _fileLoads = SharedFileResponseLoads();
  final SharedFileResponseLoads _resizedLoads = SharedFileResponseLoads();
  Future<void> _maintenanceQueue = Future<void>.value();
  final generatedImageEpoch = ValueNotifier<int>(0);
  int _clearCount = 0;
  bool get isClearing => _clearCount > 0;

  /// 生成图写入与清理串行，清理开始便使旧任务失效。
  Future<void> putGeneratedImage(
    String key,
    Uint8List bytes, {
    required int epoch,
    required bool Function() isCurrent,
  }) => _enqueueMaintenance(() async {
    bool valid() =>
        !isClearing && generatedImageEpoch.value == epoch && isCurrent();
    if (!valid()) return;
    final existing = await store.retrieveCacheData(key);
    final object =
        (existing ??
                CacheObject(
                  key,
                  key: key,
                  relativePath:
                      'generated-${sha256.convert(utf8.encode(key))}.jpg',
                  validTill: DateTime.now().add(appImageCacheStalePeriod),
                ))
            .copyWith(validTill: DateTime.now().add(appImageCacheStalePeriod));
    final file = await config.fileSystem.createFile(object.relativePath);
    // CacheManager.putFile 不等待索引入库；生成图必须等文件和索引同时完成。
    await file.writeAsBytes(bytes);
    await store.putFile(object);
    if (!valid()) await removeFile(key);
  });

  @override
  Future<void> emptyCache() {
    _clearCount++;
    final service = config.fileService;
    if (service is AppImageFileService) service.pause();
    generatedImageEpoch.value++;
    return _enqueueMaintenance(() async {
      try {
        // 上游下载和缩放会在取消订阅后继续落盘；先等待它们及索引写入。
        await _fileLoads.idle;
        await _resizedLoads.idle;
        await super.emptyCache();
        // 索引清理不会删除网络失败/进程异常留下的未入库文件。
        if (config.fileSystem is IOFileSystem) {
          final root = io.Directory(
            (await config.fileSystem.createFile('')).path,
          );
          if (await root.exists()) {
            await for (final entry in root.list(followLinks: false)) {
              if (entry is io.File) {
                try {
                  await entry.delete();
                } on io.PathNotFoundException {
                  // 自动淘汰可能已删除该文件。
                }
              }
            }
          }
        }
        store.emptyMemoryCache();
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
      } finally {
        _clearCount--;
        if (!isClearing && service is AppImageFileService) service.resume();
      }
    });
  }

  /// 删除 key 满足 [test] 的全部条目（含磁盘文件），返回删除条数。
  Future<int> removeEntriesWhere(bool Function(String key) test) {
    return _enqueueMaintenance(() async {
      final objects = await _allObjects();
      var removed = 0;
      for (final object in objects) {
        if (!test(object.key)) continue;
        await store.removeCachedFile(object);
        removed++;
      }
      return removed;
    });
  }

  /// 总体积超过 [maxBytes] 时按最久未访问优先删除，返回删除条数。
  Future<int> trimToMaxBytes([int maxBytes = appImageCacheMaxBytes]) {
    return _enqueueMaintenance(() async {
      final objects = await _allObjects();
      final sizes = <int, int>{};
      for (final object in objects) {
        sizes[object.id!] = object.length ?? await _fileLength(object);
      }
      final victims = selectImageCacheEntriesOverBudget(
        objects,
        maxBytes: maxBytes,
        sizeOf: (object) => sizes[object.id!] ?? 0,
        now: DateTime.now(),
      );
      for (final object in victims) {
        await store.removeCachedFile(object);
      }
      return victims.length;
    });
  }

  Future<List<CacheObject>> _allObjects() async {
    final repo = config.repo;
    // 索引打开失败时 open() 的后续调用会一直挂起，超时避免堵死维护队列。
    await repo.open().timeout(const Duration(seconds: 10));
    try {
      final objects = await repo.getAllObjects();
      return objects.where((object) => object.id != null).toList();
    } finally {
      await repo.close();
    }
  }

  Future<int> _fileLength(CacheObject object) async {
    try {
      final file = await config.fileSystem.createFile(object.relativePath);
      return await file.exists() ? await file.length() : 0;
    } on Object {
      return 0;
    }
  }

  Future<T> _enqueueMaintenance<T>(Future<T> Function() action) {
    final result = _maintenanceQueue.then((_) => action());
    _maintenanceQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    if (isClearing) throw StateError('图片缓存正在清理');
    return await _fileLoads
            .share(
              'download:${key ?? url}:$force',
              () => Stream<FileResponse>.fromFuture(
                super.downloadFile(
                  url,
                  key: key,
                  authHeaders: authHeaders,
                  force: force,
                ),
              ),
            )
            .firstWhere((event) => event is FileInfo)
        as FileInfo;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    if (isClearing) return Stream.error(StateError('图片缓存正在清理'));
    // 只共享带进度的底层流，按订阅者要求筛选，不丢失后加入者的文件。
    final stream = _fileLoads.share(
      key ?? url,
      () => super.getFileStream(
        url,
        key: key,
        headers: headers,
        withProgress: true,
      ),
    );
    return withProgress ? stream : stream.where((event) => event is FileInfo);
  }

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) {
    if (isClearing) return Stream.error(StateError('图片缓存正在清理'));
    if (maxHeight == null && maxWidth == null) {
      return super.getImageFile(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
      );
    }
    return _resizedLoads.share(
      resizedImageCacheKey(
        key ?? url,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      () => _loadResizedImage(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
      ),
    );
  }

  // 上游 _runningResizes 在源流报错时不会移除 key，清理取消后同图永远
  // 只能订阅已结束的流；本类的共享队列在成功、失败路径都会释放 key。
  Stream<FileResponse> _loadResizedImage(
    String url, {
    String? key,
    Map<String, String>? headers,
    required bool withProgress,
    int? maxHeight,
    int? maxWidth,
  }) async* {
    final epoch = generatedImageEpoch.value;
    final resizedKey = resizedImageCacheKey(
      key ?? url,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final cached = await getFileFromCache(resizedKey);
    if (cached != null) {
      yield cached;
      if (cached.validTill.isAfter(DateTime.now())) return;
      withProgress = false;
    }
    await for (final response in getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    )) {
      if (response is! FileInfo) {
        yield response;
        continue;
      }
      if (epoch != generatedImageEpoch.value || isClearing) {
        throw StateError('图片请求已取消');
      }
      final extension = response.file.path.split('.').last.toLowerCase();
      if (!const {
        'jpg',
        'jpeg',
        'png',
        'tga',
        'cur',
        'ico',
      }.contains(extension)) {
        yield response;
        continue;
      }
      final bytes = await response.file.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final ui.ImageDescriptor descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
      } catch (_) {
        buffer.dispose();
        rethrow;
      }
      int width;
      int height;
      try {
        final factor = math.min(
          1.0,
          math.min(
            maxWidth == null ? 1.0 : maxWidth / descriptor.width,
            maxHeight == null ? 1.0 : maxHeight / descriptor.height,
          ),
        );
        width = math.max(1, (descriptor.width * factor).round());
        height = math.max(1, (descriptor.height * factor).round());
        if (factor >= 1) {
          yield response;
          continue;
        }
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width,
        targetHeight: height,
      );
      ui.Image? image;
      Uint8List resized;
      try {
        image = (await codec.getNextFrame()).image;
        resized = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        image?.dispose();
        codec.dispose();
      }
      if (epoch != generatedImageEpoch.value || isClearing) {
        throw StateError('图片请求已取消');
      }
      final file = await putFile(
        url,
        resized,
        key: resizedKey,
        maxAge: response.validTill.difference(DateTime.now()),
        fileExtension: 'png',
      );
      yield FileInfo(
        file,
        response.source,
        response.validTill,
        response.originalUrl,
      );
    }
  }
}

/// 上游下载和缩放不 await 索引入库，防止清理先于最后一次入库完成。
class _ImageCacheStore extends CacheStore {
  _ImageCacheStore(super.config);
  Future<void> _writes = Future<void>.value();

  @override
  Future<void> putFile(CacheObject object) {
    final result = _writes.then((_) => super.putFile(object));
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<void> emptyCache() async {
    await _writes;
    await super.emptyCache();
  }
}

/// 图片缓存超过这个时间未被访问即由上游清洗删除。
const appImageCacheStalePeriod = Duration(days: 14);

/// 图片缓存的磁盘体积上限，超出后按最久未访问优先删除。
const appImageCacheMaxBytes = 512 << 20;

/// 体积清理不碰这段时间内访问过的条目，避免删掉正在加载或展示的文件。
const _recentlyTouchedGrace = Duration(minutes: 10);

/// 按最久未访问优先，选出使总体积回落到 [maxBytes] 以内需要删除的条目。
@visibleForTesting
List<CacheObject> selectImageCacheEntriesOverBudget(
  List<CacheObject> objects, {
  required int maxBytes,
  required int Function(CacheObject object) sizeOf,
  required DateTime now,
}) {
  var total = 0;
  for (final object in objects) {
    total += sizeOf(object);
  }
  if (total <= maxBytes) return const [];

  final protectedSince = now.subtract(_recentlyTouchedGrace);
  final candidates =
      objects
          .where((object) => !_touchedAt(object).isAfter(protectedSince))
          .toList()
        ..sort((a, b) => _touchedAt(a).compareTo(_touchedAt(b)));
  final victims = <CacheObject>[];
  for (final object in candidates) {
    if (total <= maxBytes) break;
    victims.add(object);
    total -= sizeOf(object);
  }
  return victims;
}

DateTime _touchedAt(CacheObject object) =>
    object.touched ?? DateTime.fromMillisecondsSinceEpoch(0);

/// 去掉 URL 中的鉴权 token，作为缓存键使用。
///
/// token 拼在 query 里的图片地址每次换 token 都会变化，直接用 URL 作缓存
/// 键会让同一张图在磁盘上按 token 存出多份。
String stableImageCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.queryParameters.containsKey('token')) return url;
  final query = Map.of(uri.queryParametersAll)..remove('token');
  if (query.isNotEmpty) return uri.replace(queryParameters: query).toString();
  return uri.replace(query: '').toString().replaceFirst(RegExp(r'\?$'), '');
}

/// 与 flutter_cache_manager 的 [ImageCacheManager] 相同的 resized 缓存键规则。
@visibleForTesting
String resizedImageCacheKey(String key, {int? maxWidth, int? maxHeight}) {
  var resizedKey = 'resized';
  if (maxWidth != null) resizedKey += '_w$maxWidth';
  if (maxHeight != null) resizedKey += '_h$maxHeight';
  return '${resizedKey}_$key';
}

/// 按 key 共享进行中的文件加载。
///
/// 后加入的订阅者会先收到已产出的最新 [FileInfo]，再接收后续事件；
/// 源流结束时先移除 key 再通知完成，之后的请求重新发起。源流结束却没有
/// 产出任何 [FileInfo] 时向订阅者报错，让上层的错误重试接管，而不是
/// 永久挂起。
@visibleForTesting
class SharedFileResponseLoads {
  final Map<String, _SharedFileResponseLoad> _loads = {};

  bool isLoading(String key) => _loads.containsKey(key);

  Future<void> get idle =>
      Future.wait(_loads.values.map((load) => load.done.future));

  Stream<FileResponse> share(
    String key,
    Stream<FileResponse> Function() start,
  ) {
    final existing = _loads[key];
    if (existing != null) return existing.subscribe();

    late final _SharedFileResponseLoad load;
    load = _SharedFileResponseLoad(
      key: key,
      onFinished: () {
        if (identical(_loads[key], load)) _loads.remove(key);
      },
    );
    _loads[key] = load;
    final stream = load.subscribe();
    load.start(start);
    return stream;
  }
}

class _SharedFileResponseLoad {
  _SharedFileResponseLoad({required this.key, required this.onFinished});

  final String key;
  final VoidCallback onFinished;

  final Set<StreamController<FileResponse>> _subscribers = {};
  StreamSubscription<FileResponse>? _source;
  FileInfo? _latestFile;
  bool _finished = false;
  final done = Completer<void>();

  Stream<FileResponse> subscribe() {
    late final StreamController<FileResponse> controller;
    controller = StreamController<FileResponse>(
      // 订阅者离开只移除自身，底层加载继续把文件写入缓存。
      onCancel: () => _subscribers.remove(controller),
    );
    final latest = _latestFile;
    if (latest != null) controller.add(latest);
    _subscribers.add(controller);
    return controller.stream;
  }

  void start(Stream<FileResponse> Function() open) {
    final Stream<FileResponse> stream;
    try {
      stream = open();
    } on Object catch (error, stackTrace) {
      _fail(error, stackTrace);
      return;
    }
    _source = stream.listen(_onData, onError: _fail, onDone: _onDone);
  }

  void _onData(FileResponse response) {
    if (_finished) return;
    if (response is FileInfo) _latestFile = response;
    for (final subscriber in [..._subscribers]) {
      subscriber.add(response);
    }
  }

  void _onDone() {
    if (_finished) return;
    if (_latestFile == null) {
      _fail(StateError('图片加载结束但没有得到文件: $key'));
      return;
    }
    _finish();
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_finished) return;
    for (final subscriber in [..._subscribers]) {
      subscriber.addError(error, stackTrace);
    }
    _finish();
  }

  void _finish() {
    _finished = true;
    done.complete();
    unawaited(_source?.cancel());
    _source = null;
    onFinished();
    for (final subscriber in [..._subscribers]) {
      unawaited(subscriber.close());
    }
    _subscribers.clear();
  }
}
