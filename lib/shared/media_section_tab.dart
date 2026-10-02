import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// 收藏分类与订阅分区共用的紧凑 tab，强调色跟随当前媒体源。
class MediaSectionTab extends StatelessWidget {
  const MediaSectionTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final foreground = selected ? colors.accent : colors.muted;
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.15)
                  : colors.chipBg,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? colors.accent.withValues(alpha: 0.5)
                    : colors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
