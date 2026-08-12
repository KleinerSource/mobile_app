import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class HomeMovieViewState {
  HomeMovieViewState(this._prefs);

  final SharedPreferences _prefs;

  Set<int> viewedMovieIds() {
    final raw = _prefs.getStringList(_viewedMovieIdsKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> markMovieViewed(int movieId) async {
    final ids = viewedMovieIds()..add(movieId);
    await _prefs.setStringList(
      _viewedMovieIdsKey,
      ids.map((id) => id.toString()).toList(),
    );
  }
}

final homeMovieViewStateProvider = Provider<HomeMovieViewState>((ref) {
  return HomeMovieViewState(ref.watch(sharedPrefsProvider));
});
