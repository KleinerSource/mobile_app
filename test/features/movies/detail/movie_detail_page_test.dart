import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/movie_detail_page.dart';
import 'package:md_center/features/movies/movies_providers.dart';
import 'package:md_center/features/movies/movies_repository.dart';

class _FakeRepo implements MoviesRepository {
  _FakeRepo(this._detail);
  final MovieDetail _detail;

  @override
  Future<MovieDetail> detail(int id) async => _detail;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ErrRepo implements MoviesRepository {
  @override
  Future<MovieDetail> detail(int id) async => throw Exception('boom');
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget wrap(Widget child, MoviesRepository repo) => ProviderScope(
        overrides: [
          moviesRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(theme: appTheme(Brightness.light), home: child),
      );

  testWidgets('loading state shows CircularProgressIndicator', (tester) async {
    final repo = _FakeRepo(const MovieDetail(id: 1, title: 't'));
    await tester.pumpWidget(wrap(const MovieDetailPage(movieId: 1), repo));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('data state shows title in body', (tester) async {
    final repo = _FakeRepo(const MovieDetail(id: 1, title: '示例片名'));
    await tester.pumpWidget(wrap(const MovieDetailPage(movieId: 1), repo));
    await tester.pumpAndSettle();
    expect(find.text('示例片名'), findsWidgets);
  });

  testWidgets('error state shows ErrorView with retry', (tester) async {
    await tester.pumpWidget(wrap(const MovieDetailPage(movieId: 1), _ErrRepo()));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });
}
