import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';

/// 拖选页面（收藏夹/媒体库/搜索）的可选条目卡片。
///
/// 视觉复刻 OMM 的 SelectableMovieCard：选择模式下未选卡片压暗到 0.55，
/// 左上角 22px 圆形勾选圈。勾选态由调用方包 ValueListenableBuilder 跟随
/// SelectionController.selectedListenable 局部重建（拖选过程不整页 setState）。
///
/// 卡片自身的 [MediaBrowserItemCard.onLongPress] 保持 null：长按手势让给
/// 外层 DragSelectionTarget，水波纹不会出现。
class MediaBrowserSelectableItemCard extends StatelessWidget {
  const MediaBrowserSelectableItemCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.square = false,
    this.showFavoriteBadge = false,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final bool square;
  final bool showFavoriteBadge;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Stack(
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: selecting && !selected ? 0.55 : 1.0,
          child: MediaBrowserItemCard(
            item: item,
            urls: urls,
            width: width,
            square: square,
            showFavoriteBadge: showFavoriteBadge,
            onTap: onTap,
          ),
        ),
        if (selecting)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? colors.accent
                    : Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
