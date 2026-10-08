import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/api/app_request_headers.dart';

class AppImageFileService extends FileService {
  AppImageFileService({FileService? delegate})
    : _delegate = delegate ?? HttpFileService();

  final FileService _delegate;

  @override
  int get concurrentFetches => _delegate.concurrentFetches;

  @override
  set concurrentFetches(int value) => _delegate.concurrentFetches = value;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _delegate.get(url, headers: await mergeAppRequestHeaders(headers));
  }
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
    : super(
        Config(
          DefaultCacheManager.key,
          stalePeriod: appImageCacheStalePeriod,
          maxNrOfCacheObjects: 3000,
          fileService: AppImageFileService(),
        ),
      );

  static final AppImageCacheManager instance = AppImageCacheManager._();

  @visibleForTesting
  AppImageCacheManager.forTesting(super.config);

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
    generatedImageEpoch.value++;
    return _enqueueMaintenance(() async {
      try {
        await super.emptyCache();
      } finally {
        _clearCount--;
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
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) {
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
      () => super.getImageFile(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
      ),
    );
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
    unawaited(_source?.cancel());
    _source = null;
    onFinished();
    for (final subscriber in [..._subscribers]) {
      unawaited(subscriber.close());
    }
    _subscribers.clear();
  }
}
