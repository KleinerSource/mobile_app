import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_selectable_item_card.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/paged_selection.dart';

/// MediaBrowser 条目的拖选控制器（选择键 = 条目 id）。
PagedSelectionController<MediaBrowserItem> createMediaBrowserItemSelection() {
  return PagedSelectionController<MediaBrowserItem>(idOf: (item) => item.id);
}

/// 网格条目的拖选装配：可选中卡片 + 选择模式点按切换勾选 / 普通模式打开。
///
/// 列表行等自定义卡片用 [PagedSelectionItem] + 自己的 cardBuilder。
Widget mediaBrowserSelectableGridItem({
  required PagedSelectionController<MediaBrowserItem> selection,
  required MediaBrowserItem item,
  required MediaBrowserServerUrls urls,
  required double width,
  required int index,
  bool square = false,
  bool showFavoriteBadge = false,
  bool selectionEnabled = true,
  required Future<void> Function(MediaBrowserItem item) onOpen,
}) {
  if (!selectionEnabled) {
    return MediaBrowserSelectableItemCard(
      item: item,
      urls: urls,
      width: width,
      square: square,
      showFavoriteBadge: showFavoriteBadge,
      selected: false,
      selecting: false,
      onTap: () => unawaited(onOpen(item)),
    );
  }
  return PagedSelectionItem<MediaBrowserItem>(
    selection: selection,
    item: item,
    selectionIndex: index,
    cardBuilder: (context, item, selected) => MediaBrowserSelectableItemCard(
      item: item,
      urls: urls,
      width: width,
      square: square,
      showFavoriteBadge: showFavoriteBadge,
      selected: selected,
      selecting: selection.isActive,
      onTap: () {
        if (selection.isActive) {
          selection.toggle(selection.idOf(item));
        } else {
          unawaited(onOpen(item));
        }
      },
    ),
  );
}

/// 横屏条目的拖选装配：使用 Stash 风格的 16:9 卡片，但不启用 Stash 预览。
Widget mediaBrowserSelectableLandscapeItem({
  required PagedSelectionController<MediaBrowserItem> selection,
  required MediaBrowserItem item,
  required MediaBrowserServerUrls urls,
  required double width,
  int? index,
  bool showFavoriteBadge = false,
  bool selectionEnabled = true,
  required Future<void> Function(MediaBrowserItem item) onOpen,
}) {
  if (!selectionEnabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MediaBrowserSelectableItemCard(
        item: item,
        urls: urls,
        width: width,
        landscape: true,
        showFavoriteBadge: showFavoriteBadge,
        selected: false,
        selecting: false,
        onTap: () => unawaited(onOpen(item)),
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: PagedSelectionItem<MediaBrowserItem>(
      selection: selection,
      item: item,
      selectionIndex: index,
      cardBuilder: (context, item, selected) => MediaBrowserSelectableItemCard(
        item: item,
        urls: urls,
        width: width,
        landscape: true,
        showFavoriteBadge: showFavoriteBadge,
        selected: selected,
        selecting: selection.isActive,
        onTap: () {
          if (selection.isActive) {
            selection.toggle(selection.idOf(item));
          } else {
            unawaited(onOpen(item));
          }
        },
      ),
    ),
  );
}

/// 列表条目的拖选装配；列表以纵向左缘为选择热区。
Widget mediaBrowserSelectableListItem({
  required PagedSelectionController<MediaBrowserItem> selection,
  required MediaBrowserItem item,
  required MediaBrowserServerUrls urls,
  required Future<void> Function(MediaBrowserItem item) onOpen,
}) {
  return PagedSelectionItem<MediaBrowserItem>(
    selection: selection,
    item: item,
    selectionHandleAlignment: Alignment.centerLeft,
    cardBuilder: (context, item, selected) => MediaBrowserListRow(
      item: item,
      urls: urls,
      selected: selected,
      selecting: selection.isActive,
      onTap: () {
        if (selection.isActive) {
          selection.toggle(selection.idOf(item));
        } else {
          unawaited(onOpen(item));
        }
      },
    ),
  );
}

/// 库/搜索页共用的批量收藏/已看执行器。
///
/// 非破坏性操作直接执行（无确认对话框，与 OMM 影片库批量行为一致）：
/// 逐条调用并统计失败，标记已看后同步失效首页「继续观看/接下来观看」，
/// 完成后交页面原位刷新已加载条目并退出选择模式。
Future<void> runMediaBrowserSelectionBatch({
  required BuildContext context,
  required WidgetRef ref,
  required PagedSelectionController<MediaBrowserItem> selection,
  required Future<void> Function() refreshLoaded,
  required void Function(bool busy) onBusyChanged,
  required bool? favorite,
  required bool? played,
}) async {
  final ids = selection.selectedIds.whereType<String>().toList();
  if (ids.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final l = AppL10n.of(context);
  onBusyChanged(true);
  var failed = 0;
  try {
    final repo = ref.read(mediaBrowserMediaRepositoryProvider);
    for (final id in ids) {
      try {
        if (favorite != null) {
          await repo.markFavorite(id, favorite);
        } else {
          await repo.markPlayed(id, played!);
        }
      } catch (_) {
        failed++;
      }
    }
  } finally {
    onBusyChanged(false);
  }
  if (played != null) {
    // 已看状态影响首页「继续观看/接下来观看」区块。
    ref.invalidate(mediaBrowserResumeProvider);
    ref.invalidate(mediaBrowserNextUpProvider);
  }
  await refreshLoaded();
  selection.exit();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failed == 0
            ? l.mediaBrowserUpdatedNItems(ids.length)
            : l.mediaBrowserUpdatedNItemsWithFailed(
                ids.length - failed,
                failed,
              ),
      ),
      duration: const Duration(seconds: 1),
    ),
  );
}
