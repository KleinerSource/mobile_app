import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'movie_card.dart';

/// 影片网格和纵向列表共用 DBO 影片库的布局，横向滚动卡片不使用此规则。
abstract final class MediaListLayout {
  static const horizontalInset = 22.0;
  static const crossAxisSpacing = 10.0;
  static const mainAxisSpacing = 14.0;
  static const padding = EdgeInsets.symmetric(horizontal: horizontalInset);

  static int columnsForWidth(double width) => width >= 1100
      ? 6
      : width >= 820
      ? 5
      : width >= 600
      ? 4
      : 3;

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
