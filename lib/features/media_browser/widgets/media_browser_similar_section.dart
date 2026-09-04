import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/server_compatibility.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/navigation/media_browser_navigation.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/shared/movie_detail_components.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// MediaBrowser 条目详情页的「更多类似」横向海报列表。
class MediaBrowserSimilarSection extends ConsumerWidget {
  const MediaBrowserSimilarSection({super.key, required this.items});

  final List<MediaBrowserItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(mediaBrowserServerUrlsProvider).value;
    if (urls == null || items.isEmpty) return const SizedBox.shrink();
    final isStash =
        ref.watch(mediaBrowserConfigProvider)?.project == ServerProject.stash;
    return MovieDetailFullBleedSection(
      header: Text(
        AppL10n.of(context).mediaBrowserSimilar,
        style: AppText.sectionTitle(context),
      ),
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return isStash
                ? StashScenePortraitCard(
                    item: item,
                    urls: urls,
                    width: 112,
                    onTap: () => openMediaBrowserItem(context, ref, item),
                  )
                : MediaBrowserItemCard(
                    item: item,
                    urls: urls,
                    width: 112,
                    onTap: () => openMediaBrowserItem(context, ref, item),
                  );
          },
        ),
      ),
    );
  }
}
