import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/features/i18n/poster_badge_visibility_provider.dart';
import 'package:md_center/features/movie_detail/cover_badges.dart';

void main() {
  test('外挂字幕生成字幕 badge', () {
    final badges = buildCoverBadges(hasExternalSubtitle: true);

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(1));
    expect(subtitleBadges.single.label, '字幕');
    expect(subtitleBadges.single.tooltip, '外挂字幕');
    expect(subtitleBadges.single.color.toARGB32(), 0xFFFF9F1C);
  });

  test('外挂字幕和内嵌字幕可以同时显示', () {
    final badges = buildCoverBadges(
      filePath: '/movies/example-chs.mkv',
      hasExternalSubtitle: true,
    );

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(2));
    expect(subtitleBadges.map((badge) => badge.tooltip), ['外挂字幕', '内嵌字幕']);
  });

  test('媒体探测到内嵌字幕流时生成内嵌字幕 badge', () {
    final badges = buildCoverBadges(hasEmbeddedSubtitle: true);

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(1));
    expect(subtitleBadges.single.tooltip, '内嵌字幕');
  });

  test('没有字幕时不生成字幕 badge', () {
    final badges = buildCoverBadges(filePath: '/movies/example.mkv');

    expect(
      badges.where((badge) => badge.kind == PosterBadgeKind.subtitle),
      isEmpty,
    );
  });
}
