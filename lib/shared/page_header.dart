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
  static const double trailingGap = 8;

  /// 带工具栏页面：头部与工具栏的统一间距（作为 bottomPadding 传入）。
  static const double toolbarTopGap = 12;

  /// 工具栏底部留白；配合列表顶部的呼吸空间
  /// （MediaListLayout.contentTopInset）使工具栏与列表间距同为 12。
  static const double toolbarBottomGap = 8;

  final String eyebrow;
  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? subtitle;

  /// 头部底部留白；工具栏紧跟头部时传 [toolbarTopGap] 收窄间距。
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final titleInset = leading == null ? 0.0 : leadingWidth;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
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
