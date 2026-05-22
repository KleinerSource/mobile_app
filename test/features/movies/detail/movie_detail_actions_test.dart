import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/movie_detail_actions.dart';
import 'package:md_center/features/movies/movies_providers.dart';
import 'package:md_center/features/movies/movies_repository.dart';

class _RecordingRepo implements MoviesRepository {
  bool? toggledFavorite;
  bool? markedCompleted;

  @override
  Future<bool> toggleFavorite(int id) async {
    toggledFavorite = true;
    return true;
  }

  @override
  Future<void> markWatched(int id, bool completed) async {
    markedCompleted = completed;
  }

  @override
  Future<MovieDetail> detail(int id) async =>
      const MovieDetail(id: 1, title: 't');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget wrap(Widget child, MoviesRepository repo) => ProviderScope(
        overrides: [moviesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: appTheme(Brightness.light), home: Scaffold(body: child)),
      );

  testWidgets('shows "收藏" when not favorited', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      _RecordingRepo(),
    ));
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('已收藏'), findsNothing);
  });

  testWidgets('shows "已收藏" when isFavorited=true', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(
          movie: MovieDetail(id: 1, title: 't', isFavorited: true)),
      _RecordingRepo(),
    ));
    expect(find.text('已收藏'), findsOneWidget);
  });

  testWidgets('shows "标记看完" when not completed', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      _RecordingRepo(),
    ));
    expect(find.text('标记看完'), findsOneWidget);
  });

  testWidgets('shows "已看完" when watchRecord.completed=true', (tester) async {
    await tester.pumpWidget(wrap(
      const MovieDetailActions(
        movie: MovieDetail(
          id: 1,
          title: 't',
          watchRecord: WatchRecordSummary(progressRatio: 1, completed: true),
        ),
      ),
      _RecordingRepo(),
    ));
    expect(find.text('已看完'), findsOneWidget);
  });

  testWidgets('tap on favorite button calls repository.toggleFavorite', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      repo,
    ));
    await tester.tap(find.text('收藏'));
    await tester.pump();
    expect(repo.toggledFavorite, true);
  });

  testWidgets('tap on watched button calls repository.markWatched(true)', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(wrap(
      const MovieDetailActions(movie: MovieDetail(id: 1, title: 't')),
      repo,
    ));
    await tester.tap(find.text('标记看完'));
    await tester.pump();
    expect(repo.markedCompleted, true);
  });
}
