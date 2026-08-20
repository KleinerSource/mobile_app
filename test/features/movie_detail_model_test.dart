import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';

void main() {
  test('详情模型解析 thumb_uuid', () {
    final movie = MovieDetail.fromJson({
      'id': 1,
      'title': '测试影片',
      'thumb_uuid': 'thumb-uuid',
      'has_external_subtitle': true,
    });

    expect(movie.thumbUuid, 'thumb-uuid');
    expect(movie.hasExternalSubtitle, isTrue);
  });

  test('列表模型解析内嵌字幕和视频分辨率状态', () {
    final movie = MovieListItem.fromJson({
      'id': 2,
      'title': '列表测试',
      'has_internal_subtitle': true,
      'video_width': 1920,
      'video_height': 1080,
    });

    expect(movie.hasInternalSubtitle, isTrue);
    expect(movie.videoWidth, 1920);
    expect(movie.videoHeight, 1080);
    expect(movie.hasEmbeddedSubtitle, isTrue);
  });
}
