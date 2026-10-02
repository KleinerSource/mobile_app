import 'dart:async';

import 'package:flutter/widgets.dart';

/// 合并滚动/选择变化，并在布局完成后选出唯一自动预览条目。
class AutoPreviewController<T> extends ValueNotifier<T?> {
  AutoPreviewController({
    required this.candidate,
    this.debounce = const Duration(milliseconds: 180),
  }) : super(null);

  final T? Function() candidate;
  final Duration debounce;
  Timer? _timer;
  bool _frameScheduled = false;
  int _generation = 0;
  bool _disposed = false;

  void schedule() {
    if (_disposed) return;
    if (debounce == Duration.zero && _frameScheduled) return;
    final generation = ++_generation;
    _timer?.cancel();
    if (debounce == Duration.zero) {
      _scheduleFrame(generation);
      return;
    }
    _timer = Timer(debounce, () {
      _timer = null;
      _scheduleFrame(generation);
    });
  }

  void _scheduleFrame(int generation) {
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _generation) return;
      _frameScheduled = false;
      value = candidate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _frameScheduled = false;
    value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
