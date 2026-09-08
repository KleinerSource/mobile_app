import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import 'package:omm/features/i18n/poster_badge_visibility_provider.dart';

void main() {
  test('resolution_tier 档位字符串映射到枚举', () {
    expect(resolutionTierFromApi('4k'), ResolutionTier.uhd);
    expect(resolutionTierFromApi('2k'), ResolutionTier.k2);
    expect(resolutionTierFromApi('fhd'), ResolutionTier.fhd);
    expect(resolutionTierFromApi('hd'), ResolutionTier.hd);
    expect(resolutionTierFromApi('sd'), ResolutionTier.sd);
    // 大小写与空白容错
    expect(resolutionTierFromApi(' FHD '), ResolutionTier.fhd);
  });

  test('unknown/缺失/非法档位视为 none', () {
    expect(resolutionTierFromApi('unknown'), ResolutionTier.none);
    expect(resolutionTierFromApi(null), ResolutionTier.none);
    expect(resolutionTierFromApi(''), ResolutionTier.none);
    expect(resolutionTierFromApi('1080p'), ResolutionTier.none);
  });

  test('列表项从 JSON 解析 resolution_tier', () {
    final item = MovieListItem.fromJson({
      'id': 1,
      'title': 'demo',
      'resolution_tier': '4k',
    });
    expect(item.resolutionTier, ResolutionTier.uhd);

    final missing = MovieListItem.fromJson({'id': 2, 'title': 'demo'});
    expect(missing.resolutionTier, ResolutionTier.none);
  });

  test('封面徽章直接使用统一档位', () {
    final badges = buildCoverBadges(
      filePath: 'title-720p.mp4',
      resolutionTier: ResolutionTier.uhd,
    );
    expect(
      badges
          .where((badge) => badge.kind == PosterBadgeKind.resolution)
          .single
          .label,
      '4K',
    );

    final none = buildCoverBadges(
      filePath: 'title-720p.mp4',
      resolutionTier: ResolutionTier.none,
    );
    expect(
      none.where((badge) => badge.kind == PosterBadgeKind.resolution),
      isEmpty,
    );
  });
}
