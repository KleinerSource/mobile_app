import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/models/movie.dart';

const _viewedMovieIdsKey = 'home.movie_viewed_ids.v1';

/// 与网页端保持一致：新加入影片在两天内显示 NEW，打开详情后不再显示。
const recentlyAddedWindow = Duration(days: 2);

bool isUnreadRecentlyAddedMovie(
  MovieListItem movie,
  Set<int> viewedIds, {
  DateTime? now,
}) {
  if (viewedIds.contains(movie.id)) return false;
  final createdAt = movie.movieCreatedAt;
  if (createdAt == null) return false;
  final age = (now ?? DateTime.now()).difference(createdAt);
  return age >= Duration.zero && age <= recentlyAddedWindow;
}

class HomeMovieViewState extends ChangeNotifier {
  HomeMovieViewState(this._prefs) : _viewedIds = _loadViewedIds(_prefs);

  final SharedPreferences _prefs;
  final Set<int> _viewedIds;

  Set<int> viewedMovieIds() {
    return Set<int>.of(_viewedIds);
  }

  Future<void> markMovieViewed(int movieId) async {
    if (!_viewedIds.add(movieId)) return;
    notifyListeners();
    await _prefs.setStringList(
      _viewedMovieIdsKey,
      _viewedIds.map((id) => id.toString()).toList(),
    );
  }

  static Set<int> _loadViewedIds(SharedPreferences prefs) {
    final raw = prefs.getStringList(_viewedMovieIdsKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }
}

final homeMovieViewStateProvider = ChangeNotifierProvider<HomeMovieViewState>((
  ref,
) {
  return HomeMovieViewState(ref.watch(sharedPrefsProvider));
});
