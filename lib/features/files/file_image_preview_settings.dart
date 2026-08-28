import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 是否在文件管理器列表中加载图片缩略图。
class FileImagePreviewNotifier extends Notifier<bool> {
  static const _preferenceKey = 'file.image_preview_enabled';

  @override
  bool build() {
    return ref.read(sharedPrefsProvider).getBool(_preferenceKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    final previous = state;
    state = enabled;
    try {
      await ref.read(sharedPrefsProvider).setBool(_preferenceKey, enabled);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final fileImagePreviewProvider =
    NotifierProvider<FileImagePreviewNotifier, bool>(
      FileImagePreviewNotifier.new,
    );
