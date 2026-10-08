import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

class FileVideoPreviewNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool('file.video_preview_enabled') ??
      true;

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    final previous = state;
    state = enabled;
    try {
      await ref
          .read(sharedPrefsProvider)
          .setBool('file.video_preview_enabled', enabled);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final fileVideoPreviewProvider =
    NotifierProvider<FileVideoPreviewNotifier, bool>(
      FileVideoPreviewNotifier.new,
    );
