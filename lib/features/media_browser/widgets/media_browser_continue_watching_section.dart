import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/playback/media_browser_playback.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';

/// Emby/Jellyfin 继续观看区块：把 Resume 条目映射到共享的 OMM 风格
/// 宽幅卡片。
class MediaBrowserContinueWatchingSection extends ConsumerWidget {
  const MediaBrowserContinueWatchingSection({super.key, required this.items});

  final List<MediaBrowserItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(mediaBrowserServerUrlsProvider).value;
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
            onOpen: () => openMediaBrowserItem(context, item),
            onResume: () => openMediaBrowserPlayback(context, ref, item: item),
          ),
      ],
    );
  }
}

double _progressOf(MediaBrowserItem item) {
  final runtimeMinutes = item.runtimeMinutes;
  if (runtimeMinutes <= 0) return 0;
  return (item.userData.resumeSeconds / 60 / runtimeMinutes).clamp(0.0, 1.0);
}

int? _minutesLeft(MediaBrowserItem item) {
  final runtimeMinutes = item.runtimeMinutes;
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
  final minutes = item.runtimeMinutes;
  if (minutes > 0) parts.add('${minutes}m');
  return parts.join(' · ');
}
