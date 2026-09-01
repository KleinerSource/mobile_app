import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/features/jellyfin/jellyfin_playback.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/jellyfin/navigation/jellyfin_navigation.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';

/// Jellyfin 接下来观看区块：与继续观看同款的 16:10 宽幅横滑卡片。
///
/// 条目都是未开播的下一集，不展示进度条与剩余分钟，播放按钮直接开播。
class JellyfinNextUpSection extends ConsumerWidget {
  const JellyfinNextUpSection({super.key, required this.items});

  final List<MediaBrowserItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(jellyfinServerUrlsProvider).value;
    return ContinueWatchingSection(
      title: '接下来观看',
      entries: [
        for (final item in items)
          ContinueWatchingEntry(
            privacyId: item.id,
            title: item.name,
            meta: _metaText(item),
            coverUrl: urls == null
                ? null
                : item.backdropImageTags.isEmpty
                ? (item.primaryImageTag == null ? null : urls.poster(item.id))
                : urls.backdrop(item.id),
            onOpen: () => openJellyfinItem(context, item),
            onResume: () => openJellyfinPlayback(context, ref, item: item),
          ),
      ],
    );
  }
}

String _metaText(MediaBrowserItem item) {
  final parts = <String>[];
  final series = item.seriesName?.trim();
  if (series?.isNotEmpty == true) parts.add(series!);
  if (item.isEpisode) {
    final season = item.parentIndexNumber ?? 0;
    final episode = item.indexNumber ?? 0;
    parts.add(
      'S${season.toString().padLeft(2, '0')}'
      'E${episode.toString().padLeft(2, '0')}',
    );
  } else if (item.productionYear != null) {
    parts.add('${item.productionYear}');
  }
  return parts.join(' · ');
}
