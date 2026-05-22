import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/related_movie.dart';

void main() {
  test('RelatedMovie.fromJson decodes all fields including snake_case keys', () {
    final json = {
      'id': 7,
      'title': '示例',
      'num': 'ABC-001',
      'movie_part': 'A',
      'year': 2023,
      'rating': 8.4,
      'runtime': 120,
      'poster_uuid': 'p-uuid',
      'thumb_uuid': 't-uuid',
      'fanart_uuid': 'f-uuid',
      'matching_actors': [
        {'id': 1, 'name': 'Actor 1'},
      ],
    };
    final m = RelatedMovie.fromJson(json);
    expect(m.id, 7);
    expect(m.moviePart, 'A');
    expect(m.posterUuid, 'p-uuid');
    expect(m.matchingActors.first.name, 'Actor 1');
  });

  test('RelatedMovie.fromJson handles missing optional fields', () {
    final m = RelatedMovie.fromJson({'id': 1, 'title': 't'});
    expect(m.year, isNull);
    expect(m.matchingActors, isEmpty);
  });
}
