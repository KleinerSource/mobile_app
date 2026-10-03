import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';

/// Header 的圆形操作：视觉区域 36，点击区域 48，始终居中。
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.loading = false,
    this.color,
  });

  static const double tapTargetSize = 48;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: tapTargetSize,
    child: IconButton(
      tooltip: tooltip,
      iconSize: HeaderActionIcon.size,
      padding: const EdgeInsets.all(6),
      onPressed: loading ? null : onPressed,
      icon: HeaderActionIcon(icon: icon, loading: loading, color: color),
    ),
  );
}

/// 供普通操作与菜单入口共用的圆形图标。
class HeaderActionIcon extends StatelessWidget {
  const HeaderActionIcon({
    super.key,
    required this.icon,
    this.loading = false,
    this.color,
  });

  static const double size = 36;

  final IconData icon;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: colors.cardBorder),
      ),
      child: loading
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            )
          : Icon(icon, size: 18, color: color ?? colors.text),
    );
  }
}
