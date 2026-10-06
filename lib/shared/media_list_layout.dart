import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'movie_card.dart';

/// 影片网格和纵向列表共用 DBO 影片库的布局，横向滚动卡片不使用此规则。
abstract final class MediaListLayout {
  static const horizontalInset = 22.0;
  static const crossAxisSpacing = 10.0;
  static const mainAxisSpacing = 14.0;
  static const padding = EdgeInsets.symmetric(horizontal: horizontalInset);

  /// 列表首项与上方页头/工具栏的统一呼吸空间。
  static const double contentTopInset = 4.0;

  /// 大屏竖版封面维持可读尺寸，继续增加列数而不放大封面。
  static const double maxPortraitCardWidth = 184.0;

  static const double minLandscapeCardWidth = 270.0;
  static const double maxLandscapeCardWidth = 440.0;
  static const double landscapeInfoHeight = 76.0;

  /// 所有列表的基准 padding；底部留白由页面按悬浮 Tab 栏等场景 copyWith。
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    horizontalInset,
    contentTopInset,
    horizontalInset,
    0,
  );

  static int columnsForWidth(double width) {
    if (width < 1100) {
      return width >= 720
          ? 5
          : width >= 600
          ? 4
          : 3;
    }
    final availableWidth = width - padding.horizontal;
    return ((availableWidth + crossAxisSpacing) /
            (maxPortraitCardWidth + crossAxisSpacing))
        .ceil();
  }

  /// 横版卡片宽度保持在适合阅读的区间内，并据可用宽度决定列数。
  static int landscapeColumnsForWidth(double width) {
    final spacingAdjustedWidth = width + crossAxisSpacing;
    final columnsToLimitWidth =
        (spacingAdjustedWidth / (maxLandscapeCardWidth + crossAxisSpacing))
            .ceil();
    final columnsToKeepReadable = math
        .max(
          1,
          (spacingAdjustedWidth / (minLandscapeCardWidth + crossAxisSpacing))
              .floor(),
        )
        .toInt();
    return math.min(columnsToLimitWidth, columnsToKeepReadable).toInt();
  }

  static double landscapeCardWidthForWidth(double width) {
    final columns = landscapeColumnsForWidth(width);
    return (width - crossAxisSpacing * (columns - 1)) / columns;
  }

  /// 仅用于预览可见区域计算；卡片本身由父布局约束宽度。
  static double contentWidth(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width - media.padding.horizontal - padding.horizontal;
  }
}

/// 按实际可用宽度计算列数，支持分屏、横屏安全区及弹层中的影片网格。
class MediaGridDelegate extends SliverGridDelegate {
  const MediaGridDelegate({this.square = false, this.textScaleFactor = 1});

  /// 音乐专辑保留方形封面，影片始终使用统一竖版比例。
  final bool square;

  /// 大字体为卡片的信息区增加空间，封面比例和列数保持一致。
  final double textScaleFactor;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = MediaListLayout.columnsForWidth(
      constraints.crossAxisExtent + MediaListLayout.padding.horizontal,
    );
    final itemWidth =
        (constraints.crossAxisExtent -
            MediaListLayout.crossAxisSpacing * (columns - 1)) /
        columns;
    final baseHeight = square
        ? itemWidth + 62
        : itemWidth / MediaCardTemplate.gridChildAspectRatio;
    final extraHeight = textScaleFactor > 1 ? 62 * (textScaleFactor - 1) : 0;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: MediaListLayout.crossAxisSpacing,
      mainAxisSpacing: MediaListLayout.mainAxisSpacing,
      childAspectRatio: itemWidth / (baseHeight + extraHeight),
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(covariant MediaGridDelegate oldDelegate) =>
      square != oldDelegate.square ||
      textScaleFactor != oldDelegate.textScaleFactor;
}

/// 横版卡片在手机上保持单列，在横屏手机和平板上按可用宽度排成多列。
class MediaLandscapePagedSliver<PageKeyType, ItemType> extends StatelessWidget {
  const MediaLandscapePagedSliver({
    super.key,
    required this.pagingController,
    required this.builderDelegate,
    this.infoHeight = MediaListLayout.landscapeInfoHeight,
  });

  final PagingController<PageKeyType, ItemType> pagingController;
  final PagedChildBuilderDelegate<ItemType> builderDelegate;
  final double infoHeight;

  @override
  Widget build(BuildContext context) => PagedSliverGrid<PageKeyType, ItemType>(
    pagingController: pagingController,
    builderDelegate: builderDelegate,
    gridDelegate: MediaLandscapeGridDelegate(
      textScaleFactor: MediaQuery.textScalerOf(context).scale(14) / 14,
      infoHeight: infoHeight,
    ),
    showNewPageProgressIndicatorAsGridChild: false,
    showNewPageErrorIndicatorAsGridChild: false,
    showNoMoreItemsIndicatorAsGridChild: false,
  );
}

class MediaLandscapeGridDelegate extends SliverGridDelegate {
  const MediaLandscapeGridDelegate({
    this.textScaleFactor = 1,
    this.infoHeight = MediaListLayout.landscapeInfoHeight,
  });

  final double textScaleFactor;
  final double infoHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = MediaListLayout.landscapeColumnsForWidth(
      constraints.crossAxisExtent,
    );
    final itemWidth = MediaListLayout.landscapeCardWidthForWidth(
      constraints.crossAxisExtent,
    );
    final scaledInfoHeight = (infoHeight * textScaleFactor.clamp(1.0, 2.5))
        .toDouble();
    final itemHeight =
        itemWidth * 9 / 16 + scaledInfoHeight + MediaListLayout.mainAxisSpacing;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: MediaListLayout.crossAxisSpacing,
      mainAxisSpacing: 0,
      mainAxisExtent: itemHeight,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(covariant MediaLandscapeGridDelegate oldDelegate) =>
      textScaleFactor != oldDelegate.textScaleFactor ||
      infoHeight != oldDelegate.infoHeight;
}

/// 横版卡片的纵向列表统一使用相同的行间距。
class MediaLandscapeListItem extends StatelessWidget {
  const MediaLandscapeListItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MediaListLayout.mainAxisSpacing),
    child: child,
  );
}
