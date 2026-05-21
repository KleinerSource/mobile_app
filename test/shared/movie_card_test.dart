import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/shared/movie_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('显示标题', (tester) async {
    await tester.pumpWidget(wrap(MovieCard(
      movie: const MovieListItem(id: 1, title: '示例片名'),
      posterUrlBuilder: (u) => 'http://x/$u',
    )));
    expect(find.text('示例片名'), findsOneWidget);
  });

  testWidgets('completed=true 显示已看完角标', (tester) async {
    await tester.pumpWidget(wrap(MovieCard(
      movie: const MovieListItem(
        id: 1,
        title: 'A',
        watchRecord: WatchRecordSummary(progressRatio: 1.0, completed: true),
      ),
      posterUrlBuilder: (u) => 'http://x/$u',
    )));
    expect(find.text('已看完'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('未完成有进度时显示进度条', (tester) async {
    await tester.pumpWidget(wrap(MovieCard(
      movie: const MovieListItem(
        id: 1,
        title: 'A',
        watchRecord: WatchRecordSummary(progressRatio: 0.4, completed: false),
      ),
      posterUrlBuilder: (u) => 'http://x/$u',
    )));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
