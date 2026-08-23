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

  test('详情模型解析关联字幕文件', () {
    final movie = MovieDetail.fromJson({
      'id': 3,
      'title': '关联字幕测试',
      'has_external_subtitle': false,
      'related_files': [
        {'type': 'subtitle', 'label': '字幕文件', 'path': '/movies/test.srt'},
      ],
    });

    expect(movie.hasExternalSubtitle, isFalse);
    expect(movie.relatedFiles.single.type, 'subtitle');
    expect(movie.relatedFiles.single.path, '/movies/test.srt');
  });

  test('列表模型解析内嵌字幕轨道和视频分辨率状态', () {
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
    // 内嵌轨道与文件名标识相互独立
    expect(movie.hasMuxedSubtitle, isTrue);
    expect(movie.hasFilenameSubtitle, isFalse);
  });

  test('列表模型按文件名后缀识别内嵌字幕标识', () {
    final movie = MovieListItem.fromJson({
      'id': 4,
      'title': '文件名标识测试',
      'file_name': 'ABCD-001-uc.mp4',
    });

    expect(movie.hasInternalSubtitle, isFalse);
    expect(movie.hasMuxedSubtitle, isFalse);
    expect(movie.hasFilenameSubtitle, isTrue);
  });

  test('详情模型解析 has_internal_subtitle', () {
    final movie = MovieDetail.fromJson({
      'id': 5,
      'title': '内嵌轨道测试',
      'has_internal_subtitle': true,
    });

    expect(movie.hasInternalSubtitle, isTrue);
  });

  test('详情与列表模型解析 has_ai_subtitle', () {
    final detail = MovieDetail.fromJson({
      'id': 6,
      'title': 'AI 字幕详情',
      'has_ai_subtitle': true,
    });
    final item = MovieListItem.fromJson({
      'id': 7,
      'title': 'AI 字幕列表',
      'has_ai_subtitle': true,
    });

    expect(detail.hasAiSubtitle, isTrue);
    expect(item.hasAiSubtitle, isTrue);
    // 字段缺省时回退 false,不影响旧接口数据
    expect(
      MovieListItem.fromJson({'id': 8, 'title': '旧数据'}).hasAiSubtitle,
      isFalse,
    );
  });

  test('isAISubtitlePath 识别文件名中的 .ai. 标记段', () {
    expect(isAISubtitlePath('/movies/aaa.ai.chs.srt'), isTrue);
    expect(isAISubtitlePath('/movies/aaa.ai.srt'), isTrue);
    expect(isAISubtitlePath('/movies/aaa.ai.ass'), isTrue);
    expect(
      isAISubtitlePath(r'D:\movies\SW-621-UMR.ai.chinese.default.srt'),
      isTrue,
    );
    expect(isAISubtitlePath('/movies/SW-621-UMR.AI.chs.srt'), isTrue);
    expect(isAISubtitlePath('ai.srt'), isTrue);

    expect(isAISubtitlePath('/movies/aaa.ks.chs.srt'), isFalse);
    expect(isAISubtitlePath('/movies/aaa.ks.chs.default.ass'), isFalse);
    expect(
      isAISubtitlePath(r'D:\movies\SW-621-UMR.KS.chinese.default.ass'),
      isFalse,
    );
    expect(isAISubtitlePath('/movies/bbb.chs.srt'), isFalse);
    expect(isAISubtitlePath('/movies/abc.sai.srt'), isFalse);
    expect(isAISubtitlePath(null), isFalse);
    expect(isAISubtitlePath('  '), isFalse);
  });
}
