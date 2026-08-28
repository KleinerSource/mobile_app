import 'dart:async';

import 'package:flutter/material.dart';

import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/pages/db_online_movie_detail_page.dart';

/// 打开 dbonline 影片详情。
///
/// 推荐、最新列表和详情中的关联影片都经过同一入口，避免各页面对番号
/// 与 video_id 的回退规则产生差异。
Future<void> openDbOnlineMovie(
  BuildContext context,
  DbOnlineMovie movie,
) async {
  final code = movie.number.trim();
  final videoId = movie.id.trim();
  if (code.isEmpty && videoId.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => code.isNotEmpty
          ? DbOnlineMovieDetailPage(code: code)
          : DbOnlineMovieDetailPage.byVideoId(videoId: videoId),
    ),
  );
}

/// 与页面按钮保持一致的非阻塞导航调用。
void openDbOnlineMovieUnawaited(BuildContext context, DbOnlineMovie movie) {
  unawaited(openDbOnlineMovie(context, movie));
}
