import 'dart:async';

/// 只协调请求生命周期；页码、末页和条目合并策略由调用方决定。
class PagedRequestCoordinator {
  PagedRequestCoordinator({this.firstPageKey = 0});

  final Object firstPageKey;
  int _generation = 0;
  bool _disposed = false;
  final Set<Object> _inFlight = {};
  Completer<void>? _refresh;

  bool get isDisposed => _disposed;

  PagedRequest? begin(Object key) {
    if (_disposed || !_inFlight.add(key)) return null;
    return PagedRequest._(this, key, _generation);
  }

  /// 执行一页请求并统一隔离过期响应；数据解析和分页提交由调用方负责。
  Future<void> execute<T>({
    required Object key,
    required Future<T> Function() load,
    required void Function(T result) onSuccess,
    required void Function(Object error) onError,
  }) async {
    final request = begin(key);
    if (request == null) return;
    try {
      final result = await load();
      if (request.isCurrent) onSuccess(result);
    } catch (error) {
      if (request.isCurrent) onError(error);
    } finally {
      request.finish();
    }
  }

  void invalidate() {
    _generation++;
    _inFlight.clear();
    _completeRefresh();
  }

  Future<void> refresh(void Function() reload) {
    if (_disposed) return Future<void>.value();
    final pending = _refresh;
    if (pending != null) return pending.future;
    invalidate();
    final completer = Completer<void>();
    _refresh = completer;
    try {
      reload();
    } catch (_) {
      _completeRefresh();
      rethrow;
    }
    return completer.future;
  }

  void _completeRefresh() {
    final pending = _refresh;
    _refresh = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}

class PagedRequest {
  PagedRequest._(this._owner, this._key, this._generation);

  final PagedRequestCoordinator _owner;
  final Object _key;
  final int _generation;
  bool _finished = false;

  bool get isCurrent =>
      !_finished && !_owner._disposed && _generation == _owner._generation;

  void finish() {
    if (isCurrent) {
      _owner._inFlight.remove(_key);
      if (_key == _owner.firstPageKey) _owner._completeRefresh();
    }
    _finished = true;
  }
}
