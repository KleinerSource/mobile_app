import 'package:shared_preferences/shared_preferences.dart';

import 'list_model.dart';

/// 本地 lists 仓库 · SharedPreferences 持久化
class ListsRepository {
  ListsRepository(this._prefs);

  static const _key = 'favorite_lists.v1';

  final SharedPreferences _prefs;

  /// 读取全部 lists; 首次启动写入默认 4 个内置 list
  List<FavoriteList> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      final defaults = FavoriteList.defaults();
      _persist(defaults);
      return defaults;
    }
    return FavoriteList.decodeAll(raw);
  }

  Future<void> _persist(List<FavoriteList> lists) async {
    await _prefs.setString(_key, FavoriteList.encodeAll(lists));
  }

  Future<List<FavoriteList>> addMovie(String listId, int movieId) async {
    final lists = loadAll();
    final idx = lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return lists;
    if (!lists[idx].movieIds.contains(movieId)) {
      lists[idx].movieIds.insert(0, movieId);
      await _persist(lists);
    }
    return lists;
  }

  Future<List<FavoriteList>> removeMovie(String listId, int movieId) async {
    final lists = loadAll();
    final idx = lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return lists;
    if (lists[idx].movieIds.remove(movieId)) {
      await _persist(lists);
    }
    return lists;
  }

  Future<List<FavoriteList>> create({
    required String name,
    required int hue,
  }) async {
    final lists = loadAll();
    final id = 'list_${DateTime.now().millisecondsSinceEpoch}';
    lists.add(FavoriteList(id: id, name: name, hue: hue));
    await _persist(lists);
    return lists;
  }

  Future<List<FavoriteList>> rename(String listId, String name) async {
    final lists = loadAll();
    final idx = lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return lists;
    lists[idx].name = name;
    await _persist(lists);
    return lists;
  }

  Future<List<FavoriteList>> delete(String listId) async {
    final lists = loadAll();
    lists.removeWhere((l) => l.id == listId && !l.builtin);
    await _persist(lists);
    return lists;
  }

  /// 返回所有「包含 movieId」的 list id 集合
  Set<String> membershipsOf(int movieId) {
    final lists = loadAll();
    return lists
        .where((l) => l.movieIds.contains(movieId))
        .map((l) => l.id)
        .toSet();
  }
}
