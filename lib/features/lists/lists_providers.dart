import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import 'list_model.dart';
import 'lists_repository.dart';

final listsRepositoryProvider = Provider<ListsRepository>((ref) {
  return ListsRepository(ref.watch(sharedPrefsProvider));
});

/// 全局 lists 状态 · 写操作走 Notifier · 读操作直接 watch
class ListsNotifier extends Notifier<List<FavoriteList>> {
  @override
  List<FavoriteList> build() {
    return ref.read(listsRepositoryProvider).loadAll();
  }

  // repo 内部对 List<FavoriteList> 是 mutate-in-place,引用相同 Riverpod 不通知;
  // 这里 deep-copy 一遍保证 state 引用变化触发 watchers 重渲染。
  List<FavoriteList> _clone(List<FavoriteList> src) =>
      src.map((l) => l.copy()).toList();

  Future<void> addMovie(String listId, int movieId) async {
    final next = await ref.read(listsRepositoryProvider).addMovie(listId, movieId);
    state = _clone(next);
  }

  Future<void> removeMovie(String listId, int movieId) async {
    final next = await ref.read(listsRepositoryProvider).removeMovie(listId, movieId);
    state = _clone(next);
  }

  Future<FavoriteList?> create({required String name, required int hue}) async {
    final lists = await ref.read(listsRepositoryProvider).create(name: name, hue: hue);
    state = _clone(lists);
    return lists.isEmpty ? null : lists.last;
  }

  Future<void> rename(String listId, String name) async {
    final next = await ref.read(listsRepositoryProvider).rename(listId, name);
    state = _clone(next);
  }

  Future<void> delete(String listId) async {
    final next = await ref.read(listsRepositoryProvider).delete(listId);
    state = _clone(next);
  }

  FavoriteList? byId(String id) {
    try {
      return state.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}

final listsProvider =
    NotifierProvider<ListsNotifier, List<FavoriteList>>(ListsNotifier.new);

/// 某 list 的实时引用
final favoriteListProvider =
    Provider.family<FavoriteList?, String>((ref, id) {
  final all = ref.watch(listsProvider);
  try {
    return all.firstWhere((l) => l.id == id);
  } catch (_) {
    return null;
  }
});
