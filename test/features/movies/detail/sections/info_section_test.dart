import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/sections/info_section.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('renders only fields that are present', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't', num: 'ABC-001', year: 2020),
    )));
    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('国家'), findsNothing);
    expect(find.text('评分'), findsNothing);
  });

  testWidgets('formats file size 4500000000 as 4.2 GB', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't', fileSize: 4500000000),
    )));
    expect(find.text('4.2 GB'), findsOneWidget);
  });

  testWidgets('formats runtime 125 minutes as 2 小时 5 分钟', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't', runtime: 125),
    )));
    expect(find.text('2 小时 5 分钟'), findsOneWidget);
  });

  testWidgets('empty data renders nothing visible', (tester) async {
    await tester.pumpWidget(wrap(const InfoSection(
      movie: MovieDetail(id: 1, title: 't'),
    )));
    expect(find.byType(InfoSection), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
