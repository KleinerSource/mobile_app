import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/config/server_runtime.dart';

const _keyPrefix = 'visited.movies.v1.';

/// 单服务器最多保留的已浏览 id 数；超出后按进入顺序淘汰最旧的。
const maxVisitedMovies = 10000;

/// 进入过影片详情页的跨源记录 · 卡片标题据此置灰。
///
/// OMM 的整数 id 与外部源（DBO/Emby/Jellyfin/FNOS/Stash）的字符串 id
/// 统一按 toString 归一化存储；记录按 media lane 的服务器隔离，不同
/// 服务器的 id 空间互不干扰（模式同 search_history）。
class VisitedMoviesState extends ChangeNotifier {
  VisitedMoviesState(this._prefs, this._serverId)
    : _ids = _load(_prefs, _serverId);

  final SharedPreferences _prefs;
  final String _serverId;
  final LinkedHashSet<String> _ids;

  bool isVisited(Object? id) {
    if (id == null) return false;
    return _ids.contains(_normalize(id));
  }

  Future<void> markVisited(Object id) async {
    if (!_ids.add(_normalize(id))) return;
    notifyListeners();
    await _prefs.setStringList(
      '$_keyPrefix$_serverId',
      _ids.toList(growable: false),
    );
  }

  static String _normalize(Object id) => id.toString().trim();

  static LinkedHashSet<String> _load(
    SharedPreferences prefs,
    String serverId,
  ) {
    final raw = prefs.getStringList('$_keyPrefix$serverId');
    final ids = LinkedHashSet<String>.of(raw ?? const <String>[]);
    while (ids.length > maxVisitedMovies) {
      ids.remove(ids.first);
    }
    return ids;
  }
}

/// 换服务器时重建状态：isVisited/markVisited 自动作用于当前服务器的集合。
final visitedMoviesProvider = ChangeNotifierProvider<VisitedMoviesState>((
  ref,
) {
  final serverId =
      ref.watch(
        serverRuntimeProvider.select((runtime) => runtime.media.serverId),
      ) ??
      '';
  return VisitedMoviesState(ref.watch(sharedPrefsProvider), serverId);
});

/// 卡片渲染用的便捷读取：id 为 null（无隐私键的目录卡）或读取失败
/// （如测试环境未提供 SharedPreferences 覆盖）时恒为 false——置灰是
/// 纯展示增强，绝不让卡片网格因它抛错。
bool watchMovieVisited(WidgetRef ref, Object? id) {
  if (id == null) return false;
  try {
    return ref.watch(visitedMoviesProvider).isVisited(id);
  } catch (_) {
    return false;
  }
}

/// 详情入口的便捷记录；记录失败（同上）不影响详情页渲染或导航。
void markMovieVisited(WidgetRef ref, Object id) {
  try {
    unawaited(ref.read(visitedMoviesProvider).markVisited(id));
  } catch (_) {}
}
