import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/pages/media_browser_album_detail_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_movie_detail_page.dart';
import 'package:omm/features/media_browser/pages/media_browser_series_detail_page.dart';
import 'package:omm/features/media_browser/playback/media_browser_audio_playback.dart';
import 'package:omm/shared/single_flight_gate.dart';

final _mediaBrowserItemOpenGate = SingleFlightGate();

/// 打开 Emby/Jellyfin 条目详情。
///
/// 首页、媒体库和搜索都经过同一入口：剧集进入季/集结构页，音乐专辑进入
/// 曲目页，音频单曲直接播放，电影和其他可播条目进入详情页，避免各页面
/// 对条目类型分流产生差异。品牌差异（如需要）由页面内从
/// mediaBrowserConfigProvider 读取。
Future<void> openMediaBrowserItem(
  BuildContext context,
  WidgetRef ref,
  MediaBrowserItem item,
) async {
  final id = item.id.trim();
  if (id.isEmpty) return;
  if (item.isAudio) {
    await openMediaBrowserAudioItem(context, ref, item: item);
    return;
  }
  await _mediaBrowserItemOpenGate.run(() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => item.isSeries
            ? MediaBrowserSeriesDetailPage(seriesId: id)
            : item.isMusicAlbum
            ? MediaBrowserAlbumDetailPage(albumId: id)
            : MediaBrowserMovieDetailPage(itemId: id),
      ),
    );
  });
}

/// 与页面按钮保持一致的非阻塞导航调用。
void openMediaBrowserItemUnawaited(
  BuildContext context,
  WidgetRef ref,
  MediaBrowserItem item,
) {
  unawaited(openMediaBrowserItem(context, ref, item));
}
