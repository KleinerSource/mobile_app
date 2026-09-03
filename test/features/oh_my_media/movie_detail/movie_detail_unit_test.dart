// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/oh_my_media/movie_detail/cover_badges_test.dart
//   - test/features/oh_my_media/movie_detail/dbo_metadata_diff_test.dart
//   - test/features/oh_my_media/movie_detail/movie_detail_formatters_test.dart
//   - test/features/oh_my_media/movie_detail/movie_quick_flag_test.dart
//   - test/features/oh_my_media/movie_detail/resources_sheet_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/actor.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/features/i18n/poster_badge_visibility_provider.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import 'package:omm/features/oh_my_media/movie_detail/dbo_metadata_diff.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_formatters.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_quick_flag.dart';
import 'package:omm/features/oh_my_media/movie_detail/resources_sheet.dart';

// ==================== 原 test/features/oh_my_media/movie_detail/cover_badges_test.dart ====================
void _main_0() {
  test('外挂字幕生成字幕 badge', () {
    final badges = buildCoverBadges(hasExternalSubtitle: true);

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(1));
    expect(subtitleBadges.single.label, 'subtitle');
    expect(subtitleBadges.single.tooltip, 'externalSubtitle');
    expect(subtitleBadges.single.color.toARGB32(), 0xFFFF9F1C);
  });

  test('外挂字幕和文件名内嵌字幕可以同时显示', () {
    final badges = buildCoverBadges(
      filePath: '/movies/example-chs.mkv',
      hasExternalSubtitle: true,
    );

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(2));
    expect(subtitleBadges.map((badge) => badge.tooltip), [
      'externalSubtitle',
      'embeddedSubtitle',
    ]);
  });

  test('媒体探测到内嵌字幕流时生成内嵌字幕轨道 badge', () {
    final badges = buildCoverBadges(hasMuxedSubtitle: true);

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(1));
    expect(subtitleBadges.single.tooltip, 'muxedSubtitle');
    expect(subtitleBadges.single.color.toARGB32(), 0xFF16A34A);
  });

  test('三种字幕来源相互独立可同时显示', () {
    final badges = buildCoverBadges(
      filePath: '/movies/ABCD-001-C.mp4',
      hasExternalSubtitle: true,
      hasMuxedSubtitle: true,
    );

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(3));
    expect(subtitleBadges.map((badge) => badge.tooltip), [
      'externalSubtitle',
      'muxedSubtitle',
      'embeddedSubtitle',
    ]);
  });

  test('内嵌字幕轨道与文件名标识不互相触发', () {
    final muxOnly = buildCoverBadges(hasMuxedSubtitle: true);
    expect(
      muxOnly
          .where((badge) => badge.kind == PosterBadgeKind.subtitle)
          .map((badge) => badge.tooltip),
      ['muxedSubtitle'],
    );

    final filenameOnly = buildCoverBadges(filePath: '/movies/ABCD-001-C.mp4');
    expect(
      filenameOnly
          .where((badge) => badge.kind == PosterBadgeKind.subtitle)
          .map((badge) => badge.tooltip),
      ['embeddedSubtitle'],
    );
  });

  test('没有字幕时不生成字幕 badge', () {
    final badges = buildCoverBadges(filePath: '/movies/example.mkv');

    expect(
      badges.where((badge) => badge.kind == PosterBadgeKind.subtitle),
      isEmpty,
    );
  });

  test('AI 字幕生成独立配色 badge', () {
    final badges = buildCoverBadges(hasAISubtitle: true);

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(1));
    expect(subtitleBadges.single.label, 'subtitle');
    expect(subtitleBadges.single.tooltip, 'aiSubtitle');
    expect(subtitleBadges.single.color.toARGB32(), 0xFF8B5CF6);
  });

  test('外挂字幕与 AI 字幕同时存在时都显示', () {
    final badges = buildCoverBadges(
      hasExternalSubtitle: true,
      hasAISubtitle: true,
    );

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(2));
    expect(subtitleBadges.map((badge) => badge.tooltip), [
      'externalSubtitle',
      'aiSubtitle',
    ]);
  });

  test('四种字幕来源相互独立可同时显示', () {
    final badges = buildCoverBadges(
      filePath: '/movies/ABCD-001-C.mp4',
      hasExternalSubtitle: true,
      hasAISubtitle: true,
      hasMuxedSubtitle: true,
    );

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(4));
    expect(subtitleBadges.map((badge) => badge.tooltip), [
      'externalSubtitle',
      'aiSubtitle',
      'muxedSubtitle',
      'embeddedSubtitle',
    ]);
  });
}

// ==================== 原 test/features/oh_my_media/movie_detail/dbo_metadata_diff_test.dart ====================
void _main_1() {
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

// ==================== 原 test/features/oh_my_media/movie_detail/movie_detail_formatters_test.dart ====================
void _main_2() {
  test('续播位置始终使用 HH:MM:SS 格式', () {
    expect(formatResumePosition(0), '00:00:00');
    expect(formatResumePosition(65), '00:01:05');
    expect(formatResumePosition(1 * 3600 + 23 * 60 + 22), '01:23:22');
  });

  test('负数续播位置按零处理', () {
    expect(formatResumePosition(-1), '00:00:00');
  });

  test('简介换行统一支持 HTML 和平台换行符', () {
    expect(
      normalizeMoviePlot('第一行\r\n第二行\r第三行\n第四行<br>第五行<br/>第六行<br />第七行'),
      '第一行\n第二行\n第三行\n第四行\n第五行\n第六行\n第七行',
    );
    expect(normalizeMoviePlot('上&lt;br&gt;下'), '上\n下');
    expect(normalizeMoviePlot('上\u2028下\u2029末'), '上\n下\n末');
  });
}

// ==================== 原 test/features/oh_my_media/movie_detail/movie_quick_flag_test.dart ====================
void _main_3() {
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

// ==================== 原 test/features/oh_my_media/movie_detail/resources_sheet_test.dart ====================
void _main_4() {
  test('ED2K 下载器优先使用服务端能力字段', () {
    expect(supportsEd2kDownloader('custom', true), isTrue);
    expect(supportsEd2kDownloader('thunder', false), isFalse);
  });

  test('ED2K 下载器兼容默认名称和 OpenList 实例名称', () {
    expect(supportsEd2kDownloader(' thunder ', null), isTrue);
    expect(supportsEd2kDownloader('openlist:家庭盘', null), isTrue);
    expect(supportsEd2kDownloader('qbittorrent', null), isFalse);
  });

  test('parseResourceDate 兼容多种日期格式', () {
    expect(parseResourceDate({'date': '2024-01-02'}), DateTime(2024, 1, 2));
    expect(parseResourceDate({'date': '2024/01/02'}), DateTime(2024, 1, 2));
    expect(
      parseResourceDate({'publish_date': '2024-01-02 15:30:00'}),
      DateTime(2024, 1, 2, 15, 30),
    );
    expect(parseResourceDate({'date': 1719792000})!.toUtc().year, 2024);
    expect(parseResourceDate({'date': '1719792000'}), isNotNull);
    // 秒级与毫秒级 epoch 应解析到同一时刻。
    expect(
      parseResourceDate({'date': 1719792000}),
      parseResourceDate({'date': 1719792000000}),
    );
    expect(parseResourceDate({'date': 'not-a-date'}), isNull);
    expect(parseResourceDate({}), isNull);
  });

  test('资源列表按日期降序排序且无日期项排最后', () {
    final items = [
      {'title': 'old', 'date': '2023-01-01'},
      {'title': 'no-date'},
      {'title': 'newest', 'date': '2025-06-15'},
      {'title': 'mid', 'publish_date': '2024-03-10'},
    ];
    final sorted = sortResourcesByDateDesc(items);
    expect(sorted.map((e) => e['title']).toList(), [
      'newest',
      'mid',
      'old',
      'no-date',
    ]);
  });

  test('无日期与相同日期的项保持原有相对顺序', () {
    final items = [
      {'title': 'a-no-date'},
      {'title': 'b-same', 'date': '2024-01-01'},
      {'title': 'b-no-date'},
      {'title': 'a-same', 'date': '2024-01-01'},
    ];
    final sorted = sortResourcesByDateDesc(items);
    expect(sorted.map((e) => e['title']).toList(), [
      'b-same',
      'a-same',
      'a-no-date',
      'b-no-date',
    ]);
  });

  test('渠道合并结果与返回先后和 map 插入顺序无关', () {
    final detail = [
      {'title': 'detail-tie', 'date': '2024-01-01'},
      {'title': 'detail-undated'},
    ];
    final nyaa = [
      {'title': 'nyaa-tie', 'date': '2024-01-01'},
      {'title': 'nyaa-new', 'date': '2025-01-01'},
    ];
    // detail 先返回、custom 已返回为空。
    final orderA = {
      'detail': detail,
      'custom': <Map<String, dynamic>>[],
      'nyaa': nyaa,
    };
    // nyaa 先返回、custom 尚未返回(map 插入顺序也不同)。
    final orderB = {'nyaa': nyaa, 'detail': detail};

    final resultA = mergeResourcesBySource(orderA);
    final resultB = mergeResourcesBySource(orderB);
    expect(resultB, equals(resultA));
    expect(resultA.map((e) => e['title']).toList(), [
      'nyaa-new',
      'detail-tie',
      'nyaa-tie',
      'detail-undated',
    ]);
  });
}

void main() {
  group('cover_badges', _main_0);
  group('dbo_metadata_diff', _main_1);
  group('movie_detail_formatters', _main_2);
  group('movie_quick_flag', _main_3);
  group('resources_sheet', _main_4);
}
