import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/actor.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/models/resource.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/features/movies/detail/sections/taxonomy_section.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('empty movie renders nothing', (tester) async {
    await tester.pumpWidget(wrap(const TaxonomySection(
      movie: MovieDetail(id: 1, title: 't'),
    )));
    expect(find.text('系列'), findsNothing);
    expect(find.text('标签'), findsNothing);
    expect(find.text('分类'), findsNothing);
    expect(find.text('演员'), findsNothing);
  });

  testWidgets('renders only sections with content', (tester) async {
    await tester.pumpWidget(wrap(const TaxonomySection(
      movie: MovieDetail(
        id: 1,
        title: 't',
        tags: [ResourceItem(id: 1, name: '标签 A')],
        actors: [ActorItem(id: 2, name: '演员 X')],
      ),
    )));
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('标签 A'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('演员 X'), findsOneWidget);
    expect(find.text('系列'), findsNothing);
    expect(find.text('分类'), findsNothing);
  });
}
