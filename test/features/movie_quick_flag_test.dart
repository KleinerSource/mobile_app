import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/movie_detail/movie_quick_flag.dart';

void main() {
  test('快捷操作配置与网页端标准名和别名一致', () {
    final subtitle = movieQuickFlagConfig(MovieQuickFlag.subtitle);
    final exsub = movieQuickFlagConfig(MovieQuickFlag.exsub);
    expect(subtitle.canonicalName, '中文字幕');
    expect(subtitle.keywords, ['中文字幕', '中字']);
    expect(exsub.canonicalName, subtitle.canonicalName);
    expect(exsub.keywords, subtitle.keywords);
    expect(movieQuickFlagConfig(MovieQuickFlag.crack).canonicalName, '无码破解');
    expect(movieQuickFlagConfig(MovieQuickFlag.crack).keywords, ['无码破解', '破解']);
    final uhd = movieQuickFlagConfig(MovieQuickFlag.uhd);
    expect(uhd.canonicalName, 'UHD');
    expect(uhd.keywords, ['UHD']);
  });

  test('开启快捷操作同时追加对应标签和分类并保留现有选择', () {
    final first = addMovieQuickFlagSelections(
      tags: const [(id: 1, name: '已有标签')],
      genres: const [(id: 10, name: '已有分类')],
      tag: const (id: 2, name: '中文字幕'),
      genre: const (id: 20, name: '中文字幕'),
    );
    final repeated = addMovieQuickFlagSelections(
      tags: first.tags,
      genres: first.genres,
      tag: const (id: 2, name: '中文字幕'),
      genre: const (id: 20, name: '中文字幕'),
    );

    expect(repeated.tags, const [(id: 1, name: '已有标签'), (id: 2, name: '中文字幕')]);
    expect(repeated.genres, const [
      (id: 10, name: '已有分类'),
      (id: 20, name: '中文字幕'),
    ]);
  });

  test('关闭快捷操作同时移除标准名和别名且保留无关选择', () {
    final result = removeMovieQuickFlagSelections(
      flag: MovieQuickFlag.subtitle,
      tags: const [(id: 1, name: '中字'), (id: 2, name: '其他标签')],
      genres: const [(id: 10, name: '中文字幕'), (id: 11, name: '剧情')],
    );

    expect(result.tags, const [(id: 2, name: '其他标签')]);
    expect(result.genres, const [(id: 11, name: '剧情')]);
  });

  test('快捷状态从分类或标签任一命中计算且忽略大小写', () {
    expect(
      hasMovieQuickFlag(
        flag: MovieQuickFlag.uhd,
        tags: const [(id: 1, name: 'uhd')],
        genres: const [],
      ),
      isTrue,
    );
    expect(
      hasMovieQuickFlag(
        flag: MovieQuickFlag.crack,
        tags: const [],
        genres: const [(id: 10, name: '破解')],
      ),
      isTrue,
    );
  });
}
