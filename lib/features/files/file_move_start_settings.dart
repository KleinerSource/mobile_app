import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 移动文件时目标目录选择器的起始位置。
enum FileMoveStartLocation {
  /// 每次从根目录开始选择（默认，行为与历史版本一致）。
  root,

  /// 从移动操作发起时所在的目录开始选择。
  current,
}

/// 移动文件目录选择器的起始位置偏好（全局，不区分服务器）。
class FileMoveStartNotifier extends Notifier<FileMoveStartLocation> {
  static const _preferenceKey = 'file.move_start_location';

  @override
  FileMoveStartLocation build() {
    final stored = ref.read(sharedPrefsProvider).getString(_preferenceKey);
    for (final location in FileMoveStartLocation.values) {
      if (location.name == stored) return location;
    }
    return FileMoveStartLocation.root;
  }

  Future<void> setLocation(FileMoveStartLocation location) async {
    if (location == state) return;
    final previous = state;
    state = location;
    try {
      await ref
          .read(sharedPrefsProvider)
          .setString(_preferenceKey, location.name);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final fileMoveStartProvider =
    NotifierProvider<FileMoveStartNotifier, FileMoveStartLocation>(
      FileMoveStartNotifier.new,
    );
