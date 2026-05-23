import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';

/// 隐私模式 · 仅做 App Switcher 防窥遮罩
///
/// 启用后,App 进入 inactive/paused (iOS 切到 App Switcher / Android Recents)
/// 时,顶层 widget 盖一层全屏遮罩,防止预览图泄露内容。
class PrivacyShieldNotifier extends Notifier<bool> {
  static const _key = 'privacy.app_switcher_shield';

  @override
  bool build() {
    return ref.read(sharedPrefsProvider).getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool v) async {
    await ref.read(sharedPrefsProvider).setBool(_key, v);
    state = v;
    // 关闭隐私模式时,清空已揭开的列表
    // 开启时,所有先前揭开的也应重置 → 用户重新进入需再次揭
    ref.read(revealedMoviesProvider.notifier).clearAll();
  }
}

final privacyShieldProvider =
    NotifierProvider<PrivacyShieldNotifier, bool>(PrivacyShieldNotifier.new);

/// 当前 session 内被临时揭开的影片 id 集合 · 不持久化
/// 隐私模式开启时,海报与标题被遮罩盖住,点击单卡片揭开该张
class RevealedMoviesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  /// 揭开某张 · 同一 session 内有效
  void reveal(int id) {
    if (state.contains(id)) return;
    state = {...state, id};
  }

  /// 重新遮罩 (例如关闭隐私模式或手动收起)
  void hide(int id) {
    if (!state.contains(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }

  /// 清空所有揭开 (关闭隐私模式时调用)
  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }

  bool isRevealed(int id) => state.contains(id);
}

final revealedMoviesProvider =
    NotifierProvider<RevealedMoviesNotifier, Set<int>>(
  RevealedMoviesNotifier.new,
);
