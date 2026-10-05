import 'dart:async';

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
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  AppImageCacheManager._()
    : super(
        Config(
          DefaultCacheManager.key,
          maxNrOfCacheObjects: 3000,
          fileService: AppImageFileService(),
        ),
      );

  static final AppImageCacheManager instance = AppImageCacheManager._();

  final SharedFileResponseLoads _resizedLoads = SharedFileResponseLoads();

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
