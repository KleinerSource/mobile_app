import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 首页 Recently Added — 复用 /movies?sort_by=created_at&order=desc
final recentlyAddedProvider = FutureProvider<PagedResult<MovieListItem>>((ref) async {
  final repo = ref.watch(moviesRepositoryProvider);
  return repo.list(
    const MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
    limit: 12,
    offset: 0,
  );
});

/// Continue Watching — 取最近有 watch_record 且未完成的(在客户端筛)
final continueWatchingProvider = FutureProvider<List<MovieListItem>>((ref) async {
  final result = await ref.watch(recentlyAddedProvider.future);
  return result.items
      .where((m) {
        final r = m.watchRecord;
        if (r == null) return false;
        return !r.completed && r.progressRatio > 0.01 && r.progressRatio < 0.97;
      })
      .take(5)
      .toList();
});

/// 推荐轮播 — 取最近添加里 fanart/poster 不为空的前 10 条
/// 复用 recentlyAddedProvider 数据,客户端筛选,不发额外请求
final recommendCarouselProvider = FutureProvider<List<MovieListItem>>((ref) async {
  final result = await ref.watch(recentlyAddedProvider.future);
  return result.items
      .where((m) =>
          (m.fanartUuid != null && m.fanartUuid!.isNotEmpty) ||
          (m.posterUuid != null && m.posterUuid!.isNotEmpty) ||
          (m.thumbUuid != null && m.thumbUuid!.isNotEmpty))
      .take(10)
      .toList();
});
