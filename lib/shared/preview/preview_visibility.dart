import 'package:flutter/widgets.dart';

/// 按滚动位置选择当前应自动预览的列表项。
int? previewItemIndexForScroll({
  required double scrollOffset,
  required double cardHeight,
  required double itemGap,
  required int itemCount,
  double leadingPadding = 0,
  double switchOutFraction = 0.6,
}) {
  if (itemCount <= 0 ||
      !scrollOffset.isFinite ||
      !cardHeight.isFinite ||
      cardHeight <= 0 ||
      !itemGap.isFinite ||
      itemGap < 0 ||
      !switchOutFraction.isFinite ||
      switchOutFraction <= 0 ||
      switchOutFraction > 1) {
    return null;
  }
  final offset = (scrollOffset - leadingPadding).clamp(0.0, double.infinity);
  final itemExtent = cardHeight + itemGap;
  final baseIndex = (offset / itemExtent).floor();
  final withinItem = offset - baseIndex * itemExtent;
  final index = withinItem > cardHeight * switchOutFraction
      ? baseIndex + 1
      : baseIndex;
  return index.clamp(0, itemCount - 1);
}

/// 按实际布局位置选择当前应自动预览的列表项。
int? previewItemIndexForViewportKeys({
  required Iterable<GlobalKey?> itemKeys,
  required GlobalKey viewportKey,
  required double coverHeight,
  double switchOutFraction = 0.6,
}) {
  final keys = itemKeys.toList(growable: false);
  if (keys.isEmpty ||
      !coverHeight.isFinite ||
      coverHeight <= 0 ||
      !switchOutFraction.isFinite ||
      switchOutFraction <= 0 ||
      switchOutFraction > 1) {
    return null;
  }
  final viewport = viewportKey.currentContext?.findRenderObject();
  if (viewport is! RenderBox || !viewport.hasSize) return null;
  final viewportTop = viewport.localToGlobal(Offset.zero).dy;
  final viewportBottom = viewportTop + viewport.size.height;
  for (var index = 0; index < keys.length; index++) {
    final card = keys[index]?.currentContext?.findRenderObject();
    if (card is! RenderBox || !card.hasSize) continue;
    final cardTop = card.localToGlobal(Offset.zero).dy;
    final cardBottom = cardTop + card.size.height;
    if (cardBottom <= viewportTop || cardTop >= viewportBottom) continue;
    final hidden = (viewportTop - cardTop).clamp(0.0, coverHeight);
    if (hidden <= coverHeight * switchOutFraction) return index;
  }
  return null;
}
