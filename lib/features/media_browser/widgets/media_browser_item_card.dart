import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/shared/movie_card.dart';

/// Emby/Jellyfin 条目卡片。
///
/// 渲染由共享 [CatalogMovieCard] 统一维护（与 OMM/DBO 同一套风格和尺寸），
/// 这里只把服务器字段整理成展示值：无番号行，meta 为
/// 「年份 · 时长」或「SxxEyy · 剧名」。
class MediaBrowserItemCard extends StatelessWidget {
  const MediaBrowserItemCard({
    super.key,
    required this.item,
    required this.urls,
    this.width = 112,
    this.square = false,
    this.onTap,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;

  /// 专辑/歌曲等方形封面；影视海报保持 2:3。
  final bool square;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final played = item.userData.played;
    return CatalogMovieCard(
      title: item.name,
      code: null,
      imageUrl: item.primaryImageTag == null
          ? null
          : urls.poster(item.id, tag: item.primaryImageTag),
      meta: _metaText(item),
      width: width,
      rating: item.communityRating,
      played: played,
      progress: played ? 0 : _progressOf(item),
      year: item.productionYear,
      privacyId: item.id,
      posterAspectRatio: square ? 1 : 2 / 3,
      onTap: onTap,
    );
  }
}

double _progressOf(MediaBrowserItem item) {
  final runtimeMinutes = item.runtimeMinutes;
  if (runtimeMinutes <= 0) return 0;
  return (item.userData.resumeSeconds / 60 / runtimeMinutes).clamp(0.0, 1.0);
}

/// meta 行 · 与 OMM 一致的「年份 · 时长」格式；剧集条目为「SxxEyy · 剧名」，
/// 音乐条目为「年份 · 艺术家」（专辑）或「艺术家 · 时长」（歌曲）。
String _metaText(MediaBrowserItem item) {
  final parts = <String>[];
  if (item.isEpisode) {
    final season = item.parentIndexNumber ?? 0;
    final episode = item.indexNumber ?? 0;
    parts.add(
      'S${season.toString().padLeft(2, '0')}'
      'E${episode.toString().padLeft(2, '0')}',
    );
    final series = item.seriesName?.trim();
    if (series?.isNotEmpty == true) parts.add(series!);
    return parts.join(' · ');
  }
  if (item.isMusicAlbum) {
    if (item.productionYear != null) parts.add('${item.productionYear}');
    final artist = item.displayArtist;
    if (artist != null) parts.add(artist);
    final trackCount = item.childCount;
    if (trackCount != null && trackCount > 0) parts.add('$trackCount 首');
    return parts.join(' · ');
  }
  if (item.isAudio) {
    final artist = item.displayArtist;
    if (artist != null) parts.add(artist);
    final minutes = item.runtimeMinutes;
    if (minutes > 0) parts.add('${minutes}m');
    return parts.join(' · ');
  }
  if (item.productionYear != null) parts.add('${item.productionYear}');
  final minutes = item.runtimeMinutes;
  if (minutes > 0) parts.add('${minutes}m');
  return parts.join(' · ');
}

/// 列表为空时的占位。
class MediaBrowserEmptyPlaceholder extends StatelessWidget {
  const MediaBrowserEmptyPlaceholder({super.key, this.text = '暂无内容'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(child: Text(text, style: AppText.meta(context))),
    );
  }
}
