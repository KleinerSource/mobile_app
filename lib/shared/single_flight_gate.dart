/// 保证同一类异步启动操作在前一次完成前最多执行一次。
class SingleFlightGate {
  bool _running = false;

  bool get isRunning => _running;

  Future<void> run(Future<void> Function() action) async {
    if (_running) return;
    _running = true;
    try {
      await action();
    } finally {
      _running = false;
    }
  }

  Future<T?> runWithResult<T>(Future<T?> Function() action) async {
    if (_running) return null;
    _running = true;
    try {
      return await action();
    } finally {
      _running = false;
    }
  }
}
