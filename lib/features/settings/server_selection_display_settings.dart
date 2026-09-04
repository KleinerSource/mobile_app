import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 连接页是否使用 Emby/Jellyfin/FNOS 当前登录用户的身份信息。
class ServerSelectionShowUsernameNotifier extends Notifier<bool> {
  static const preferenceKey = 'server_selection.show_username';

  @override
  bool build() {
    return ref.read(sharedPrefsProvider).getBool(preferenceKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    final previous = state;
    state = enabled;
    try {
      await ref.read(sharedPrefsProvider).setBool(preferenceKey, enabled);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final serverSelectionShowUsernameProvider =
    NotifierProvider<ServerSelectionShowUsernameNotifier, bool>(
      ServerSelectionShowUsernameNotifier.new,
    );

/// 连接页是否使用 Emby/Jellyfin 当前登录用户的头像。
class ServerSelectionShowAvatarNotifier extends Notifier<bool> {
  static const preferenceKey = 'server_selection.show_avatar';

  @override
  bool build() {
    return ref.read(sharedPrefsProvider).getBool(preferenceKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    final previous = state;
    state = enabled;
    try {
      await ref.read(sharedPrefsProvider).setBool(preferenceKey, enabled);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final serverSelectionShowAvatarProvider =
    NotifierProvider<ServerSelectionShowAvatarNotifier, bool>(
      ServerSelectionShowAvatarNotifier.new,
    );
