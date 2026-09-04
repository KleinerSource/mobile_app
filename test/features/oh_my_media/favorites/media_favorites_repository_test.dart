import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/sources/common/source_id.dart';
import 'package:omm/core/sources/media/media_models.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/favorites/media_favorites_repository.dart';
import 'package:omm/features/oh_my_media/movies/movie_filter.dart';

void main() {
  test('解析收藏影片的观看记录和跨分页统计', () async {
    final source = _StubFavoritesSource(withStats: true);
    final repository = MediaFavoritesRepository(source);

    final result = await repository.list(
      const MovieFilter(),
      limit: 30,
      offset: 0,
    );

    expect(result.page.items, hasLength(1));
    expect(result.page.items.single.watchRecord?.completed, isTrue);
    expect(result.stats?.watchedCount, 2);
    expect(result.stats?.watchedMinutes, 180);
    expect(result.stats?.hours, 3);

    final local = FavoriteStats.fromMovies(result.page.items);
    expect(local.watchedCount, 1);
    expect(local.watchedMinutes, 120);
  });

  test('旧服务端没有统计字段时保留空统计以便页面回退本地计算', () async {
    final repository = MediaFavoritesRepository(
      _StubFavoritesSource(withStats: false),
    );

    final result = await repository.list(
      const MovieFilter(),
      limit: 30,
      offset: 0,
    );

    expect(result.stats, isNull);
  });

  test('批量收藏操作通过 OMM 收藏能力而非影片关联能力', () async {
    final source = _StubFavoritesSource();
    final repository = MediaFavoritesRepository(source);

    await repository.addBatch([1, 2]);
    await repository.removeBatch([3, 4]);

    expect(source.added?.map((movie) => movie.value), ['1', '2']);
    expect(source.removed?.map((movie) => movie.value), ['3', '4']);
  });
}

class _StubFavoritesSource implements OmmMediaOperationsSource {
  _StubFavoritesSource({this.withStats = true});

  final bool withStats;
  List<MediaRef>? added;
  List<MediaRef>? removed;

  @override
  Future<MediaPage<MediaSummary>> listFavorites(MediaQuery query) async {
    final movie = MovieListItem.fromJson({
      'id': 1,
      'title': 'Watched movie',
      'runtime': 120,
      'watch_record': {'progress_ratio': 1.0, 'completed': true},
    });
    return MediaPage(
      items: [
        MediaSummary(
          ref: const MediaRef(sourceId: SourceId('omm'), value: '1'),
          title: movie.title,
          duration: movie.runtime,
          payload: movie,
        ),
      ],
      page: query.page,
      limit: query.limit,
      total: 2,
      hasMore: false,
      metadata: {
        if (withStats) 'stats': {'watched_count': 2, 'watched_minutes': 180},
      },
    );
  }

  @override
  Future<void> addFavoriteBatch(List<MediaRef> movies) async {
    added = List<MediaRef>.from(movies);
  }

  @override
  Future<void> removeFavoriteBatch(List<MediaRef> movies) async {
    removed = List<MediaRef>.from(movies);
  }

  @override
  Future<PreviewStartResult> generatePreview(
    MediaRef movie, {
    bool overwrite = false,
  }) => throw UnimplementedError();

  @override
  Future<PreviewStatus> previewStatus(MediaRef movie, {String? taskId}) =>
      throw UnimplementedError();

  @override
  Future<PreviewTask> previewTask(String taskId) => throw UnimplementedError();

  @override
  Future<void> cancelPreviewTask(String taskId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
