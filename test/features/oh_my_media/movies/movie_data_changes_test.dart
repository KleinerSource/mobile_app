import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';

void main() {
  test('按影片快照不会被其他影片的变更误触发', () {
    const movieA = 901001;
    const movieB = 901002;
    final before = MovieDataChanges.snapshot(movieId: movieA);

    MovieDataChanges.bumpImages(movieId: movieB);

    expect(before.latest.changedSince(before), isFalse);
    expect(before.latest.imagesChangedSince(before), isFalse);
  });

  test('影片编辑和播放进度分别只触发对应的变更类型', () {
    const movieA = 901003;
    final before = MovieDataChanges.snapshot(movieId: movieA);

    MovieDataChanges.bumpMetadata(movieId: movieA);
    final afterMetadata = before.latest;
    expect(afterMetadata.displayChangedSince(before), isTrue);
    expect(afterMetadata.imagesChangedSince(before), isFalse);
    expect(afterMetadata.progressChangedSince(before), isFalse);

    final beforeProgress = MovieDataChanges.snapshot(movieId: movieA);
    MovieDataChanges.bumpProgress(movieId: movieA);
    final afterProgress = beforeProgress.latest;
    expect(afterProgress.displayChangedSince(beforeProgress), isFalse);
    expect(afterProgress.progressChangedSince(beforeProgress), isTrue);
  });
}
