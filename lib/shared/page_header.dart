import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 固定双行抬头：统一留白、标题行高度及返回／操作对齐。
/// trailing 保持控件自然尺寸；搜索框、筛选行等工具栏由页面按需接在下方，
/// 带工具栏的页面通过 [bottomPadding] 收窄头部与工具栏的间距。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.leading,
    this.trailing,
    this.alignTrailingToPadding = false,
    this.subtitle,
    this.bottomPadding = 22,
  });

  static const double horizontalPadding = 22;
  static const double leadingWidth = 48;

  /// leading 触区向左挤进水平边距的量：图标（24px）在 48px 槽内居中，
  /// 左移 12 后可见图标左缘正好落在 [horizontalPadding]，与无 leading
  /// 页面的标题左缘对齐，同时保留完整 48x48 点击区域。
  static const double leadingBleed = (leadingWidth - 24) / 2;

  /// trailing 触区向右挤进水平边距的量：圆形操作按钮的可见圆（36px）在
  /// 48px 触区内居中，两侧各留 6px 空隙；出血后可见圆右缘正好落在
  /// [horizontalPadding]，与标题/返回图标的左缘对称，同时保留完整
  /// 48x48 点击区域。
  static const double trailingBleed = (48 - 36) / 2;

  static const double trailingGap = 8;

  /// 页头操作控件的可见边缘间距；圆形按钮相邻时，触区已提供此留白。
  static const double actionGap = 12;

  /// 圆形按钮与筛选／视图切换等自然宽度控件之间，扣除圆形触区留白。
  static const double mixedActionGap = actionGap - trailingBleed;

  /// 相邻块（头部→工具栏、工具栏→搜索框等）之间的统一间距。
  static const double toolbarTopGap = 16;

  /// 紧邻主列表的块（头部/工具栏/搜索框）的统一底部留白；配合列表顶部的
  /// 呼吸空间（MediaListLayout.contentTopInset）后与块间间距
  /// （toolbarTopGap）保持一致，任意组件缺失或增减时，
  /// 列表与上一块的间距不变。
  static const double aboveListGap = 12;

  /// 标题行高由 48px 操作按钮撑起，与 [AppText.pageTitle] 的字号/行高
  /// 保持同步；用于在 [build] 中计算文字居中产生的下方空隙。
  static const double _titleFontSize = 28;
  static const double _titleLineHeightFactor = 1.05;
  static const double _titleRowHeight = 48;

  final String eyebrow;
  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  /// trailing 末尾是圆形操作按钮（[trailingBleed] 所述结构）时传 true：
  /// 触区向右出血，可见圆右缘对齐 [horizontalPadding]；胶囊形等可见
  /// 边界即自然尺寸的控件保持 false。
  final bool alignTrailingToPadding;

  final Widget? subtitle;

  /// 标题文字到下一块的视觉间距；下一块是工具栏时传 [toolbarTopGap]，
  /// 主列表直接跟随时传 [aboveListGap]。标题文字垂直居中在 48px 标题行
  /// 内，文字下方约 9px 的空隙会让视觉间距大于实际留白，因此 [build]
  /// 会按当前字体缩放扣除该空隙（光学补偿），保证任何字号下标题文字
  /// 到下一块的视觉间距恒等于此值。
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final titleInset = leading == null ? 0.0 : leadingWidth;
    // 标题行高由 48px 操作按钮撑起，文字居中会在文字下方产生空隙；
    // 放大字体后标题行随文字增高、空隙归零。subtitle 紧贴标题行底部，
    // 不经过该空隙，无需补偿。
    final scaledTitleLineHeight =
        MediaQuery.textScalerOf(context).scale(_titleFontSize) *
        _titleLineHeightFactor;
    final titleSlack = subtitle == null
        ? math.max(0, (_titleRowHeight - scaledTitleLineHeight) / 2)
        : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding - (leading == null ? 0.0 : leadingBleed),
        16,
        horizontalPadding -
            (trailing != null && alignTrailingToPadding ? trailingBleed : 0.0),
        math.max(0, bottomPadding - titleSlack),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: titleInset),
            child: Text(
              eyebrow,
              style: AppText.eyebrow(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                if (leading != null)
                  SizedBox(width: leadingWidth, height: 48, child: leading),
                Expanded(
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: trailingGap),
                  SizedBox(
                    height: 48,
                    child: Center(widthFactor: 1, child: trailing),
                  ),
                ],
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(left: titleInset),
              child: subtitle,
            ),
          ],
        ],
      ),
    );
  }
}
