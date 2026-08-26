import 'dart:async';

import 'package:flutter/foundation.dart';

/// 搜索输入等场景的防抖器: 每次 [run] 重置计时,停顿 [duration] 后执行最后一次回调。
///
/// 统一全应用搜索防抖时长为 300ms。持有者需在 dispose 时调用 [dispose]
/// (或先 [cancel]) 取消挂起的回调,避免触发已卸载组件的 setState。
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;

  Timer? _timer;

  bool get isActive => _timer?.isActive ?? false;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
