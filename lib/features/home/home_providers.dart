import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../libraries/libraries_providers.dart';
import '../movies/movie_filter.dart';
import '../movies/movies_providers.dart';

/// 首页 Recently Added — 复用 /movies?sort_by=created_at&order=desc
final recentlyAddedProvider = FutureProvider<PagedResult<MovieListItem>>((ref) async {
  final repo = ref.watch(moviesRepositoryProvider);
  return repo.list(
    const MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
    limit: 12,
    offset: 0,
    compact: true,
  );
});

/// Continue Watching — 跨影片分页查找有 watch_record 且未完成的影片。
bool isContinueWatchingMovie(MovieListItem movie) {
  final record = movie.watchRecord;
  if (record == null) return false;
  return !record.completed &&
      record.progressRatio > 0.01 &&
      record.progressRatio < 0.97;
}

final continueWatchingProvider = FutureProvider<List<MovieListItem>>((ref) async {
  final repo = ref.watch(moviesRepositoryProvider);
  const pageSize = 50;
  const resultLimit = 5;
  final result = <MovieListItem>[];
  var offset = 0;

  while (result.length < resultLimit) {
    final page = await repo.list(
      const MovieFilter(sortBy: 'created_at', sortOrder: 'desc'),
      limit: pageSize,
      offset: offset,
    );
    result.addAll(page.items.where(isContinueWatchingMovie));
    if (!page.hasMore || page.items.isEmpty) break;
    offset += page.items.length;
  }

  return result.take(resultLimit).toList();
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

/// 服务器切换并完成鉴权后，清掉旧服务器的首页请求状态并重新加载数据。
///
/// 通过回调同时兼容页面中的 [WidgetRef] 和 Notifier 中的 [Ref]，避免把
/// 页面层的刷新逻辑复制到服务器切换流程。
Future<void> refreshHomeProviders({
  required Future<Object?> Function() refreshRecentlyAdded,
  required Future<Object?> Function() refreshContinueWatching,
  required Future<Object?> Function() refreshLibraries,
  required Future<Object?> Function() refreshRecommendCarousel,
}) async {
  await Future.wait<void>([
    _waitForHomeRefresh(refreshRecentlyAdded),
    _waitForHomeRefresh(refreshContinueWatching),
    _waitForHomeRefresh(refreshLibraries),
  ]);
  await _waitForHomeRefresh(refreshRecommendCarousel);
}

Future<void> _waitForHomeRefresh(Future<Object?> Function() refresh) async {
  try {
    await refresh();
  } catch (_) {
    // Provider 会保留目标服务器本次请求的错误状态，不能回退到旧服务器错误。
  }
}
