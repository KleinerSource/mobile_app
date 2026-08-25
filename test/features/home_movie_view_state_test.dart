import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/home/home_movie_view_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('最近加入且未打开的影片显示 NEW', () {
    final now = DateTime.utc(2026, 8, 12, 12);
    final movie = MovieListItem(
      id: 1,
      title: '新影片',
      movieCreatedAt: now.subtract(const Duration(hours: 6)),
    );

    expect(isUnreadRecentlyAddedMovie(movie, <int>{}, now: now), isTrue);
    expect(isUnreadRecentlyAddedMovie(movie, <int>{1}, now: now), isFalse);
    expect(
      isUnreadRecentlyAddedMovie(
        movie.copyWith(movieCreatedAt: now.subtract(const Duration(days: 3))),
        <int>{},
        now: now,
      ),
      isFalse,
    );
  });

  test('已打开影片的状态会持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = HomeMovieViewState(prefs);

    await state.markMovieViewed(42);

    expect(state.viewedMovieIds(), contains(42));
  });
}
