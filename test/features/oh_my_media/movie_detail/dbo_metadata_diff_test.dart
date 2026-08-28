import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/actor.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/features/oh_my_media/movie_detail/dbo_metadata_diff.dart';

void main() {
  test('解析 DBO 影片信息字段并生成差异', () {
    const movie = MovieDetail(
      id: 7,
      title: '旧标题',
      rating: 6.0,
      runtime: 90,
      plot: '旧简介',
      year: 2023,
      genres: [ResourceItem(id: 1, name: '剧情')],
      actors: [ActorItem(id: 2, name: '旧演员')],
      series: ResourceItem(id: 3, name: '旧系列'),
    );

    final diff = buildDboMetadataDiff(movie, {
      'code': 'ABC-001',
      'title': '新标题',
      'score': 8.5,
      'duration': 120,
      'overview': '新简介',
      'date': '2024-05-01',
      'series': {'name': '新系列'},
      'categories': [
        {'name': '喜剧'},
      ],
      'actors': [
        {'name': '新演员', 'gender': 'female'},
      ],
    });

    final info = diff.items
        .where((item) => item.section == DboMetadataDiffSection.info)
        .toList();
    expect(diff.code, 'ABC-001');
    expect(diff.title, '新标题');
    expect(
      info.map((item) => item.field),
      containsAll(['title', 'rating', 'runtime', 'plot', 'year']),
    );
    expect(info.firstWhere((item) => item.field == 'rating').value, 8.5);
    expect(info.firstWhere((item) => item.field == 'runtime').value, 120);
    expect(info.firstWhere((item) => item.field == 'plot').value, '新简介');
  });

  test('分类、演员和系列差异包含增删信息', () {
    const movie = MovieDetail(
      id: 7,
      title: '影片',
      genres: [ResourceItem(id: 1, name: '旧分类')],
      actors: [ActorItem(id: 2, name: '旧演员')],
      series: ResourceItem(id: 3, name: '旧系列'),
    );

    final diff = buildDboMetadataDiff(movie, {
      'categories': [
        {'name': '新分类'},
      ],
      'actors': [
        {'name': '新演员', 'gender': 'female'},
      ],
      'series': {'name': '新系列'},
    });

    expect(
      diff.items.where((item) => item.section == DboMetadataDiffSection.genres),
      isNotEmpty,
    );
    expect(
      diff.items
          .where((item) => item.section == DboMetadataDiffSection.genres)
          .map((item) => item.action),
      containsAll([DboMetadataDiffAction.add, DboMetadataDiffAction.remove]),
    );
    expect(
      diff.items
          .where((item) => item.section == DboMetadataDiffSection.actors)
          .map((item) => item.action),
      containsAll([DboMetadataDiffAction.add, DboMetadataDiffAction.remove]),
    );
    final addedActor = diff.items.firstWhere(
      (item) =>
          item.section == DboMetadataDiffSection.actors &&
          item.action == DboMetadataDiffAction.add,
    );
    expect(addedActor.gender, 'female');
    final series = diff.items.firstWhere(
      (item) => item.section == DboMetadataDiffSection.series,
    );
    expect(series.action, DboMetadataDiffAction.replace);
    expect(series.remoteName, '新系列');
    expect(series.localId, 3);
  });
}
