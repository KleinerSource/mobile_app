import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/emby/providers/emby_providers.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/shared/poster.dart' show Poster, RatingBadge;

/// Emby 条目卡片 · 显示风格与尺寸对齐 OMM [MovieCard]：
/// 2:3 海报（评分角标右上、已看完左上、进度条贴底）+ 两行标题 +
/// 年份/时长 meta，随 OMM 的角标可见性与位置配置联动。
class EmbyItemCard extends ConsumerWidget {
  const EmbyItemCard({
    super.key,
    required this.item,
    required this.urls,
    this.width = 112,
    this.onTap,
  });

  final EmbyItem item;
  final EmbyServerUrls urls;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final positions = ref.watch(badgePositionsProvider);
    final played = item.userData.played;
    final progress = played ? 0.0 : _progressOf(item);
    final hasRating =
        positions.ratingEnabled &&
        item.communityRating != null &&
        item.communityRating! > 0;
    final coverUrl = item.primaryImageTag == null ? null : urls.poster(item.id);

    return SizedBox(
      width: width,
      child: PrivacyAwareInkWell(
        movieId: item.id,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                PrivacyMask(
                  movieId: item.id,
                  radius: 10,
                  child: Poster(
                    url: coverUrl,
                    title: item.name,
                    year: item.productionYear,
                  ),
                ),
                // 已看完 (固定左上, 与 OMM 卡片一致)
                if (played)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已看完',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                // 观看进度 (固定贴海报底部边缘)
                if (!played && progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      ),
                    ),
                  ),
                // 评分 (默认右上, 与 OMM 角标位置配置联动)
                if (hasRating)
                  Positioned(
                    top: 6 + positions.topRightOffset.vertical.toDouble(),
                    right: 6 + positions.topRightOffset.horizontal.toDouble(),
                    child: RatingBadge(rating: item.communityRating!),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 标题: 隐私模式遮罩 · 固定 2 行高度避免溢出
            PrivacyText(
              movieId: item.id,
              text: item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.movieCardTitle(context),
            ),
            if (_metaText(item).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _metaText(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.movieCardMeta(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

double _progressOf(EmbyItem item) {
  final runtimeMinutes = embyTicksToSeconds(item.runTimeTicks) / 60;
  if (runtimeMinutes <= 0) return 0;
  return (item.userData.resumeSeconds / 60 / runtimeMinutes).clamp(0.0, 1.0);
}

/// meta 行 · 与 OMM 一致的「年份 · 时长」格式；剧集条目为「S01E02 · 剧名」。
String _metaText(EmbyItem item) {
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
  if (item.productionYear != null) parts.add('${item.productionYear}');
  final minutes = embyTicksToSeconds(item.runTimeTicks) / 60;
  if (minutes > 0) parts.add('${minutes.round()}m');
  return parts.join(' · ');
}

/// 列表为空时的占位。
class EmbyEmptyPlaceholder extends StatelessWidget {
  const EmbyEmptyPlaceholder({super.key, this.text = '暂无内容'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(child: Text(text, style: AppText.meta(context))),
    );
  }
}
