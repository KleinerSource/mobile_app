import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/features/jellyfin/jellyfin_playback.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/jellyfin/navigation/jellyfin_navigation.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';

/// Jellyfin 继续观看区块：把 Resume 条目映射到共享的 OMM 风格宽幅卡片。
class JellyfinContinueWatchingSection extends ConsumerWidget {
  const JellyfinContinueWatchingSection({super.key, required this.items});

  final List<MediaBrowserItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(jellyfinServerUrlsProvider).value;
    return ContinueWatchingSection(
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
            progress: _progressOf(item),
            minutesLeft: _minutesLeft(item),
            onOpen: () => openJellyfinItem(context, item),
            onResume: () => openJellyfinPlayback(context, ref, item: item),
          ),
      ],
    );
  }
}

double _progressOf(MediaBrowserItem item) {
  final runtimeMinutes = mediaBrowserTicksToSeconds(item.runTimeTicks) / 60;
  if (runtimeMinutes <= 0) return 0;
  return (item.userData.resumeSeconds / 60 / runtimeMinutes).clamp(0.0, 1.0);
}

int? _minutesLeft(MediaBrowserItem item) {
  final runtimeMinutes = mediaBrowserTicksToSeconds(item.runTimeTicks) / 60;
  if (runtimeMinutes <= 0) return null;
  return (runtimeMinutes * (1 - _progressOf(item))).round();
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
  final minutes = mediaBrowserTicksToSeconds(item.runTimeTicks) / 60;
  if (minutes > 0) parts.add('${minutes.round()}m');
  return parts.join(' · ');
}
