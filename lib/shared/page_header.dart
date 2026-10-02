import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 固定双行抬头：统一留白、标题行高度及返回／操作对齐。
/// trailing 保持控件自然尺寸；搜索框、筛选行等工具栏由页面按需接在下方。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
  });

  final String eyebrow;
  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final titleInset = leading == null ? 0.0 : 48.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
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
                  SizedBox(width: 48, height: 48, child: leading),
                Expanded(
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
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
