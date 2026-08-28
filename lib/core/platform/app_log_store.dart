import 'package:flutter/foundation.dart';

/// 应用内排障日志。
///
/// 日志保留在当前运行会话中，最多保存最近 500 条，避免影响播放器的
/// 内存占用。调试/ profile 包同时输出到系统控制台，release 包仍可在
/// 应用内查看，方便没有 Xcode 的 iOS 真机收集播放日志。
class AppLogStore {
  AppLogStore._();

  static final AppLogStore instance = AppLogStore._();

  static const maxEntries = 500;

  final ValueNotifier<List<String>> _entries = ValueNotifier<List<String>>(
    const <String>[],
  );

  ValueListenable<List<String>> get listenable => _entries;

  List<String> get entries => _entries.value;

  String get text => entries.join('\n');

  void add(String message) {
    final normalized = message.trimRight();
    if (normalized.isEmpty) return;
    final timestamp = DateTime.now().toIso8601String();
    final next = <String>[..._entries.value, '$timestamp $normalized'];
    if (next.length > maxEntries) {
      next.removeRange(0, next.length - maxEntries);
    }
    _entries.value = List<String>.unmodifiable(next);
  }

  void clear() {
    if (_entries.value.isEmpty) return;
    _entries.value = const <String>[];
  }
}

/// 记录一条应用日志，并在非 release 包输出到系统控制台。
void appLog(String message) {
  AppLogStore.instance.add(message);
  if (!kReleaseMode) debugPrint(message);
}
