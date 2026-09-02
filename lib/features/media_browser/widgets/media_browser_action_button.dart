import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';

/// Emby/Jellyfin/fnos 详情页操作按钮(收藏/已看/转码播放等),
/// 电影页操作行与剧集页收藏按钮共用同一描边样式;[active] 时高亮强调色。
class MediaBrowserActionButton extends StatelessWidget {
  const MediaBrowserActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.padding = const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  /// 默认适配操作行内的窄按钮;整宽场景(剧集页收藏)传
  /// `EdgeInsets.symmetric(vertical: 11)` 保持原内边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? colors.accent : colors.text,
        side: BorderSide(
          color: active
              ? colors.accent.withValues(alpha: 0.55)
              : colors.cardBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: padding,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
