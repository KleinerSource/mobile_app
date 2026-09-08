import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import 'package:omm/features/i18n/poster_badge_visibility_provider.dart';

void main() {
  test('数据库宽高优先于扫描入库的文件名解析结果', () {
    expect(
      resolutionTierFor(
        width: 1920,
        height: 1080,
        fileResolution: '4k',
      ),
      ResolutionTier.fhd,
    );
  });

  test('缺少数据库宽高时使用扫描入库的分辨率结果', () {
    expect(
      resolutionTierFor(fileResolution: '4k'),
      ResolutionTier.uhd,
    );
    expect(
      resolutionTierFor(fileResolution: 'fhd'),
      ResolutionTier.fhd,
    );
    expect(resolutionTierFor(fileResolution: 'hd'), ResolutionTier.hd);
  });

  test('扫描期已完成 prob4 大小兜底后只读取数据库结果', () {
    expect(
      resolutionTierFor(
        fileResolution: '4k',
      ),
      ResolutionTier.uhd,
    );
    expect(
      resolutionTierFor(
        fileResolution: 'unknown',
      ),
      ResolutionTier.none,
    );
  });

  test('详情媒体信息优先使用数据库顶层宽高，即使没有嵌套视频流', () {
    final mediaInfo = MediaInfoDetail.fromJson({
      'video_width': 3840,
      'video_height': 2160,
      'streams': <dynamic>[],
    });
    final badges = buildCoverBadges(
      filePath: 'title-720p.mp4',
      videoWidth: mediaInfo.videoWidth,
      videoHeight: mediaInfo.videoHeight,
      fileResolution: 'hd',
      video: mediaInfo.streams.video,
    );

    expect(
      badges
          .where((badge) => badge.kind == PosterBadgeKind.resolution)
          .single
          .label,
      '4K',
    );
  });
}
