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
    return ref.read(sharedPrefsProvider).getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool v) async {
    await ref.read(sharedPrefsProvider).setBool(_key, v);
    state = v;
    // 关闭隐私模式时,清空已揭开的列表
    // 开启时,所有先前揭开的也应重置 → 用户重新进入需再次揭
    ref.read(revealedMoviesProvider.notifier).clearAll();
    ref.read(revealedActorsProvider.notifier).clearAll();
    ref.read(revealedActorAssociationsProvider.notifier).clearAll();
  }
}

final privacyShieldProvider = NotifierProvider<PrivacyShieldNotifier, bool>(
  PrivacyShieldNotifier.new,
);

/// 是否允许通过摇动设备快速切换隐私模式。
class PrivacyShakeNotifier extends Notifier<bool> {
  static const _key = 'privacy.shake_to_toggle';

  @override
  bool build() {
    return ref.read(sharedPrefsProvider).getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool v) async {
    state = v;
    await ref.read(sharedPrefsProvider).setBool(_key, v);
  }
}

final privacyShakeProvider = NotifierProvider<PrivacyShakeNotifier, bool>(
  PrivacyShakeNotifier.new,
);

/// 当前 session 内被临时揭开的实体 id 集合 · 不持久化
/// 隐私模式开启时,内容被遮罩盖住,点击单卡片揭开该张
///
/// 每个数据域各一份实例:影片/演员/演员关联的 id 互不相关,
/// 共用一个集合会让"揭开影片 5"连带揭开"演员 5"。
///
/// id 保留原始类型，以兼容 OMM 的整数 id 和 dbonline 的字符串 id，
/// 避免把字符串哈希成整数带来的碰撞和不稳定。
class RevealedIdsNotifier extends Notifier<Set<Object>> {
  @override
  Set<Object> build() => const {};

  /// 揭开某张 · 同一 session 内有效
  void reveal(Object id) {
    if (state.contains(id)) return;
    state = {...state, id};
  }

  /// 重新遮罩 (例如关闭隐私模式或手动收起)
  void hide(Object id) {
    if (!state.contains(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }

  /// 清空所有揭开 (关闭隐私模式时调用)
  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }

  bool isRevealed(Object id) => state.contains(id);
}

final revealedMoviesProvider =
    NotifierProvider<RevealedIdsNotifier, Set<Object>>(RevealedIdsNotifier.new);

/// 演员域 · 演员管理页的揭示集合 (key 为演员 id)
final revealedActorsProvider =
    NotifierProvider<RevealedIdsNotifier, Set<Object>>(RevealedIdsNotifier.new);

/// 演员关联域 · 演员关联页的揭示集合 (key 为关联规则 id)
final revealedActorAssociationsProvider =
    NotifierProvider<RevealedIdsNotifier, Set<Object>>(RevealedIdsNotifier.new);
