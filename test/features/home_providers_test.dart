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
}
