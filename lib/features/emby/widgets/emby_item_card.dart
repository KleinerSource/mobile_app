import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/emby/providers/emby_providers.dart';
import 'package:omm/shared/movie_card.dart';

/// Emby 条目卡片。
///
/// 卡片由共享 [CatalogMovieCard] 渲染，这里负责把 Emby 的类型/季集号/
/// 图片地址适配成目录卡片字段（与 DbOnlineMovieCard 同构）。
class EmbyItemCard extends StatelessWidget {
  const EmbyItemCard({
    super.key,
    required this.item,
    required this.urls,
    this.width = 112,
    this.onTap,
    this.codeOnly = false,
  });

  final EmbyItem item;
  final EmbyServerUrls urls;
  final double width;
  final VoidCallback? onTap;
  final bool codeOnly;

  @override
  Widget build(BuildContext context) {
    return CatalogMovieCard(
      title: item.name,
      code: _codeText(item),
      imageUrl: item.primaryImageTag == null ? null : urls.poster(item.id),
      meta: _metaText(item),
      width: width,
      rating: item.communityRating,
      canPlay: item.isPlayable,
      privacyId: item.id,
      onTap: onTap,
      showTitle: !codeOnly,
      showMeta: !codeOnly,
    );
  }
}

/// 副标题：季集号 / 电影无番号，用条目类型代替。
String _codeText(EmbyItem item) {
  if (item.isEpisode) {
    final season = item.parentIndexNumber ?? 0;
    final episode = item.indexNumber ?? 0;
    return 'S${season.toString().padLeft(2, '0')}'
        'E${episode.toString().padLeft(2, '0')}';
  }
  if (item.isSeries) return '剧集';
  if (item.isSeason) {
    final season = item.indexNumber;
    return season == null ? '季' : '第 $season 季';
  }
  return item.productionYear?.toString() ?? '电影';
}

String _metaText(EmbyItem item) {
  final parts = <String>[];
  final series = item.seriesName?.trim();
  if (series?.isNotEmpty == true) parts.add(series!);
  final year = item.productionYear;
  if (!item.isEpisode && year != null) parts.add('$year');
  final minutes = item.runtimeMinutes;
  if (item.isPlayable && minutes > 0) parts.add('${minutes}m');
  if (parts.isEmpty) return '暂无信息';
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
