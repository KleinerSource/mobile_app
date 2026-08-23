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

  test('外挂字幕和文件名内嵌字幕可以同时显示', () {
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

  test('媒体探测到内嵌字幕流时生成内嵌字幕轨道 badge', () {
    final badges = buildCoverBadges(hasMuxedSubtitle: true);

    final subtitleBadges = badges
        .where((badge) => badge.kind == PosterBadgeKind.subtitle)
        .toList();
    expect(subtitleBadges, hasLength(1));
    expect(subtitleBadges.single.tooltip, '内嵌字幕轨道');
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
      '外挂字幕',
      '内嵌字幕轨道',
      '内嵌字幕',
    ]);
  });

  test('内嵌字幕轨道与文件名标识不互相触发', () {
    final muxOnly = buildCoverBadges(hasMuxedSubtitle: true);
    expect(
      muxOnly
          .where((badge) => badge.kind == PosterBadgeKind.subtitle)
          .map((badge) => badge.tooltip),
      ['内嵌字幕轨道'],
    );

    final filenameOnly = buildCoverBadges(filePath: '/movies/ABCD-001-C.mp4');
    expect(
      filenameOnly
          .where((badge) => badge.kind == PosterBadgeKind.subtitle)
          .map((badge) => badge.tooltip),
      ['内嵌字幕'],
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
    expect(subtitleBadges.single.label, '字幕');
    expect(subtitleBadges.single.tooltip, 'AI 字幕');
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
    expect(subtitleBadges.map((badge) => badge.tooltip), ['外挂字幕', 'AI 字幕']);
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
      '外挂字幕',
      'AI 字幕',
      '内嵌字幕轨道',
      '内嵌字幕',
    ]);
  });
}
