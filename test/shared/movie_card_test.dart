import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/shared/movie_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 120, child: child),
          ),
        ),
      );

  MovieCard card(MovieListItem movie) => MovieCard(
        movie: movie,
        posterUrlBuilder: (u) => 'http://x/$u',
      );

  testWidgets('显示标题', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: '示例片名'),
    )));
    expect(find.text('示例片名'), findsOneWidget);
  });

  testWidgets('completed=true 显示已看完角标', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(
        id: 1,
        title: 'A',
        watchRecord: WatchRecordSummary(progressRatio: 1.0, completed: true),
      ),
    )));
    expect(find.text('已看完'), findsOneWidget);
  });

  testWidgets('未完成有进度时显示进度条', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(
        id: 1,
        title: 'A',
        watchRecord: WatchRecordSummary(progressRatio: 0.4, completed: false),
      ),
    )));
    expect(find.byKey(const ValueKey('movie-progress')), findsOneWidget);
  });

  testWidgets('is_updated 显示"已更新"角标', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', isUpdated: true),
    )));
    expect(find.text('已更新'), findsOneWidget);
  });

  testWidgets('is_favorited 显示"已收藏"角标', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', isFavorited: true),
    )));
    expect(find.text('已收藏'), findsOneWidget);
  });

  testWidgets('is_updated 优先于 is_favorited（互斥）', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(
        id: 1,
        title: 'A',
        isUpdated: true,
        isFavorited: true,
      ),
    )));
    expect(find.text('已更新'), findsOneWidget);
    expect(find.text('已收藏'), findsNothing);
  });

  testWidgets('rating 显示评分 badge（保留一位小数）', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', rating: 8.567),
    )));
    expect(find.text('8.6'), findsOneWidget);
  });

  testWidgets('has_external_subtitle 显示字幕 badge', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', hasExternalSubtitle: true),
    )));
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
  });

  testWidgets('num 显示番号 pill', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', num: 'ABC-001'),
    )));
    expect(find.text('ABC-001'), findsOneWidget);
  });

  testWidgets('year 显示年份', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', year: 2023),
    )));
    expect(find.text('2023'), findsOneWidget);
  });
}
