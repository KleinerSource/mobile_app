import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../core/sources/files/file_entry.dart';

typedef FileThumbnailDownload =
    Future<Stream<List<int>>> Function(FileCancellationToken cancellation);

/// 页面内共享下载队列；已完成的图片字节仅由对应条目持有。
class FileThumbnailLoader {
  final Queue<FileThumbnailRequest> _pending = Queue();
  final Set<FileThumbnailRequest> _active = {};
  bool _disposed = false;

  FileThumbnailRequest load(FileThumbnailDownload download) {
    final request = FileThumbnailRequest._(download);
    if (_disposed) {
      request.release();
    } else {
      _pending.add(request);
      _pump();
    }
    return request;
  }

  void _pump() {
    while (!_disposed && _active.length < 2 && _pending.isNotEmpty) {
      final request = _pending.removeFirst();
      if (request._cancellation.isCancelled) continue;
      _active.add(request);
      unawaited(_download(request));
    }
  }

  Future<void> _download(FileThumbnailRequest request) async {
    try {
      final stream = await request._download(request._cancellation);
      final iterator = StreamIterator(stream);
      request._iterator = iterator;
      if (request._cancellation.isCancelled) return;
      final bytes = BytesBuilder(copy: false);
      while (await iterator.moveNext()) {
        if (request._cancellation.isCancelled) return;
        bytes.add(iterator.current);
      }
      if (!request._result.isCompleted) {
        request._result.complete(bytes.takeBytes());
      }
    } catch (error, stackTrace) {
      if (!request._result.isCompleted) {
        request._result.completeError(error, stackTrace);
      }
    } finally {
      await request._cancelIterator();
      _active.remove(request);
      _pump();
    }
  }

  void dispose() {
    _disposed = true;
    for (final request in [..._pending, ..._active]) {
      request.release();
    }
    _pending.clear();
  }
}

class FileThumbnailRequest {
  FileThumbnailRequest._(this._download);

  final FileThumbnailDownload _download;
  final _cancellation = FileCancellationToken();
  final _result = Completer<Uint8List?>();
  StreamIterator<List<int>>? _iterator;

  Future<Uint8List?> get bytes => _result.future;

  void release() {
    _cancellation.cancel();
    if (!_result.isCompleted) _result.complete(null);
    unawaited(_cancelIterator());
  }

  Future<void> _cancelIterator() async {
    final iterator = _iterator;
    _iterator = null;
    try {
      await iterator?.cancel();
    } catch (_) {
      // 请求已结束，取消订阅失败不应产生未处理的异步错误。
    }
  }
}
