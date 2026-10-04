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
    this.subtitle,
    this.bottomPadding = 22,
  });

  static const double horizontalPadding = 22;
  static const double leadingWidth = 48;

  /// leading 触区向左挤进水平边距的量：图标（24px）在 48px 槽内居中，
  /// 左移 12 后可见图标左缘正好落在 [horizontalPadding]，与无 leading
  /// 页面的标题左缘对齐，同时保留完整 48x48 点击区域。
  static const double leadingBleed = (leadingWidth - 24) / 2;

  static const double trailingGap = 8;

  /// 相邻块（头部→工具栏、工具栏→搜索框等）之间的统一间距。
  static const double toolbarTopGap = 12;

  /// 紧邻主列表的块（头部/工具栏/搜索框）的统一底部留白；配合列表顶部的
  /// 呼吸空间（MediaListLayout.contentTopInset）与块间间距同为 12，
  /// 任意组件缺失或增减时，列表与上一块的间距保持不变。
  static const double aboveListGap = 8;

  final String eyebrow;
  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? subtitle;

  /// 头部底部留白；下一块是工具栏时传 [toolbarTopGap]，
  /// 主列表直接跟随时传 [aboveListGap]，保持块间节奏一致。
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final titleInset = leading == null ? 0.0 : leadingWidth;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding - (leading == null ? 0.0 : leadingBleed),
        16,
        horizontalPadding,
        bottomPadding,
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
