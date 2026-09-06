import 'dart:async';

import 'package:flutter/widgets.dart';

/// 合并滚动/选择变化，并在布局完成后选出唯一自动预览条目。
class AutoPreviewController<T> extends ValueNotifier<T?> {
  AutoPreviewController({required this.candidate}) : super(null);

  final T? Function() candidate;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  void schedule() {
    if (_disposed) return;
    final generation = ++_generation;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), () {
      _timer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || generation != _generation) return;
        value = candidate();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
