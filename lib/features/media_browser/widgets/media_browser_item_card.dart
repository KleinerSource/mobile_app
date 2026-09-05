import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/media_metadata_normalizer.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_list_row.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/shared/poster.dart';

/// Emby/Jellyfin/FNOS 条目卡片。
///
/// 渲染由共享 [CatalogMovieCard] 统一维护（与 OMM/DBO 同一套风格和尺寸），
/// 这里只把服务器字段整理成展示值：这些来源没有番号，因此始终不传番号行，meta 为
/// 「年份 · 时长」或剧集「起止年份 · 集数」。
///
/// 交互与 DBO 卡片（DbOnlineMovieCard）一致：点击由外层 GestureDetector
/// 承接，内部 InkWell 不接回调 —— 按住不出现水波纹/按压高亮；拖选页面的
/// 长按手势由 DragSelectionTarget 接管并触发选择震动（同 OMM 影片库）。
class MediaBrowserItemCard extends StatelessWidget {
  const MediaBrowserItemCard({
    super.key,
    required this.item,
    required this.urls,
    this.width = 112,
    this.square = false,
    this.showFavoriteBadge = false,
    this.onTap,
    this.onLongPress,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;

  /// 专辑/歌曲等方形封面；影视海报保持 2:3。
  final bool square;

  /// 已收藏时在海报左上角叠心形角标（评分角标默认在右上，不冲突）。
  /// 收藏夹页内条目全部已收藏，不启用。
  final bool showFavoriteBadge;
  final VoidCallback? onTap;

  /// 无拖选的页面（如首页横排）传非空回调，避免长按松手误触打开；
  /// 拖选页面的长按手势由 DragSelectionTarget 接管，保持 null。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final played = item.userData.played;
    // 与 DBO 卡片（DbOnlineMovieCard）同款：CatalogMovieCard 只作展示层，
    // 不给内部 InkWell 传 onTap —— 按住时不会出现水波纹/按压高亮，
    // 点击交给外层 GestureDetector（无任何 Material 墨水特效）。
    // 拖选页面的长按由 DragSelectionTarget 接管并触发选择震动。
    final card = Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: CatalogMovieCard(
            title: item.name,
            code: null,
            imageUrl: item.primaryImageTag == null
                ? null
                : urls.poster(item.id, tag: item.primaryImageTag),
            imageHeaders: urls.imageHeaders,
            meta: mediaBrowserItemMetaText(context, item),
            width: width,
            rating: normalizeMediaRating(item.communityRating),
            played: played,
            progress: played ? 0 : _progressOf(item),
            year: normalizeMediaYear(item.productionYear),
            privacyId: item.id,
            posterAspectRatio: square ? 1 : 2 / 3,
          ),
        ),
        if (showFavoriteBadge && item.userData.isFavorite)
          const Positioned(top: 6, left: 6, child: _FavoriteBadge()),
      ],
    );
    return card;
  }
}

/// MediaBrowser 横屏卡片：复用目录卡片的共享字段和 Stash 的 16:9 信息区。
class MediaBrowserLandscapeCard extends StatelessWidget {
  const MediaBrowserLandscapeCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    this.showFavoriteBadge = false,
    this.onTap,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final bool showFavoriteBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CatalogMovieCard(
        title: item.name,
        code: null,
        imageUrl: item.primaryImageTag == null
            ? urls.heroImage(item)
            : urls.poster(item.id, tag: item.primaryImageTag),
        imageHeaders: urls.imageHeaders,
        meta: mediaBrowserItemMetaText(context, item),
        width: width,
        rating: normalizeMediaRating(item.communityRating),
        played: item.userData.played,
        progress: item.userData.played ? 0 : _progressOf(item),
        year: normalizeMediaYear(item.productionYear),
        privacyId: item.id,
        landscape: true,
      ),
    );
    return Stack(
      children: [
        card,
        if (showFavoriteBadge && item.userData.isFavorite)
          const Positioned(top: 12, left: 12, child: _FavoriteBadge()),
      ],
    );
  }
}

/// MediaBrowser 紧凑列表行；库页和搜索页使用，收藏页保留自己的左滑行。
class MediaBrowserListRow extends StatelessWidget {
  const MediaBrowserListRow({
    super.key,
    required this.item,
    required this.urls,
    required this.onTap,
    this.selected = false,
    this.selecting = false,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final VoidCallback onTap;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return MediaListRow(
      thumbnail: PrivacyMask(
        movieId: item.id,
        radius: 8,
        child: Poster(
          url: item.primaryImageTag == null
              ? urls.heroImage(item)
              : urls.poster(item.id, tag: item.primaryImageTag),
          title: item.name,
          year: item.productionYear,
          radius: 8,
          httpHeaders: urls.imageHeaders,
        ),
      ),
      leading: selecting
          ? Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colors.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? colors.accent : colors.muted2,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            )
          : null,
      title: PrivacyText(
        movieId: item.id,
        text: item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.text,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.2,
        ),
      ),
      meta: Text(
        mediaBrowserItemMetaText(context, item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.meta(context),
      ),
      onTap: onTap,
      privacyId: item.id,
      privacyAwareTap: !selecting,
    );
  }
}

/// 已收藏心形角标 · 黑玻璃圆底白心，与评分角标同一气质。
class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
      ),
      child: const Icon(Icons.favorite_rounded, size: 11, color: Colors.white),
    );
  }
}

double _progressOf(MediaBrowserItem item) {
  final runtimeMinutes = item.runtimeMinutes;
  if (runtimeMinutes <= 0) return 0;
  return (item.userData.resumeSeconds / 60 / runtimeMinutes).clamp(0.0, 1.0);
}

/// meta 行 · 与 OMM 一致的「年份 · 时长」格式；剧集条目为
/// 「起止年份 · 集数」；分集为「SxxEyy · 剧名」，音乐条目为
/// 「年份 · 艺术家」（专辑）或「艺术家 · 时长」（歌曲）。
/// 收藏夹页的列表行也复用这行 meta。
String mediaBrowserItemMetaText(BuildContext context, MediaBrowserItem item) {
  final l = AppL10n.of(context);
  final parts = <String>[];
  if (item.isSeries) {
    final yearText = _seriesYearText(l, item);
    if (yearText != null) parts.add(yearText);
    final episodeCount = item.totalEpisodeCount;
    if (episodeCount != null) {
      parts.add(l.mediaBrowserEpisodeCount(episodeCount));
    }
    return parts.join(' · ');
  }
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
    if (trackCount != null && trackCount > 0) {
      parts.add(l.mediaBrowserTrackCount(trackCount));
    }
    return parts.join(' · ');
  }
  if (item.isAudio) {
    final artist = item.displayArtist;
    if (artist != null) parts.add(artist);
    final minutes = item.runtimeMinutes;
    if (minutes > 0) parts.add(l.mediaDurationMinutes(minutes));
    return parts.join(' · ');
  }
  return formatMediaCardMeta(
    l,
    year: item.productionYear,
    duration: item.runtimeMinutes,
  );
}

String? _seriesYearText(AppL10n l, MediaBrowserItem item) {
  final startYear = item.productionYear;
  final endYear = item.endYear;

  switch (item.status?.trim().toLowerCase()) {
    case 'ended':
      if (startYear == null) return endYear?.toString();
      if (endYear == null) return startYear.toString();
      if (endYear == startYear) return '$startYear';
      return '$startYear - $endYear';
    case 'continuing':
      if (startYear == null) return l.mediaBrowserNow;
      return '$startYear - ${l.mediaBrowserNow}';
  }

  if (startYear == null) return endYear?.toString();
  if (endYear == null) return '$startYear - ${l.mediaBrowserNow}';
  if (endYear == startYear) return '$startYear';
  return '$startYear - $endYear';
}

/// 列表为空时的占位。
class MediaBrowserEmptyPlaceholder extends StatelessWidget {
  const MediaBrowserEmptyPlaceholder({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          text ?? AppL10n.of(context).mediaBrowserEmptyDefault,
          style: AppText.meta(context),
        ),
      ),
    );
  }
}
