import 'media_browser_home_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/playback/media_browser_playback.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// Emby/Jellyfin 继续观看区块：把 Resume 条目映射到共享的 OMM 风格
/// 宽幅卡片。
class MediaBrowserContinueWatchingSection extends ConsumerWidget {
  const MediaBrowserContinueWatchingSection({super.key, required this.items});

  final List<MediaBrowserItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(mediaBrowserServerUrlsProvider).value;
    final l = AppL10n.of(context);
    return ContinueWatchingSection(
      entries: [
        for (final item in items)
          ContinueWatchingEntry(
            privacyId: item.id,
            title: _displayTitle(item),
            meta: mediaBrowserHomeMetaText(l, item),
            coverUrl: urls?.heroImage(item),
            imageHeaders: urls?.imageHeaders,
            progress: _progressOf(item),
            minutesLeft: _minutesLeft(item),
            onOpen: () => openMediaBrowserItem(context, ref, item),
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

String _displayTitle(MediaBrowserItem item) {
  return item.name.trim();
}
