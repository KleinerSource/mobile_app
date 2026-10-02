import 'media_browser_home_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/playback/media_browser_playback.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// Emby/Jellyfin 接下来观看区块：与继续观看同款的 16:10 宽幅横滑卡片。
///
/// 条目都是未开播的下一集，不展示进度条与剩余分钟，播放按钮直接开播。
class MediaBrowserNextUpSection extends ConsumerWidget {
  const MediaBrowserNextUpSection({super.key, required this.items});

  final List<MediaBrowserItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(mediaBrowserServerUrlsProvider).value;
    final l = AppL10n.of(context);
    return ContinueWatchingSection(
      title: l.mediaBrowserNextUp,
      entries: [
        for (final item in items)
          ContinueWatchingEntry(
            privacyId: item.id,
            title: item.name,
            meta: mediaBrowserHomeMetaText(l, item),
            coverUrl: urls?.heroImage(item),
            imageHeaders: urls?.imageHeaders,
            onOpen: () => openMediaBrowserItem(context, ref, item),
            onResume: () => openMediaBrowserPlayback(context, ref, item: item),
          ),
      ],
    );
  }
}
