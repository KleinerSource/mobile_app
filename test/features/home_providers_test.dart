import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/features/home/home_providers.dart';

void main() {
  test('continue watching 过滤未完成且有有效进度的影片', () {
    expect(
      isContinueWatchingMovie(
        const MovieListItem(
          id: 1,
          watchRecord: WatchRecordSummary(progressRatio: 0.4),
        ),
      ),
      isTrue,
    );
    expect(
      isContinueWatchingMovie(
        const MovieListItem(
          id: 2,
          watchRecord: WatchRecordSummary(progressRatio: 0.4, completed: true),
        ),
      ),
      isFalse,
    );
    expect(
      isContinueWatchingMovie(
        const MovieListItem(
          id: 3,
          watchRecord: WatchRecordSummary(progressRatio: 0.01),
        ),
      ),
      isFalse,
    );
  });

  test('首页刷新不会因单个区块失败而跳过其它区块', () async {
    final refreshed = <String>[];

    await refreshHomeProviders(
      refreshRecentlyAdded: () async {
        refreshed.add('recent');
        throw StateError('recent failed');
      },
      refreshContinueWatching: () async {
        refreshed.add('continue');
      },
      refreshLibraries: () async {
        refreshed.add('libraries');
      },
      refreshRecommendCarousel: () async {
        refreshed.add('carousel');
      },
    );

    expect(refreshed, containsAll(<String>[
      'recent',
      'continue',
      'libraries',
      'carousel',
    ]));
  });
}
