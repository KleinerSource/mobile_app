import 'dart:async';

import 'package:flutter/material.dart';

import 'package:omm/features/jellyfin/models/jellyfin_models.dart';
import 'package:omm/features/jellyfin/pages/jellyfin_movie_detail_page.dart';
import 'package:omm/features/jellyfin/pages/jellyfin_series_detail_page.dart';

/// 打开 Jellyfin 条目详情。
///
/// 首页、媒体库和搜索都经过同一入口：剧集进入季/集结构页，电影和
/// 其他可播条目进入详情页，避免各页面对条目类型分流产生差异。
Future<void> openJellyfinItem(BuildContext context, JellyfinItem item) async {
  final id = item.id.trim();
  if (id.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => item.isSeries
          ? JellyfinSeriesDetailPage(seriesId: id)
          : JellyfinMovieDetailPage(itemId: id),
    ),
  );
}

/// 与页面按钮保持一致的非阻塞导航调用。
void openJellyfinItemUnawaited(BuildContext context, JellyfinItem item) {
  unawaited(openJellyfinItem(context, item));
}
