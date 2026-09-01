import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/emby/providers/emby_providers.dart';
import 'package:omm/shared/movie_card.dart';

/// Emby 条目卡片。
///
/// 渲染由共享 [CatalogMovieCard] 统一维护（与 OMM/DBO 同一套风格和尺寸），
/// 这里只把 Emby 的字段整理成展示值：无番号行，meta 为
/// 「年份 · 时长」或「SxxEyy · 剧名」。
class EmbyItemCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final played = item.userData.played;
    return CatalogMovieCard(
      title: item.name,
      code: null,
      imageUrl: item.primaryImageTag == null ? null : urls.poster(item.id),
      meta: _metaText(item),
      width: width,
      rating: item.communityRating,
      played: played,
      progress: played ? 0 : _progressOf(item),
      year: item.productionYear,
      privacyId: item.id,
      onTap: onTap,
    );
  }
}

double _progressOf(EmbyItem item) {
  final runtimeMinutes = embyTicksToSeconds(item.runTimeTicks) / 60;
  if (runtimeMinutes <= 0) return 0;
  return (item.userData.resumeSeconds / 60 / runtimeMinutes).clamp(0.0, 1.0);
}

/// meta 行 · 与 OMM 一致的「年份 · 时长」格式；剧集条目为「SxxEyy · 剧名」。
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
